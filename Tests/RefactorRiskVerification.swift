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
        let original = try await store.performStoreOperation { try store.loadHistoryDetail(itemID: summary.id, revision: summary.uniqueId) }
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
