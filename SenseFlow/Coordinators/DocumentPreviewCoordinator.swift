import Foundation
import Observation
import AppKit

/// Owns one document identity. The native editor owns the live text, not this model.
@MainActor @Observable final class DocumentPreviewCoordinator {
    private(set) var source: DocumentSnapshot?
    private(set) var imagePreview: CGImage?
    var isMedia: Bool { imagePreview != nil }
    var isImage: Bool { imagePreview != nil }
    var previewSize = CGSize(width: 600, height: 440)
    var previewContentVisible = false
    var previewWindowNumber: Int?
    private(set) var isEditing = false
    private(set) var isPinned = false
    private(set) var isLoading = false
    private(set) var status = ""
    private(set) var errorMessage: String?
    private(set) var recoveredDraft: DocumentDraft?
    private(set) var generation = 0
    private(set) var savedGeneration = 0
    var isDirty: Bool { generation != savedGeneration }

    @ObservationIgnored private let repository: HistoryContentRepository
    @ObservationIgnored private let writer: ClipboardWriter
    @ObservationIgnored private let host: DocumentWindowHost
    @ObservationIgnored private weak var editor: (any DocumentEditor)?
    @ObservationIgnored private var preparationTask: Task<Void, Never>?
    @ObservationIgnored private var requestTask: Task<Void, Never>?
    @ObservationIgnored private var checkpointTask: Task<Void, Never>?
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var sessionID = UUID()
    @ObservationIgnored private var anchor = CGRect.zero
    @ObservationIgnored private var readingTimer: Timer?
    @ObservationIgnored private var outsideSince: Date?
    @ObservationIgnored private var candidateItemID: Int64?
    @ObservationIgnored private var lastHoveredID: Int64?
    @ObservationIgnored private var existingDraft: DocumentDraft?
    @ObservationIgnored private var archivedText = ""
    @ObservationIgnored private var persistedGeneration = -1
    @ObservationIgnored private var saving = false
    @ObservationIgnored private var closing = false
    @ObservationIgnored var onDidSave: (() -> Void)?

    init(repository: HistoryContentRepository, writer: ClipboardWriter, host: DocumentWindowHost) {
        self.repository = repository
        self.writer = writer
        self.host = host
        host.onClose = { [weak self] in self?.requestClose() }
        host.onPin = { [weak self] in self?.pin() }
        host.onSave = { [weak self] in self?.save() }
        host.onPointerDismiss = { [weak self] in self?.dismissPointerPreview() ?? false }
    }

    /// Hover only updates pointer lifetime; every content type requires right-click to open.
    func pointerEntered(_ item: ClipboardItem, anchor: CGRect) {
        lastHoveredID = item.id
        if source?.itemID == item.id { self.anchor = anchor; outsideSince = nil; return }
    }
    func pointerLeft(_ itemID: Int64) {
        if lastHoveredID == itemID { lastHoveredID = nil }
        if candidateItemID == itemID, source?.itemID != itemID {
            cancelCandidate()
            if source != nil && !isPinned { startReadingTimer() }
        }
    }
    /// Reserves the existing request generation before source-card press feedback.
    func beginPointerPreviewIntent() -> UUID {
        cancelCandidate()
        return requestID
    }
    /// Right-click toggles the current card, preserving edited text as a draft.
    func togglePointerPreview(_ item: ClipboardItem, anchor: CGRect, expectedRequest: UUID) {
        guard expectedRequest == requestID else { return }
        guard !saving, !closing else { return }
        guard source?.itemID == item.id else {
            host.playPressConfirmation()
            preview(item, anchor: anchor, pinOnOpen: false, expectedRequest: expectedRequest)
            return
        }
        host.playPressConfirmation()
        _ = dismissPointerPreview()
    }

    /// Dismisses a pointer preview anywhere, checkpointing edits without a modal.
    /// Returns true when the click belongs to dismissal and must not open another card.
    @discardableResult func dismissPointerPreview() -> Bool {
        guard source != nil || candidateItemID != nil else { return false }
        guard !saving, !closing else { return true }
        cancelCandidate()
        guard let source else { return true }
        guard editor?.isComposing != true else {
            errorMessage = "请先完成当前输入，再收回预览。"
            return true
        }
        if !isEditing || !isDirty {
            closeImmediately()
            return true
        }
        let token = requestID
        let sourceID = source.itemID
        closing = true
        editor?.setEditable(false)
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.closing = false
                if self.isEditing { self.editor?.setEditable(true) }
            }
            guard await self.checkpoint(), self.requestID == token,
                  self.source?.itemID == sourceID else { return }
            self.closeImmediately()
        }
        return true
    }
    /// Explicit triggers can opt into the same unpinned lifetime as hover.
    func preview(_ item: ClipboardItem, anchor: CGRect, pinOnOpen: Bool = true, expectedRequest: UUID? = nil) {
        if let expectedRequest, expectedRequest != requestID { return }
        if source?.itemID == item.id {
            outsideSince = nil
            if pinOnOpen { pin() }
            return
        }
        guard !saving, !closing else { status = "当前保存尚未完成，请稍后切换。"; return }
        open(item, anchor: anchor, explicit: pinOnOpen)
    }
    func historyChanged() {
        cancelCandidate()
        if !isPinned { closeImmediately() }
    }
    /// Scrolling dismisses a reading preview once; editing buffers remain protected.
    func historyScrolled() {
        cancelCandidate()
        if !isEditing, source != nil { closeImmediately(returnToCard: false) }
    }
    /// Hiding is separate from closing: an editing buffer survives loss of app focus.
    func historyHidden() {
        preparationTask?.cancel()
        preparationTask = nil
        cancelCandidate()
        stopReadingTimer()
        if isEditing {
            if isDirty { scheduleCheckpoint() }
            host.hideRetainingSession()
        } else {
            closeImmediately()
        }
    }
    func historyShown() {
        if isEditing { host.showRetainedSession() }
        preparationTask?.cancel()
        preparationTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.host.prepare(session: self)
            self.preparationTask = nil
        }
    }
    /// Called only after the user explicitly confirms clearing history and drafts.
    func historyCleared() { closeImmediately() }
    func screenChanged() { host.fitRemainingScreen() }

    private func cancelCandidate() {
        requestID = UUID()
        requestTask?.cancel()
        requestTask = nil
        isLoading = false
        candidateItemID = nil
    }

    private func open(_ item: ClipboardItem, anchor: CGRect, explicit: Bool = false) {
        guard item.type != .video else { return }
        cancelCandidate()
        stopReadingTimer()
        let token = requestID
        candidateItemID = item.id
        self.anchor = anchor
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard !Task.isCancelled, self.requestID == token else { return }
                self.isLoading = true
                let draft = item.type == .text ? try await self.repository.recover(sourceID: item.id) : nil
                let detail = try await self.repository.loadDetail(itemID: item.id, revision: item.uniqueId)
                let image: CGImage?
                if detail.type == .image {
                    image = try await HistoryMediaLoader.imagePreview(for: detail, pixels: 2048)
                } else { image = nil }
                guard !Task.isCancelled, self.requestID == token else { return }
                if self.isEditing && self.isDirty {
                    guard self.editor?.isComposing != true else {
                        self.isLoading = false
                        self.errorMessage = "请先完成当前输入，再切换预览。"
                        return
                    }
                    let previousEditor = self.editor
                    previousEditor?.setEditable(false)
                    let preserved = await self.checkpoint()
                    previousEditor?.setEditable(true)
                    guard !Task.isCancelled, self.requestID == token else { return }
                    guard preserved, self.persistedGeneration >= self.generation else {
                        self.isLoading = false
                        return
                    }
                }
                let text = detail.textContent ?? ""
                self.closeImmediately(invalidateRequest: false, closeSurface: false)
                self.sessionID = UUID()
                self.generation = 0
                self.savedGeneration = 0
                self.persistedGeneration = -1
                self.source = DocumentSnapshot(itemID: detail.id, revision: detail.uniqueId, text: text,
                                               appName: detail.appName, appPath: detail.appPath, timestamp: detail.timestamp)
                self.imagePreview = image
                self.archivedText = text
                self.errorMessage = nil
                self.status = "阅读全文 · 点击正文开始编辑"
                let sampleEnd = text.index(text.startIndex, offsetBy: 1024, limitedBy: text.endIndex) ?? text.endIndex
                self.recoveredDraft = draft
                self.existingDraft = draft
                try self.host.present(session: self, anchor: anchor, sample: String(text[..<sampleEnd]), imageAspectRatio: image.map { CGFloat($0.width) / CGFloat($0.height) }, hasMoreText: sampleEnd != text.endIndex)
                self.isLoading = false
                self.candidateItemID = nil
                if explicit { self.pin() } else { self.startReadingTimer() }
            } catch is CancellationError {
                return
            } catch {
                guard self.requestID == token else { return }
                if self.source?.itemID == item.id { self.closeImmediately() }
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.status = "预览加载失败，可再次打开重试。"
                if self.source != nil && !self.isPinned { self.startReadingTimer() }
            }
        }
    }

    func attachEditor(_ editor: any DocumentEditor) {
        self.editor = editor
        editor.load(text: source?.text ?? "")
    }
    func pin() {
        guard source != nil else { return }
        isPinned = true
        cancelCandidate()
        stopReadingTimer()
    }
    func beginEditing() {
        guard source != nil, !isMedia, !closing else { return }
        if let existingDraft { recoveredDraft = existingDraft; status = "请先继续或删除已有草稿。"; pin(); return }
        pin()
        isEditing = true
        editor?.setEditable(true)
        host.activateEditor()
        editor?.focus()
        status = isDirty ? "草稿未归档" : "编辑中 · 原文保持不变"
    }

    func textDidChange() {
        guard isEditing else { return }
        generation += 1
        errorMessage = nil
        status = "草稿保存中…"
        scheduleCheckpoint()
    }

    private func scheduleCheckpoint() {
        checkpointTask?.cancel()
        checkpointTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            await self?.checkpoint()
        }
        if deadlineTask == nil {
            deadlineTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                self?.deadlineTask = nil
                await self?.checkpoint()
            }
        }
    }

    @discardableResult private func checkpoint() async -> Bool {
        guard let source, let editor else { return false }
        guard !editor.isComposing else {
            // Never persist transient marked text. Retry after the next idle interval.
            checkpointTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                await self?.checkpoint()
            }
            return false
        }
        if persistedGeneration >= generation { return true }
        let identity = sessionID
        let current = generation
        let draft = DocumentDraft(sessionID: identity, source: source, generation: current, text: editor.textSnapshot())
        do {
            try await repository.checkpoint(draft)
            guard identity == sessionID else { return false }
            persistedGeneration = max(persistedGeneration, current)
            if current == generation { status = "草稿已保存 · 尚未归档为新记录" }
            return true
        } catch {
            guard identity == sessionID else { return false }
            errorMessage = "草稿未保存：\(error.localizedDescription)"
            return false
        }
    }
    func retryCheckpoint() { Task { await checkpoint() } }

    func continueDraft() {
        guard let recoveredDraft, let editor, !editor.isComposing else { return }
        sessionID = recoveredDraft.sessionID
        generation = recoveredDraft.generation
        savedGeneration = -1
        persistedGeneration = generation
        editor.load(text: recoveredDraft.text)
        self.recoveredDraft = nil
        existingDraft = nil
        beginEditing()
    }
    func viewOriginal() { recoveredDraft = nil }
    func deleteRecoveredDraft() {
        guard let recoveredDraft else { return }
        Task {
            do {
                try await repository.discard(sessionID: recoveredDraft.sessionID, generation: recoveredDraft.generation)
                self.recoveredDraft = nil
                self.existingDraft = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func save() { beginEditing(); guard isEditing else { return }; Task { await saveVersion() } }
    @discardableResult private func saveVersion() async -> Bool {
        guard !saving, let source, let editor else { return false }
        guard !editor.isComposing else { errorMessage = "请先完成当前输入，再保存。"; return false }
        let text = editor.textSnapshot()
        let current = generation
        let identity = sessionID
        if text == archivedText { savedGeneration = current; status = "内容未改变，无需新增记录"; return true }
        saving = true
        status = "正在保存新记录…"
        defer { saving = false }
        do {
            _ = try await repository.saveDerived(text: text, source: source, requestID: UUID())
            guard sessionID == identity else { return false }
            archivedText = text
            savedGeneration = current
            // Preserve edits made while the write was in flight; never reload the buffer.
            status = current == generation ? "已保存为新记录 · 原文保留" : "新记录已保存，后续修改仍为草稿"
            errorMessage = nil
            onDidSave?()
            // The checkpoint remains recoverable until an explicit clean close.
            return true
        } catch {
            guard sessionID == identity else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }
    func copyAll() {
        if isImage, let source {
            Task {
                do {
                    let detail = try await repository.loadDetail(itemID: source.itemID, revision: source.revision)
                    let data = try await HistoryMediaLoader.imageData(for: detail)
                    await writer.write(.image(data))
                } catch { errorMessage = error.localizedDescription }
            }
            return
        }
        guard let editor, !editor.isComposing else { errorMessage = "请先完成当前输入，再复制全文。"; return }
        let text = editor.textSnapshot()
        Task { await writer.write(text) }
    }

    func requestClose() { Task { _ = await prepareToClose() } }
    /// Returning false keeps the document open after cancel, composition or failed persistence.
    func prepareToClose() async -> Bool {
        guard source != nil else { cancelCandidate(); return true }
        guard !closing, !saving else { return false }
        guard editor?.isComposing != true else { errorMessage = "请先完成当前输入，再关闭。"; return false }
        closing = true
        editor?.setEditable(false)
        checkpointTask?.cancel()
        deadlineTask?.cancel()
        defer {
            closing = false
            if isEditing {
                editor?.setEditable(true)
                deadlineTask = nil
                if isDirty { scheduleCheckpoint() }
            }
        }
        let hasChanges = isEditing && editor?.textSnapshot() != archivedText
        var keep = false
        if hasChanges {
            switch host.closeChoice() {
            case .cancel: return false
            case .save: guard await saveVersion() else { return false }
            case .keepDraft: guard await checkpoint() else { return false }; keep = true
            case .discard: break
            }
        }
        if !keep, isEditing {
            do { try await repository.discard(sessionID: sessionID, generation: generation) }
            catch { errorMessage = error.localizedDescription; return false }
        }
        closeImmediately()
        return true
    }

    private func closeImmediately(invalidateRequest: Bool = true, closeSurface: Bool = true, returnToCard: Bool = true) {
        if invalidateRequest { cancelCandidate() }
        stopReadingTimer()
        checkpointTask?.cancel(); deadlineTask?.cancel(); deadlineTask = nil
        if closeSurface { host.close(returnToCard: returnToCard) }
        editor = nil
        source = nil
        imagePreview = nil
        previewContentVisible = false
        previewWindowNumber = nil
        sessionID = UUID()
        recoveredDraft = nil
        existingDraft = nil
        isPinned = false
        isEditing = false
        outsideSince = nil
    }
    private func startReadingTimer() {
        stopReadingTimer()
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPointer() }
        }
        readingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func stopReadingTimer() { readingTimer?.invalidate(); readingTimer = nil }
    private func checkPointer() {
        guard !isPinned, !host.isTransitioning, let frame = host.frame else { return }
        let point = NSEvent.mouseLocation
        // A narrow card-to-window corridor keeps traversal stable without retaining the entire history panel.
        let corridor = CGRect(x: min(anchor.midX, frame.midX) - 32, y: min(anchor.maxY, frame.minY),
                              width: abs(anchor.midX - frame.midX) + 64, height: abs(frame.minY - anchor.maxY))
        if anchor.contains(point) || frame.contains(point) || corridor.contains(point) || NSEvent.pressedMouseButtons != 0 {
            outsideSince = nil
        } else if let since = outsideSince {
            if Date().timeIntervalSince(since) >= 0.25 { closeImmediately() }
        } else { outsideSince = Date() }
    }
}
