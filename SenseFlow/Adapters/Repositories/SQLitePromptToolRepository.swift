//
//  SQLitePromptToolRepository.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - Repository Pattern（仓库模式）】
//  这是 Domain-Driven Design (DDD) 的核心模式之一
//
//  什么是 Repository（仓库）？
//  - Repository 是数据访问的抽象层
//  - 它提供类似"集合"的接口来访问领域对象
//  - 隐藏数据存储的实现细节（SQLite、CoreData、网络 API）
//
//  为什么需要 Repository？
//  1. 隔离数据源：业务逻辑不关心数据来自哪里
//  2. 统一接口：所有数据访问通过统一的方法（findAll、save、delete）
//  3. 易于测试：可以用 MockRepository 替换真实实现
//  4. 易于切换：从 SQLite 切换到 CoreData 只需修改 Repository
//
//  【Repository Pattern 可视化】
//  ```
//  ┌─────────────────────────────────────┐
//  │  Business Logic (Use Case)          │
//  │                                     │
//  │  coordinator.loadTools()            │
//  │         ↓                           │
//  │  repository.findAll()               │  ← 调用接口
//  └─────────────────────────────────────┘
//              ↓ 依赖
//  ┌─────────────────────────────────────┐
//  │  PromptToolRepository (接口)         │  ← Port
//  │  - findAll()                        │
//  │  - save()                           │
//  │  - delete()                         │
//  └─────────────────────────────────────┘
//              ↑ 实现
//  ┌─────────────────────────────────────┐
//  │  SQLitePromptToolRepository         │  ← Adapter（这个文件）
//  │  (实现 PromptToolRepository)         │
//  └─────────────────────────────────────┘
//              ↓ 调用
//  ┌─────────────────────────────────────┐
//  │  DatabaseManager                    │  ← 遗留代码
//  │  (SQLite 封装)                       │
//  └─────────────────────────────────────┘
//  ```
//
//  【对比传统方式】
//  ❌ 传统方式（直接访问数据库）：
//  ```swift
//  class PromptToolCoordinator {
//      func loadTools() {
//          let db = DatabaseManager.shared
//          let tools = db.fetchAllPromptTools()  // 直接依赖数据库
//      }
//  }
//  ```
//  问题：
//  - 业务逻辑和数据访问紧耦合
//  - 无法切换数据源
//  - 难以测试
//
//  ✅ Repository 方式（依赖接口）：
//  ```swift
//  class PromptToolCoordinator {
//      private let repository: PromptToolRepository  // 依赖接口
//
//      func loadTools() {
//          let tools = try await repository.findAll()  // 不关心实现
//      }
//  }
//  ```
//  好处：
//  - 业务逻辑和数据访问解耦
//  - 可以切换数据源（SQLite、CoreData、网络）
//  - 易于测试（MockRepository）
//
//  【Repository 的职责】
//  1. ✅ 应该做：CRUD 操作、查询、过滤
//  2. ❌ 不应该做：业务逻辑、数据验证、复杂计算
//
//  【Repository vs DAO】
//  - DAO (Data Access Object)：面向数据库表
//  - Repository：面向领域对象（Domain Entity）
//
//  Repository 更高层，提供领域语义：
//  - DAO: `getUserById(id: Int)`
//  - Repository: `find(by: UserID)`（使用领域类型）
//

import Foundation

/// SQLite 实现的 PromptToolRepository（Adapter）
///
/// 【职责】
/// 将 PromptToolRepository 接口适配到 DatabaseManager（遗留代码）
///
/// 【设计模式】
/// 1. Repository Pattern：数据访问抽象
/// 2. Adapter Pattern：适配遗留代码
/// 3. Collection-like Interface：类似集合的接口
///
/// 【为什么叫 SQLitePromptToolRepository？】
/// - SQLite：表明使用 SQLite 数据库
/// - PromptTool：表明管理 PromptTool 实体
/// - Repository：表明是仓库模式
///
/// 【未来可能的实现】
/// - CoreDataPromptToolRepository：使用 CoreData
/// - CloudKitPromptToolRepository：使用 CloudKit
/// - InMemoryPromptToolRepository：内存实现（测试用）
/// - MockPromptToolRepository：Mock 实现（测试用）
///
/// 【依赖】
/// - DatabaseManager：现有的数据库管理器（遗留代码）
/// - PromptToolRepository：接口定义
final class SQLitePromptToolRepository: PromptToolRepository {
    /// 数据库管理器
    ///
    /// 【依赖注入】
    /// 通过构造器注入，不使用 DatabaseManager.shared
    /// 这样更易于测试和替换
    private let databaseManager: DatabaseManager

    /// 构造器注入
    ///
    /// 【为什么注入 DatabaseManager？】
    /// 即使是适配遗留代码，也要遵循依赖注入原则
    /// 这样可以：
    /// 1. 测试时注入 Mock DatabaseManager
    /// 2. 使用不同的数据库实例
    /// 3. 避免全局单例的问题
    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    /// 查找所有工具
    ///
    /// 【实现方式】
    /// 直接调用 DatabaseManager 的方法
    ///
    /// 【为什么不是 async？】
    /// 因为 DatabaseManager 的方法是同步的（遗留代码）
    /// 但接口定义是 async（为了未来扩展）
    /// 所以这里是同步实现异步接口
    ///
    /// 【未来优化】
    /// 可以在这里添加：
    /// 1. 缓存：避免频繁查询数据库
    /// 2. 分页：支持大量数据
    /// 3. 排序：按名称、创建时间等排序
    /// 4. 过滤：只返回特定条件的工具
    func findAll() async throws -> [PromptTool] {
        return databaseManager.fetchAllPromptTools()
    }

    /// 根据 ID 查找工具
    ///
    /// 【实现细节】
    /// 1. 查询所有工具
    /// 2. 在内存中过滤
    ///
    /// 【为什么不直接查询数据库？】
    /// 因为 DatabaseManager 没有提供按 ID 查询的方法（遗留代码限制）
    /// 这是一个性能问题，未来应该优化
    ///
    /// 【性能问题】
    /// 每次查询都要加载所有工具，效率低
    /// 解决方案：
    /// 1. 给 DatabaseManager 添加 `fetchPromptTool(id:)` 方法
    /// 2. 在 Repository 中添加缓存
    /// 3. 使用索引优化数据库查询
    ///
    /// 【ToolID 类型】
    /// 注意这里使用 ToolID 类型（Value Object）
    /// 而不是原始的 UUID
    /// 这是 DDD 的最佳实践：用类型系统表达领域概念
    func find(by id: ToolID) async throws -> PromptTool? {
        let tools = databaseManager.fetchAllPromptTools()
        return tools.first { ToolID($0.id) == id }
    }

    /// 保存工具（插入或更新）
    ///
    /// 【Upsert 语义】
    /// 这个方法实现了 "Upsert" 语义：
    /// - 如果工具存在：更新
    /// - 如果工具不存在：插入
    ///
    /// 【实现步骤】
    /// 1. 检查工具是否存在
    /// 2. 存在则更新，不存在则插入
    ///
    /// 【为什么不让数据库处理？】
    /// 理想情况下应该用 SQL 的 `INSERT OR REPLACE`
    /// 但 DatabaseManager 没有提供这个功能（遗留代码限制）
    ///
    /// 【事务问题】
    /// 这个实现不是原子的：
    /// 1. 查询（find）
    /// 2. 更新或插入（update/insert）
    /// 中间可能有其他操作
    ///
    /// 解决方案：
    /// 1. 使用数据库事务
    /// 2. 使用乐观锁（版本号）
    /// 3. 使用悲观锁（行锁）
    ///
    /// 【错误处理】
    /// 如果更新/插入失败，抛出 RepositoryError
    func save(_ tool: PromptTool) async throws {
        // 【步骤 1】检查是否已存在
        if let _ = try await find(by: tool.toolID) {
            // 【步骤 2a】更新现有工具
            guard databaseManager.updatePromptTool(tool) else {
                throw RepositoryError.updateFailed
            }
        } else {
            // 【步骤 2b】插入新工具
            guard databaseManager.insertPromptTool(tool) else {
                throw RepositoryError.insertFailed
            }
        }
    }

    /// 删除工具
    ///
    /// 【实现方式】
    /// 直接调用 DatabaseManager 的删除方法
    ///
    /// 【ToolID 转换】
    /// 注意这里将 ToolID 转换为 UUID
    /// 因为 DatabaseManager 接受 UUID 类型
    ///
    /// 【错误处理】
    /// 如果删除失败（例如工具不存在），抛出错误
    ///
    /// 【幂等性】
    /// 这个方法不是幂等的：
    /// - 第一次调用：删除成功
    /// - 第二次调用：抛出错误（工具不存在）
    ///
    /// 是否应该幂等？取决于业务需求：
    /// - 幂等：删除不存在的工具不报错（静默成功）
    /// - 非幂等：删除不存在的工具报错（当前实现）
    func delete(id: ToolID) async throws {
        guard databaseManager.deletePromptTool(id: id.value) else {
            throw RepositoryError.deleteFailed
        }
    }

    /// 查找默认工具
    ///
    /// 【业务查询】
    /// 这是一个业务相关的查询方法
    /// 不是基础的 CRUD 操作
    ///
    /// 【实现方式】
    /// 1. 查询所有工具
    /// 2. 在内存中过滤
    ///
    /// 【性能优化】
    /// 应该在数据库层面过滤：
    /// ```sql
    /// SELECT * FROM prompt_tools WHERE is_default = 1
    /// ```
    /// 而不是加载所有数据再过滤
    ///
    /// 【Repository 的边界】
    /// 这个方法展示了 Repository 的一个问题：
    /// - 如果每个业务查询都加一个方法，Repository 会变得很大
    /// - 解决方案：使用 Specification Pattern（规格模式）
    ///
    /// 【Specification Pattern 示例】
    /// ```swift
    /// protocol Specification {
    ///     func isSatisfiedBy(_ tool: PromptTool) -> Bool
    /// }
    ///
    /// struct DefaultToolSpec: Specification {
    ///     func isSatisfiedBy(_ tool: PromptTool) -> Bool {
    ///         return tool.isDefault
    ///     }
    /// }
    ///
    /// func find(matching spec: Specification) -> [PromptTool] {
    ///     return findAll().filter { spec.isSatisfiedBy($0) }
    /// }
    /// ```
    func findDefaults() async throws -> [PromptTool] {
        let tools = databaseManager.fetchAllPromptTools()
        return tools.filter { $0.isDefault }
    }
}

// MARK: - Errors（错误定义）
//
// 【领域错误】
// 这些是 Repository 层特有的错误
// 表示数据访问失败

/// Repository 错误
///
/// 【错误分类】
/// 1. insertFailed：插入失败（例如主键冲突）
/// 2. updateFailed：更新失败（例如记录不存在）
/// 3. deleteFailed：删除失败（例如记录不存在）
/// 4. notFound：查询失败（例如 ID 不存在）
///
/// 【错误处理策略】
/// - 数据库错误：抛出 RepositoryError
/// - 业务错误：在 Use Case 层处理
/// - 技术错误：在 Infrastructure 层处理
///
/// 【LocalizedError 协议】
/// 实现这个协议可以提供用户友好的错误信息
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
