import Foundation
import SQLite

/// Migrates retained clipboard columns without touching unrelated legacy user data.
final class DatabaseMigrationManager {
    private let db: Connection
    init(db: Connection) { self.db = db }

    func migrateIfNeeded() throws {
        let columns = Set(try db.prepare("PRAGMA table_info(clipboard_history)").compactMap { $0[1] as? String })
        try db.transaction {
            for column in ["app_path", "ocr_text"] where !columns.contains(column) {
                try db.run("ALTER TABLE clipboard_history ADD COLUMN \(column) TEXT")
            }
            db.userVersion = max(db.userVersion ?? 0, 6)
        }
    }
}
