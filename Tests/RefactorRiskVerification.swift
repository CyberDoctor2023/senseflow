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
