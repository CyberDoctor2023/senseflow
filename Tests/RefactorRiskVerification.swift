import Foundation
import AppKit
@testable import SenseFlow

/// Exercises production persistence and retained-memory limits in an isolated database.
/// A controlled read models a slow, non-cancellable SQL result arriving after a newer search.
@main struct RefactorRiskVerification {
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DatabaseManager(databaseURL: directory.appendingPathComponent("history.sqlite"))
        let boundaries: [Date?] = [nil, Date()]
        for screenshots in [false, true] {
            for recordings in [false, true] {
                for since in boundaries {
                    let predicate = SystemCaptureService.capturePredicate(screenshots: screenshots, recordings: recordings, since: since)
                    if screenshots || recordings {
                        guard let predicate else { throw Failure("capture predicate missing") }
                        let query = NSMetadataQuery()
                        query.searchScopes = [directory.path]
                        query.predicate = predicate
                        try require(query.start(), "Spotlight starts the selected capture categories and date boundary")
                        query.stop()
                    } else { try require(predicate == nil, "disabled capture categories do not start discovery") }
                }
            }
        }
        let tools = SQLitePromptToolRepository(databaseManager: store)
        let tool = PromptTool(name: "isolated concurrent save", prompt: "keep original input")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<40 { group.addTask { try await tools.save(tool) } }
            try await group.waitForAll()
        }
        let saved = try await tools.findAll()
        try require(saved.count == 1 && saved.first?.id == tool.id, "concurrent saves retain one tool identity")
        let found = try await tools.find(by: tool.toolID)
        try require(found?.prompt == tool.prompt, "primary-key tool lookup preserves prompt")

        let countLimited = InMemoryAPIRequestRecorder(maxRecords: 3, maxBytes: 8192)
        for _ in 0..<10 { await countLimited.record(record(body: "small")) }
        try require(countLimited.allRecords.count == 3, "diagnostic record count evicts the oldest records")
        let recorder = InMemoryAPIRequestRecorder(maxRecords: 50, maxBytes: 2048)
        for _ in 0..<10 { await recorder.record(record(body: String(repeating: "x", count: 700))) }
        try require(recorder.allRecords.count <= 3 && recorder.retainedBytes <= 2048,
                    "record count and duplicated payload bytes remain bounded")
        let prior = recorder.allRecords.map(\.id)
        await recorder.record(record(body: String(repeating: "x", count: 4000)))
        try require(recorder.allRecords.map(\.id) == prior && recorder.retainedBytes <= 2048,
                    "oversized diagnostics do not evict or retain screenshot payloads")
        await recorder.clearAll()
        try require(recorder.allRecords.isEmpty && recorder.retainedBytes == 0 && recorder.lastRecord == nil,
                    "clearing diagnostics releases all retained payloads")

        try await store.performStoreOperation {
            for index in 0..<401 {
                guard store.insertItem(.init(type: .text, textContent: index == 0 ? "func hello() { return 1 }" : "普通段落 \(index)", appName: "isolated")) else {
                    throw Failure("history insert failed")
                }
            }
        }
        let content = DocumentRepository(store: store)
        let model = makeModel(repository: DatabaseClipboardRepository(databaseManager: store), content: content)
        await model.loadItems()
        await model.selectType(.code)
        try require(model.items.count == 1 && model.items.first?.textContent?.contains("func hello") == true,
                    "empty filtered pages advance to a matching older record")
        model.isWindowPinned = true
        let pinnedIDs = model.items.map(\.id)
        _ = try await store.performStoreOperation { store.insertItem(.init(type: .text, textContent: "func newCode() {}", appName: "isolated")) }
        await model.loadItems()
        try require(model.items.map(\.id) == pinnedIDs, "pinned content resists new database writes")

        let slow = ControlledHistoryRepository(old: sample(id: 1, text: "旧结果"), new: sample(id: 2, text: "最新结果"))
        let racing = makeModel(repository: slow, content: content)
        let initial = Task { await racing.loadItems() }
        while !(await slow.hasStarted) { await Task.yield() }
        await racing.performSearch(query: "最新")
        await slow.releaseOldRead()
        await initial.value
        try require(racing.items.first?.id == 2 && !racing.isLoading,
                    "late cancelled read cannot replace the newer search or loading state")
        let changing = ControlledHistoryRepository(old: sample(id: 3, text: "写入前"), new: sample(id: 4, text: "写入后"))
        let refreshed = makeModel(repository: changing, content: content)
        let read = Task { await refreshed.loadItems() }
        while !(await changing.hasStarted) { await Task.yield() }
        refreshed.historyDidChange()
        refreshed.historyDidChange()
        await changing.releaseOldRead()
        await read.value
        try require(refreshed.items.first?.id == 4 && !refreshed.isLoading,
                    "writes during an in-flight snapshot coalesce into a latest read")
        var imageIDs: [Int64] = []
        for index in 0..<3 {
            let image = NSImage(size: NSSize(width: 1200, height: 400))
            image.lockFocus()
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1200, height: 400)).fill()
            ("History recognition \(index)" as NSString).draw(at: NSPoint(x: 60, y: 170), withAttributes: [
                .font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black
            ])
            image.unlockFocus()
            guard let data = image.tiffRepresentation else { throw Failure("image preparation failed") }
            try await store.performStoreOperation {
                guard store.insertItem(.init(type: .image, imageData: data, appName: "isolated")) else {
                    throw Failure("image insert failed")
                }
            }
            let latest = try await store.fetchRecentItemsAsync(limit: 1)
            guard let id = latest.first?.id else { throw Failure("image row missing") }
            imageIDs.append(id)
        }
        let removed = imageIDs[1]
        store.deleteItem(id: removed)
        let deadline = Date().addingTimeInterval(60)
        var recognized = false
        repeat {
            let rows = try await store.fetchRecentItemsAsync(limit: 10)
            let details = try await store.performStoreOperation {
                try rows.filter { imageIDs.contains($0.id) }.map { try store.loadHistoryDetail(itemID: $0.id, revision: $0.uniqueId) }
            }
            recognized = imageIDs.filter { $0 != removed }.allSatisfy { id in
                details.contains { $0.id == id && $0.ocrText?.contains("History") == true }
            }
            if recognized { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        } while Date() < deadline
        try require(recognized, "one OCR consumer recognizes queued external originals across a deletion")
        let remaining = try await store.fetchRecentItemsAsync(limit: 10)
        try require(!remaining.contains { $0.id == removed }, "late recognition cannot recreate a deleted image")
        guard let summary = remaining.first(where: { imageIDs.contains($0.id) }) else { throw Failure("recognized image missing") }
        let thumbnails = ClipboardThumbnailLoader(repository: content, maxBytes: 1_048_576, maxCount: 2)
        guard let hot = await thumbnails.thumbnail(for: summary, pixels: 96),
              let cold = await thumbnails.thumbnail(for: summary, pixels: 120) else { throw Failure("thumbnail preparation failed") }
        _ = await thumbnails.thumbnail(for: summary, pixels: 96)
        _ = await thumbnails.thumbnail(for: summary, pixels: 160)
        let retained = await thumbnails.thumbnail(for: summary, pixels: 96)
        let rebuilt = await thumbnails.thumbnail(for: summary, pixels: 120)
        try require(retained === hot && rebuilt !== cold, "cache pressure retains the recently used thumbnail and evicts only the cold one")
        let tinyCache = ClipboardThumbnailLoader(repository: content, maxBytes: 32, maxCount: 2)
        let oversizedFirst = await tinyCache.thumbnail(for: summary, pixels: 96)
        let oversizedSecond = await tinyCache.thumbnail(for: summary, pixels: 96)
        try require(oversizedFirst != nil && oversizedSecond != nil && oversizedFirst !== oversizedSecond,
                    "a thumbnail above the byte budget remains usable without being retained")
        let original = try await store.performStoreOperation { try store.loadHistoryDetail(itemID: summary.id, revision: summary.uniqueId) }
        let sharedRepository = GatedThumbnailRepository(content: content)
        let sharedLoader = ClipboardThumbnailLoader(repository: sharedRepository)
        let firstWaiter = Task { await sharedLoader.thumbnail(for: summary, pixels: 96) }
        let secondWaiter = Task { await sharedLoader.thumbnail(for: summary, pixels: 96) }
        while await sharedRepository.loads < 1 { await Task.yield() }
        // Allow both consumers to register before cancellation; the gate prevents completion.
        for _ in 0..<20 { await Task.yield() }
        firstWaiter.cancel()
        let cancelled = await firstWaiter.value
        await sharedRepository.releaseAll()
        let survivor = await secondWaiter.value
        let sharedReads = await sharedRepository.loads
        try require(cancelled == nil && survivor != nil && sharedReads == 1,
                    "cancelling one thumbnail waiter preserves the shared request")
        let boundedRepository = GatedThumbnailRepository(content: content)
        let boundedLoader = ClipboardThumbnailLoader(repository: boundedRepository)
        let activeFirst = Task { await boundedLoader.thumbnail(for: summary, pixels: 96) }
        let activeSecond = Task { await boundedLoader.thumbnail(for: summary, pixels: 120) }
        while await boundedRepository.loads < 2 { await Task.yield() }
        let queued = Task { await boundedLoader.thumbnail(for: summary, pixels: 160) }
        for _ in 0..<20 { await Task.yield() }
        queued.cancel()
        let queuedResult = await queued.value
        await boundedRepository.releaseAll()
        let activeImages = [await activeFirst.value, await activeSecond.value]
        let boundedReads = await boundedRepository.loads
        let peakLoads = await boundedRepository.peakLoads
        try require(queuedResult == nil && activeImages.allSatisfy { $0 != nil } && boundedReads == 2 && peakLoads == 2,
                    "queued cancellation avoids original reads and concurrent loads stay bounded")
        let replacementRepository = GatedThumbnailRepository(content: content)
        let replacementLoader = ClipboardThumbnailLoader(repository: replacementRepository)
        let obsolete = Task { await replacementLoader.thumbnail(for: summary, pixels: 96) }
        while await replacementRepository.loads < 1 { await Task.yield() }
        obsolete.cancel()
        let obsoleteImage = await obsolete.value
        let replacement = Task { await replacementLoader.thumbnail(for: summary, pixels: 96) }
        while await replacementRepository.loads < 2 { await Task.yield() }
        await replacementRepository.releaseAll()
        let replacementImage = await replacement.value
        try require(obsoleteImage == nil && replacementImage != nil,
                    "a cancelled load's late completion cannot remove its same-key replacement")
        let data = try await HistoryMediaLoader.imageData(for: original)
        let otherDirectory = directory.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: otherDirectory, withIntermediateDirectories: true)
        let otherStore = DatabaseManager(databaseURL: otherDirectory.appendingPathComponent("history.sqlite"))
        _ = try await otherStore.performStoreOperation { otherStore.insertItem(.init(type: .image, imageData: data, appName: "isolated")) }
        let otherRows = try await otherStore.fetchRecentItemsAsync(limit: 1)
        guard let other = otherRows.first, let otherPath = other.blobPath else { throw Failure("second store original missing") }
        store.clearAllItems()
        try require(FileManager.default.fileExists(atPath: otherPath), "clearing one database preserves another database's identical original")
        print("PASS refactor risk verification; no user history, credentials or clipboard writes")
    }

    @MainActor private static func makeModel(repository: ClipboardRepositoryProtocol, content: HistoryContentRepository) -> ClipboardListViewModel {
        let writer = NoEffectsWriter()
        let documents = DocumentPreviewCoordinator(repository: content, writer: writer,
            host: DocumentWindowHost(workspace: WorkspaceWindowCoordinator()))
        return ClipboardListViewModel(repository: repository,
            actions: HistoryActionCoordinator(documents: documents, repository: content, writer: writer, onPaste: {}),
            thumbnails: ClipboardThumbnailLoader(repository: content))
    }
    private static func record(body: String) -> APIRequestRecord {
        APIRequestRecord(toolName: "isolated", serviceType: "offline", modelName: "none",
                         requestBodyJSON: body, messagesJSON: body)
    }
    private static func sample(id: Int64, text: String) -> ClipboardItem {
        ClipboardItem(id: id, uniqueId: UUID().uuidString, type: .text, textContent: text,
                      imageData: nil, blobPath: nil, timestamp: id, appName: "isolated", appPath: nil)
    }
    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message) }
        print("PASS \(message)")
    }
    struct Failure: Error { let message: String; init(_ message: String) { self.message = message } }
}

private actor ControlledHistoryRepository: ClipboardRepositoryProtocol {
    let old: ClipboardItem
    let new: ClipboardItem
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var hasStarted = false
    init(old: ClipboardItem, new: ClipboardItem) { self.old = old; self.new = new }
    func fetchRecent(limit: Int, offset: Int) async throws -> [ClipboardItem] {
        if hasStarted { return [new] }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            hasStarted = true
        }
        return [old]
    }
    func search(query: String, limit: Int, offset: Int) async throws -> [ClipboardItem] { [new] }
    func releaseOldRead() { continuation?.resume(); continuation = nil }
}
private struct NoEffectsWriter: ClipboardWriter {
    func write(_ text: String) async {}
    func write(_ content: ClipboardContent) async {}
}

/// Holds real repository reads at their asynchronous boundary, without inspecting production IDs.
private actor GatedThumbnailRepository: HistoryContentRepository {
    let content: HistoryContentRepository
    private var gates: [CheckedContinuation<Void, Never>] = []
    private var released = false
    private var active = 0
    private(set) var loads = 0
    private(set) var peakLoads = 0
    init(content: HistoryContentRepository) { self.content = content }
    func loadDetail(itemID: Int64, revision: String) async throws -> ClipboardItem {
        loads += 1; active += 1; peakLoads = max(peakLoads, active)
        if !released { await withCheckedContinuation { gates.append($0) } }
        defer { active -= 1 }
        return try await content.loadDetail(itemID: itemID, revision: revision)
    }
    func releaseAll() {
        released = true
        let pending = gates; gates.removeAll()
        for gate in pending { gate.resume() }
    }
    func saveDerived(text: String, source: DocumentSnapshot, requestID: UUID) async throws -> Int64 {
        try await content.saveDerived(text: text, source: source, requestID: requestID)
    }
    func recover(sourceID: Int64) async throws -> DocumentDraft? { try await content.recover(sourceID: sourceID) }
    func checkpoint(_ draft: DocumentDraft) async throws { try await content.checkpoint(draft) }
    func discard(sessionID: UUID, generation: Int) async throws { try await content.discard(sessionID: sessionID, generation: generation) }
}
