import Foundation
import Observation
import AppKit
import SwiftUI
import Carbon
import QuartzCore

/// Progress for the contextual tour; storage and document content remain outside this model.
@MainActor @Observable final class ClipboardOnboardingCoordinator {
    enum Step: Int { case launch, history, preview, filters, finished, complete }
    private(set) var step: Step
    private(set) var hasPreview = false
    private(set) var didSlideLeft = false
    private(set) var didSlideRight = false
    private(set) var didSelectCategory = false
    private(set) var isGuideLeaving = false
    @ObservationIgnored private var advancement: Task<Void, Never>?
    private var leftTravel: CGFloat = 0
    private var rightTravel: CGFloat = 0
    @ObservationIgnored private let defaults: UserDefaults
    private static let progressKey = "contextual_onboarding_v4_step"
    @ObservationIgnored var onComplete: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let progress = defaults.object(forKey: Self.progressKey) as? Int {
            step = Step(rawValue: progress) ?? .launch
        } else {
            step = (defaults.object(forKey: "contextual_onboarding_v3_step") as? Int == 4 || defaults.object(forKey: "contextual_onboarding_v2_step") as? Int == 7) ? .complete : .launch
        }
    }

    var isComplete: Bool { step == .complete }
    var historyStep: Step? { isComplete || hasPreview ? nil : step }
    var previewStep: Step? { hasPreview && step == .filters ? .filters : nil }

    func next() {
        switch step {
        case .history where didSlideLeft && didSlideRight: move(to: .preview)
        case .filters where didSelectCategory && !hasPreview: move(to: .finished)
        case .finished: move(to: .complete)
        default: break
        }
    }
    /// Finishes after the last instruction has had time to be read.
    func finishAutomatically() {
        guard step == .finished else { return }
        advanceAfterReading(from: .finished, to: .complete)
    }
    /// Advances only after an actual shortcut or recognized physical reveal gesture.
    func launchRequested() { if step == .launch { move(to: .history) } }
    func historyScrolled(by delta: CGFloat) {
        guard step == .history, delta.isFinite, delta != 0 else { return }
        // Keep the instruction until scrolling has settled, even after both directions qualify.
        advancement?.cancel()
        advancement = nil
        isGuideLeaving = false
        if !didSlideLeft {
            if delta > 0 { leftTravel += delta }
            didSlideLeft = leftTravel >= 24
            return
        }
        if delta < 0 { rightTravel -= delta }
        didSlideRight = rightTravel >= 24
        if didSlideLeft && didSlideRight { advanceAfterReading(from: .history, to: .preview) }
    }
    func categorySelected() {
        if step == .filters && !hasPreview {
            didSelectCategory = true
            advanceAfterReading(from: .filters, to: .finished)
        }
    }
    private func advanceAfterReading(from source: Step, to destination: Step) {
        guard advancement == nil else { return }
        advancement = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(900))
                guard let self, self.step == source else { return }
                self.isGuideLeaving = true
                try await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, self.step == source else { return }
                self.move(to: destination)
            } catch { /* A changed tutorial step cancels its pending transition. */ }
        }
    }
    func previewOpened() {
        hasPreview = true
        if step == .preview { move(to: .filters) }
    }
    func previewClosed() { hasPreview = false }
    func skip() { move(to: .complete) }
    func restart() { didSelectCategory = false; previewClosed(); didSlideLeft = false; didSlideRight = false; leftTravel = 0; rightTravel = 0; move(to: .launch) }

    private func move(to step: Step) {
        guard self.step != step else { return }
        advancement?.cancel()
        advancement = nil
        isGuideLeaving = false
        self.step = step
        defaults.set(step.rawValue, forKey: Self.progressKey)
        if step == .complete { onComplete?() }
    }
}

/// Tutorial-only history. It never opens the user's database or system pasteboard.
actor ClipboardTutorialRepository: ClipboardRepositoryProtocol, HistoryContentRepository {
    private var records: [ClipboardItem]
    private var drafts: [UUID: DocumentDraft] = [:]
    init(records: [ClipboardItem]) { self.records = records }
    func fetchRecent(limit: Int, offset: Int) async throws -> [ClipboardItem] {
        Array(records.dropFirst(offset).prefix(limit))
    }
    func search(query: String, limit: Int, offset: Int) async throws -> [ClipboardItem] {
        Array(records.filter { ($0.textContent ?? "").localizedStandardContains(query) }.dropFirst(offset).prefix(limit))
    }
    func loadDetail(itemID: Int64, revision: String) async throws -> ClipboardItem {
        guard let item = records.first(where: { $0.id == itemID && $0.uniqueId == revision }) else { throw DocumentStoreError.missing }
        return item
    }
    func saveDerived(text: String, source: DocumentSnapshot, requestID: UUID) async throws -> Int64 {
        guard !text.isEmpty else { throw DocumentStoreError.empty }
        let id = (records.map(\.id).max() ?? 0) + 1
        records.insert(ClipboardItem(id: id, uniqueId: UUID().uuidString, type: .text, textContent: text,
            imageData: nil, blobPath: nil, timestamp: Int64(Date().timeIntervalSince1970), appName: "教程示例", appPath: Bundle.main.bundlePath), at: 0)
        return id
    }
    func recover(sourceID: Int64) async throws -> DocumentDraft? { drafts.values.first { $0.source.itemID == sourceID } }
    func checkpoint(_ draft: DocumentDraft) async throws { drafts[draft.sessionID] = draft }
    func discard(sessionID: UUID, generation: Int) async throws { drafts[sessionID] = nil }
}

/// Owns a separate native workspace backed entirely by tutorial examples.
@MainActor final class ClipboardTutorialSession {
    var historyModel: ClipboardListViewModel { model }
    var historyFrame: NSRect { panel.frame }
    var isHistoryVisible: Bool { wantsVisible && panel.isVisible }
    /// Removes the tutorial surface without playing a vertical dismissal.
    func concealForHandoff() { panel.orderOut(nil) }
    private let tour: ClipboardOnboardingCoordinator
    private let workspace = WorkspaceWindowCoordinator()
    private let repository: ClipboardTutorialRepository
    private let documents: DocumentPreviewCoordinator
    private let model: ClipboardListViewModel
    private let panel: NSPanel
    private var launchPanel: NSPanel?
    private let layout = WindowLayoutConfig.default
    private enum Visibility { case hidden, teasing, showing, visible, hiding }
    private var visibility = Visibility.hidden
    private var wantsVisible = false
    private var isClosed = false
    private var teaserDisplayLink: CADisplayLink?
    private var teaserDisplayTarget: ClipboardTeaserDisplayTarget?
    private var teaserRestFrame: NSRect?
    private var teaserStart: CFTimeInterval = 0
    private var teaserStartY: CGFloat = 0
    init(tour: ClipboardOnboardingCoordinator) {
        self.tour = tour
        let repository = ClipboardTutorialRepository(records: Self.examples())
        self.repository = repository
        let writer = NSPasteboardAdapter(monitor: .shared)
        let host = DocumentWindowHost(workspace: workspace, onboarding: tour)
        let documents = DocumentPreviewCoordinator(repository: repository, writer: writer, host: host)
        self.documents = documents
        let actions = HistoryActionCoordinator(documents: documents, repository: repository, writer: writer,
            onPaste: {
                FloatingWindowManager.shared.hideWindow()
                AutoPasteManager.shared.performAutoPaste()
            })
        model = ClipboardListViewModel(repository: repository, actions: actions,
            thumbnails: ClipboardThumbnailLoader(repository: repository))
        let factory = WindowFactory(layoutConfig: layout, repository: repository, onboarding: tour)
        panel = factory.createWindow(sharedViewModel: model, onItemSelected: { _ in })
        WindowConfigurator().configurePanel(panel)
        workspace.register(panel)
        documents.onDidSave = { [weak model] in
            Task { await model?.loadItems() }
        }
    }
    func show() {
        guard !isClosed else { return }
        if tour.step == .launch {
            showTeaser()
            if launchPanel == nil {
                let prompt = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 540, height: 148),
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                prompt.isReleasedWhenClosed = false
                prompt.isOpaque = false
                prompt.backgroundColor = .clear
                prompt.hasShadow = false
                prompt.level = .popUpMenu
                prompt.hidesOnDeactivate = false
                prompt.ignoresMouseEvents = true
                prompt.contentView = NSHostingView(rootView: ClipboardLaunchPrompt(tour: tour))
                workspace.register(prompt)
                launchPanel = prompt
            }
            positionLaunchPrompt()
            launchPanel?.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
            panel.makeFirstResponder(nil)
            return
        }
        launchPanel?.orderOut(nil)
        stopTeaser()
        panel.ignoresMouseEvents = false
        panel.contentView?.setAccessibilityHidden(false)
        wantsVisible = true
        updateVisibility()
        documents.historyShown()
    }
    var isVisible: Bool { wantsVisible || launchPanel?.isVisible == true }
    func hide() {
        stopTeaser()
        if visibility == .teasing { panel.orderOut(nil); visibility = .hidden }
        launchPanel?.orderOut(nil)
        documents.historyHidden()
        wantsVisible = false
        updateVisibility()
    }
    private func showTeaser() {
        guard visibility != .teasing else { return }
        let positioner = WindowPositioner(layoutConfig: layout)
        guard let screen = positioner.detectActiveScreen() ?? NSScreen.main else { return }
        var rest = positioner.calculateWindowFrame(for: screen,
            windowHeight: min(layout.unifiedWindowHeight, screen.visibleFrame.height * 0.8))
        rest.origin.y = screen.frame.minY - rest.height * 2 / 3
        teaserRestFrame = rest
        visibility = .teasing
        panel.ignoresMouseEvents = true
        panel.contentView?.setAccessibilityHidden(true)
        panel.alphaValue = 1
        var hidden = rest
        hidden.origin.y = screen.frame.minY - rest.height + Constants.ClipboardWindow.shadowBleedTop
        panel.setFrame(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? rest : hidden, display: false)
        panel.orderFront(nil)
        Task { await model.loadItems() }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        teaserStart = CACurrentMediaTime()
        teaserStartY = hidden.minY
        let target = ClipboardTeaserDisplayTarget(session: self)
        teaserDisplayTarget = target
        let link = panel.displayLink(target: target, selector: #selector(ClipboardTeaserDisplayTarget.tick(_:)))
        teaserDisplayLink = link
        link.add(to: .main, forMode: .common)
    }
    fileprivate func advanceTeaser(at time: CFTimeInterval) {
        guard visibility == .teasing, let rest = teaserRestFrame else { return }
        let elapsed = max(0, time - teaserStart)
        var frame = rest
        let rise = UnitCurve.bezier(startControlPoint: UnitPoint(x: 1.0 / 3, y: 1),
                                   endControlPoint: UnitPoint(x: 2.0 / 3, y: 1))
        if elapsed < 0.32 {
            let progress = rise.value(at: elapsed / 0.32)
            frame.origin.y = teaserStartY + (rest.minY - teaserStartY) * progress
        } else {
            var phase = (elapsed - 0.32).truncatingRemainder(dividingBy: 2.1)
            // Each impact immediately launches a smaller ballistic rebound.
            for (height, duration) in [(24.0, 0.42), (8.0, 0.26), (2.5, 0.18)] {
                if phase < duration {
                    let progress = phase / duration
                    frame.origin.y += 4 * height * progress * (1 - progress)
                    break
                }
                phase -= duration
            }
        }
        panel.setFrameOrigin(frame.origin)
        positionLaunchPrompt()
    }
    private func positionLaunchPrompt() {
        guard let prompt = launchPanel else { return }
        prompt.setFrameOrigin(NSPoint(x: panel.frame.midX - prompt.frame.width / 2,
            y: panel.frame.maxY + 10))
    }
    private func stopTeaser() {
        teaserDisplayLink?.invalidate()
        teaserDisplayLink = nil
        teaserDisplayTarget = nil
        teaserRestFrame = nil
    }
    private func updateVisibility() {
        guard !isClosed else { return }
        switch visibility {
        case .teasing where wantsVisible:
            let positioner = WindowPositioner(layoutConfig: layout)
            let screen = positioner.detectActiveScreen() ?? panel.screen ?? NSScreen.main
            guard let screen else { return }
            let full = positioner.calculateWindowFrame(for: screen,
                windowHeight: min(layout.unifiedWindowHeight, screen.visibleFrame.height * 0.8))
            visibility = .showing
            panel.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(full, display: true)
            }, completionHandler: { [weak self] in
                guard let self, !self.isClosed else { return }
                self.visibility = .visible
                self.updateVisibility()
            })
        case .hidden where wantsVisible:
            let positioner = WindowPositioner(layoutConfig: layout)
            let available = (positioner.detectActiveScreen() ?? NSScreen.main)?.visibleFrame.height ?? 800
            positioner.resizeAndPositionWindow(panel, windowHeight: min(layout.unifiedWindowHeight, available * 0.8))
            visibility = .showing
            Task { await model.loadItems() }
            FloatingWindowAnimator.animateSlideIn(window: panel) { [weak self] in
                guard let self, !self.isClosed else { return }
                self.visibility = .visible
                self.updateVisibility()
            }
        case .visible where !wantsVisible:
            visibility = .hiding
            FloatingWindowAnimator.animateSlideOut(window: panel) { [weak self] in
                guard let self, !self.isClosed else { return }
                self.visibility = .hidden
                self.updateVisibility()
            }
        default:
            break
        }
    }
    func close() {
        isClosed = true
        stopTeaser()
        wantsVisible = false
        launchPanel?.orderOut(nil)
        launchPanel?.close()
        launchPanel = nil
        documents.historyCleared()
        panel.orderOut(nil)
        panel.contentView = nil
        panel.close()
    }
    private static func examples() -> [ClipboardItem] {
        let now = Int64(Date().timeIntervalSince1970)
        func text(_ id: Int64, _ content: String) -> ClipboardItem {
            ClipboardItem(id: id, uniqueId: UUID().uuidString, type: .text, textContent: content,
                imageData: nil, blobPath: nil, timestamp: now, appName: "senseflow", appPath: Bundle.main.bundlePath)
        }
        var items = [text(1, "https://senseflow.top")]
        if let url = Bundle.main.url(forResource: "onboarding-promotion", withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            items.append(ClipboardItem(id: 2, uniqueId: UUID().uuidString, type: .image, textContent: nil,
                imageData: data, blobPath: nil, timestamp: now, appName: "senseflow", appPath: Bundle.main.bundlePath))
        }
        items.append(text(3, """
        感觉在流动

        灵感并不总是在你准备好的时候出现。它可能是一段读到一半的文字，一张想留下的图片，也可能是工作间隙突然冒出的念头。我们复制它们，是因为那一刻觉得它们值得留下。

        senseflow 希望让这份感觉继续流动。从看到，到留下；从找回，到重新使用。中间的每一步都应该轻松，不需要你先整理文件夹、命名笔记，或者记住自己把内容放在哪里。

        复制，是一个自然的动作。

        你在浏览器里读到一句话，在聊天中收到一张图片，在文档里找到一段资料。复制之后，继续手上的事情就好。需要时，记录在那里，原来的文字和图片都被完整保留。

        找回，应该顺着记忆。

        有时你记得内容，有时只记得它大概出现的时间。左右翻看，按文字或图片筛选，或者搜索一个记得的词。我们希望这些操作顺着你的直觉，让你从一张小卡片认出那一刻的内容。

        预览，让内容回到眼前。

        小卡片帮助你快速扫过，完整预览让你停下来读。短句不需要复杂的界面，长文章应该有舒适的阅读空间，图片也应该能够清楚地展开。你不必为了看完整内容先把它粘贴到另一个地方。

        修改，是下一次表达的开始。

        一段留下的文字，可以在新的场景里继续生长。改一句话，整理一下格式，保存为新的记录。原文仍然保留，你可以放心试着表达，不需要在旧内容与新想法之间做选择。

        工具，应该接在动作之后。

        翻译、格式整理和固定的工作流程，都是为了让已经找到的内容更容易使用。工具不该打断你，也不该让一个简单的动作变成一连串设置。需要的时候出现，完成以后把空间还给你。

        流动，也意味着尊重边界。

        界面应该回应你的操作，而不是抢走注意力。动画告诉你内容从哪里来、到哪里去；清楚的反馈让你知道发生了什么。轻快的运行、完整的原文和可以理解的操作，是这份体验的基础。

        我们相信，好用的软件会慢慢融入习惯。它不需要每一次都提醒你自己的存在，只需要在你需要的时候，让那段文字、那张图片、那个念头重新回到眼前。

        从一次复制，到下一次使用。
        感觉在流动。
        """))
        let notes = [
            "忙着一头焦虑的话，尝试洗一个澡。",
            "如果没有办法开始，告诉自己一天只需要工作 8 个小时。"
        ]
        items += notes.enumerated().map { text(Int64($0.offset + 4), $0.element) }
        return items
    }
}

/// First-run instruction before the clipboard workspace is opened.
private struct ClipboardLaunchPrompt: View {
    let tour: ClipboardOnboardingCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    private var keys: [(symbol: String, name: String)] {
        let config = HotKeyPreferences.load()
        let modifiers: [(UInt32, String, String)] = [
            (UInt32(cmdKey), "⌘", "Command"),
            (UInt32(shiftKey), "⇧", "Shift"),
            (UInt32(optionKey), "⌥", "Option"),
            (UInt32(controlKey), "⌃", "Control")
        ]
        let selected = modifiers.filter { config.modifierFlags & $0.0 != 0 }
            .map { (symbol: $0.1, name: $0.2) }
        let letter = String(config.displayString.drop(while: { "⌘⇧⌥⌃".contains($0) }))
        return selected + [(symbol: letter, name: "")]
    }
    var body: some View {
        ZStack {
            OnboardingFeatheredBlur(regions: [CGRect(x: 20, y: 0, width: 500, height: 148)])
            VStack(spacing: 12) {
                Text("呼出剪贴板")
                    .font(.pingFang(size: 22, weight: .semibold))
                    .shadow(color: .white.opacity(0.8), radius: 3)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                HStack(spacing: 18) {
                    if TrackpadRevealMonitor.shared.status == .listening {
                        VStack(spacing: 4) {
                            ClipboardFingerDemo(vertical: true, travel: 34)
                                .frame(width: 94, height: 66)
                            Text("双指滑至上边缘").font(.pingFang(size: 11, weight: .medium))
                        }
                        .accessibilityLabel("双指从触控板上半区向上滑至上边缘，呼出剪贴板")
                        Text("或").font(.pingFang(size: 13)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                            keycap(key.symbol, name: key.name, index: index)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("按下 " + keys.map { $0.name.isEmpty ? $0.symbol : $0.name }.joined(separator: " + "))
                }
            }
        }
        .frame(width: 540, height: 148)
        .onAppear { breathing = true }
    }
    private func keycap(_ symbol: String, name: String, index: Int) -> some View {
        let pressed = breathing && !reduceMotion
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.16))
                .offset(y: 4)
            VStack(spacing: 4) {
                Text(symbol).font(.pingFang(size: 28, weight: .semibold))
                if !name.isEmpty {
                    Text(name).font(.pingFang(size: 11, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.72)],
                startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.12), lineWidth: 1))
            .offset(y: pressed ? 3 : 0)
            .animation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.15)
                .delay(Double(index) * 0.12).repeatForever(autoreverses: true), value: breathing)
        }
        .frame(width: name.isEmpty ? 64 : 90, height: 66)
        .shadow(color: .black.opacity(0.12), radius: pressed ? 1 : 4, y: 3)
    }
}

/// Display-link target does not retain the tutorial session or outlive its first-stage motion.
@MainActor private final class ClipboardTeaserDisplayTarget: NSObject {
    private weak var session: ClipboardTutorialSession?
    init(session: ClipboardTutorialSession) { self.session = session }
    @objc func tick(_ link: CADisplayLink) { session?.advanceTeaser(at: link.targetTimestamp) }
}
