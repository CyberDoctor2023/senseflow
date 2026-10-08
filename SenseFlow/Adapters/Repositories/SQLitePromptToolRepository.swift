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
    case notFound

    var errorDescription: String? {
        switch self {
        case .insertFailed:
            return "插入数据失败"
        case .updateFailed:
            return "更新数据失败"
        case .deleteFailed:
            return "删除数据失败"
        case .notFound:
            return "数据未找到"
        }
    }
}

//
// 【扩展阅读】
//
// Repository Pattern 的最佳实践：
// 1. 接口应该面向领域，不是数据库
//    - ✅ find(by: UserID)
//    - ❌ getUserById(id: Int)
//
// 2. 返回领域对象，不是数据库记录
//    - ✅ [PromptTool]
//    - ❌ [PromptToolRecord]
//
// 3. 使用领域类型，不是原始类型
//    - ✅ ToolID
//    - ❌ UUID
//
// 4. 保持接口简单，不要过度设计
//    - ✅ findAll(), save(), delete()
//    - ❌ findByNameAndCreatedAtBetween(...)
//
// 5. 考虑性能，但不过早优化
//    - 先实现功能
//    - 发现性能问题再优化
//    - 使用缓存、索引、分页等技术
//
// Repository vs Active Record：
// - Active Record：领域对象自己负责持久化
//   ```swift
//   tool.save()  // 对象自己保存
//   ```
// - Repository：专门的对象负责持久化
//   ```swift
//   repository.save(tool)  // Repository 保存对象
//   ```
//
// Repository 的优点：
// - 关注点分离：领域对象不关心持久化
// - 易于测试：可以 Mock Repository
// - 易于切换：可以更换数据源
//
// Active Record 的优点：
// - 简单直观：对象自己管理自己
// - 代码更少：不需要额外的 Repository 类
//
