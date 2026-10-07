import Foundation

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

