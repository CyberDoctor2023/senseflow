import Foundation

/// Adapts document operations to the same serial owner used by clipboard capture.
final class DocumentRepository: HistoryContentRepository {
    private let store: DatabaseManager
    init(store: DatabaseManager) { self.store = store }
    func loadDetail(itemID: Int64, revision: String) async throws -> ClipboardItem {
        try await store.performStoreOperation { try self.store.loadHistoryDetail(itemID: itemID, revision: revision) }
    }
    func saveDerived(text: String, source: DocumentSnapshot, requestID: UUID) async throws -> Int64 {
        try await store.performStoreOperation { try self.store.saveDocumentVersion(text: text, source: source, requestID: requestID) }
    }
    func recover(sourceID: Int64) async throws -> DocumentDraft? {
        try await store.performStoreOperation { try self.store.recoverDocumentDraft(sourceID: sourceID) }
    }
    func checkpoint(_ draft: DocumentDraft) async throws {
        try await store.performStoreOperation { try self.store.checkpointDocumentDraft(draft) }
    }
    func discard(sessionID: UUID, generation: Int) async throws {
        try await store.performStoreOperation { try self.store.discardDocumentDraft(sessionID: sessionID, generation: generation) }
    }
}
