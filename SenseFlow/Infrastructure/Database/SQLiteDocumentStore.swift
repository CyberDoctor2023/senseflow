import Foundation
import SQLite

/// Document transactions operate only inside DatabaseManager's serial store queue.
/// History insertion is supplied by the owner, keeping media/OCR outside this component.
struct SQLiteDocumentStore {
    let db: Connection
    private let historyTable = Table("clipboard_history")
    private let id = Expression<Int64>("id")
    private let uniqueId = Expression<String>("unique_id")
    private let timestamp = Expression<Int64>("timestamp")
    func createTables() throws {
        try db.run("CREATE TABLE IF NOT EXISTS document_drafts (session_id TEXT PRIMARY KEY, source_id INTEGER NOT NULL UNIQUE, base_revision TEXT NOT NULL, generation INTEGER NOT NULL, text TEXT NOT NULL, source_name TEXT NOT NULL, source_path TEXT, source_timestamp INTEGER NOT NULL)")
        try db.run("CREATE TABLE IF NOT EXISTS document_versions (request_id TEXT PRIMARY KEY, source_id INTEGER, item_id INTEGER NOT NULL)")
    }

    /// Idempotent save with stable deduplication and source linkage in one transaction.
    func saveVersion(text: String, source: DocumentSnapshot, requestID: UUID, createText: (String) throws -> Int64) throws -> Int64 {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DocumentStoreError.empty }
        var result: Int64 = 0
        try db.transaction {
            let versions = Table("document_versions")
            let request = Expression<String>("request_id")
            let savedID = Expression<Int64>("item_id")
            if let prior = try db.pluck(versions.filter(request == requestID.uuidString)) {
                result = prior[savedID]
                return
            }
            let hash = text.sha256()
            if let existing = try db.pluck(historyTable.filter(uniqueId == hash)) {
                result = existing[id]
                try db.run(historyTable.filter(id == result).update(timestamp <- Int64(Date().timeIntervalSince1970)))
            } else {
                result = try createText(hash)
            }
            try db.run(versions.insert(request <- requestID.uuidString,
                                      Expression<Int64>("source_id") <- source.itemID, savedID <- result))
        }
        return result
    }

    /// Rejects old checkpoints; committed generation cannot move backwards.
    func checkpoint(_ draft: DocumentDraft) throws {
        try db.transaction {
            let drafts = Table("document_drafts")
            let sid = Expression<String>("session_id")
            let generation = Expression<Int>("generation")
            if let existing = try db.pluck(drafts.filter(sid == draft.sessionID.uuidString)), existing[generation] > draft.generation {
                throw DocumentStoreError.stale
            }
            try db.run("INSERT INTO document_drafts (session_id,source_id,base_revision,generation,text,source_name,source_path,source_timestamp) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(session_id) DO UPDATE SET generation=excluded.generation,text=excluded.text,base_revision=excluded.base_revision",
                       draft.sessionID.uuidString, draft.source.itemID, draft.source.revision, draft.generation,
                       draft.text, draft.source.appName, draft.source.appPath, draft.source.timestamp)
        }
    }

    func recover(sourceID: Int64) throws -> DocumentDraft? {
        let drafts = Table("document_drafts")
        guard let row = try db.pluck(drafts.filter(Expression<Int64>("source_id") == sourceID)),
              let sessionID = UUID(uuidString: row[Expression<String>("session_id")]) else { return nil }
        let source = DocumentSnapshot(itemID: sourceID, revision: row[Expression<String>("base_revision")], text: "",
                                      appName: row[Expression<String>("source_name")], appPath: row[Expression<String?>("source_path")],
                                      timestamp: row[Expression<Int64>("source_timestamp")])
        return DocumentDraft(sessionID: sessionID, source: source, generation: row[Expression<Int>("generation")], text: row[Expression<String>("text")])
    }

    func discard(sessionID: UUID, generation: Int) throws {
        let drafts = Table("document_drafts")
        let selection = drafts.filter(Expression<String>("session_id") == sessionID.uuidString)
        if let row = try db.pluck(selection), row[Expression<Int>("generation")] > generation { throw DocumentStoreError.stale }
        try db.run(selection.delete())
    }
}
