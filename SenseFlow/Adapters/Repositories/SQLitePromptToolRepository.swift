import Foundation

/// Tool persistence uses the same serial database owner as history and document saves.
final class SQLitePromptToolRepository: PromptToolRepository {
    private let databaseManager: DatabaseManager
    init(databaseManager: DatabaseManager) { self.databaseManager = databaseManager }

    func findAll() async throws -> [PromptTool] {
        try await databaseManager.performStoreOperation { self.databaseManager.fetchAllPromptTools() }
    }
    func find(by id: ToolID) async throws -> PromptTool? {
        try await databaseManager.performStoreOperation { try self.databaseManager.fetchPromptTool(id: id.value) }
    }
    /// Lookup and write share one queue operation, preventing competing saves from inserting twice.
    func save(_ tool: PromptTool) async throws {
        try await databaseManager.performStoreOperation {
            if try self.databaseManager.fetchPromptTool(id: tool.id) != nil {
                guard self.databaseManager.updatePromptTool(tool) else { throw RepositoryError.updateFailed }
            } else {
                guard self.databaseManager.insertPromptTool(tool) else { throw RepositoryError.insertFailed }
            }
        }
    }
    func delete(id: ToolID) async throws {
        try await databaseManager.performStoreOperation {
            guard self.databaseManager.deletePromptTool(id: id.value) else { throw RepositoryError.deleteFailed }
        }
    }
    func findDefaults() async throws -> [PromptTool] {
        try await findAll().filter { $0.isDefault }
    }
}

enum RepositoryError: LocalizedError {
    case insertFailed
    case updateFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .insertFailed:
            return "插入数据失败"
        case .updateFailed:
            return "更新数据失败"
        case .deleteFailed:
            return "删除数据失败"
        }
    }
}
