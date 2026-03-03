//
//  PromptToolCoordinator.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - Coordinator 层】
//  这是 Clean Architecture 的 Coordinator 层（协调器层）
//
//  核心职责：
//  1. 协调多个 Use Case 完成复杂的业务流程
//  2. 处理 UI 层的请求，转换为业务逻辑调用
//  3. 管理业务流程的状态和错误处理
//
//  与 Use Case 的区别：
//  - Use Case：单一业务场景（执行工具、注册快捷键）
//  - Coordinator：组合多个 Use Case（创建工具 = 保存 + 注册快捷键）
//
//  设计模式：
//  1. Facade Pattern（外观模式）
//     - 为复杂的子系统提供简单的接口
//     - UI 层只需调用 Coordinator，不需要知道内部细节
//
//  2. Mediator Pattern（中介者模式）
//     - 协调多个对象之间的交互
//     - 避免对象之间直接耦合
//
//  依赖方向：
//  SwiftUI View → Coordinator → Use Cases → Services
//  所有依赖都指向内层（业务逻辑核心）
//
//  【对比传统 MVC】
//  传统 MVC：
//  - ViewController 直接调用 Model、Service
//  - 业务逻辑分散在多个 ViewController 中
//  - 难以测试、难以复用
//
//  Clean Architecture：
//  - View 只调用 Coordinator
//  - 业务逻辑集中在 Use Case 中
//  - 易于测试、易于复用
//

import Foundation

/// Prompt Tool 协调器
///
/// 【职责范围】
/// 1. CRUD 操作：创建、读取、更新、删除工具
/// 2. 快捷键管理：注册、注销快捷键
/// 3. 工具执行：触发工具执行流程
/// 4. 初始化：首次启动时创建默认工具
///
/// 【为什么需要 Coordinator？】
/// 假设没有 Coordinator，SwiftUI View 需要：
/// ```swift
/// // ❌ View 直接调用多个 Use Case
/// try await repository.save(tool)
/// try hotKeyCoordinator.registerToolHotKey(for: tool) { ... }
/// ```
/// 问题：
/// 1. View 需要知道业务流程细节
/// 2. 业务逻辑分散在多个 View 中
/// 3. 难以保证一致性（忘记注册快捷键？）
///
/// 有了 Coordinator：
/// ```swift
/// // ✅ View 只调用一个方法
/// try await coordinator.createTool(tool)
/// ```
/// 好处：
/// 1. View 不需要知道内部细节
/// 2. 业务逻辑集中管理
/// 3. 保证流程完整性
final class PromptToolCoordinator {
    // MARK: - 依赖（全部通过构造器注入）

    /// 工具仓库（数据访问）
    /// 职责：持久化工具数据
    private let repository: PromptToolRepository

    /// 执行工具用例
    /// 职责：执行工具的业务流程
    private let executeToolUseCase: ExecutePromptTool

    /// 快捷键协调器
    /// 职责：统一处理 Prompt Tool 的快捷键注册/注销
    private let hotKeyCoordinator: PromptToolHotKeyHandling

    /// 构造器注入
    ///
    /// 【依赖注入的三种方式】
    /// 1. Constructor Injection（构造器注入）✅ 推荐
    ///    - 依赖关系清晰
    ///    - 对象创建后立即可用
    ///    - 编译时检查
    ///
    /// 2. Property Injection（属性注入）
    ///    - 可选依赖
    ///    - 可能出现未初始化的依赖
    ///
    /// 3. Method Injection（方法注入）
    ///    - 每次调用时注入
    ///    - 适合临时依赖
    init(
        repository: PromptToolRepository,
        executeToolUseCase: ExecutePromptTool,
        hotKeyCoordinator: PromptToolHotKeyHandling = AppHotKeyCoordinator.shared
    ) {
        self.repository = repository
        self.executeToolUseCase = executeToolUseCase
        self.hotKeyCoordinator = hotKeyCoordinator
    }

    // MARK: - CRUD Operations（增删改查操作）
    //
    // 【设计说明】
    // 这些方法展示了 Coordinator 如何协调多个 Use Case
    // 注意每个操作的"事务性"：要么全部成功，要么全部失败

    /// 加载所有工具
    ///
    /// 【简单委托】
    /// 这是一个简单的委托方法，直接调用 Repository
    /// 为什么不直接让 View 调用 Repository？
    /// 1. 统一入口：所有数据访问都通过 Coordinator
    /// 2. 未来扩展：可能需要添加缓存、过滤等逻辑
    /// 3. 测试友好：可以 Mock Coordinator 而不是 Repository
    func loadTools() async throws -> [PromptTool] {
        return try await repository.findAll()
    }

    /// 创建工具（便捷方法）
    ///
    /// 【Convenience Method 便捷方法】
    /// 这是一个便捷方法，简化 UI 层的调用
    /// UI 层不需要手动创建 PromptTool 对象
    func createTool(
        name: String,
        prompt: String,
        capabilities: [PromptToolCapability] = [],
        shortcutKeyCode: UInt16,
        shortcutModifiers: UInt32
    ) async throws {
        // 创建 Domain Entity（领域实体）
        let tool = PromptTool(
            name: name,
            prompt: prompt,
            capabilities: capabilities,
            shortcutKeyCode: shortcutKeyCode,
            shortcutModifiers: shortcutModifiers
        )
        // 调用完整的创建流程
        try await createTool(tool)
    }

    /// 创建工具（完整流程）
    ///
    /// 【业务流程协调】
    /// 这个方法展示了 Coordinator 的核心价值：协调多个操作
    ///
    /// 业务规则：
    /// 1. 创建工具 = 保存数据 + 注册快捷键
    /// 2. 两个操作必须都成功，否则回滚
    ///
    /// 【事务性（Transaction）】
    /// 理想情况下应该有事务支持：
    /// ```swift
    /// try await transaction {
    ///     try await repository.save(tool)
    ///     try hotKeyCoordinator.registerToolHotKey(for: tool) { ... }
    /// }
    /// ```
    /// 但由于涉及系统 API（快捷键注册），无法完全事务化
    /// 所以采用"先保存后注册"的策略
    ///
    /// 【错误处理】
    /// - 如果保存失败：抛出错误，快捷键不会注册
    /// - 如果注册失败：抛出错误，但数据已保存（需要手动清理）
    func createTool(_ tool: PromptTool) async throws {
        // 【步骤 1】保存到数据库
        // 为什么先保存？因为快捷键回调需要查询数据库
        try await repository.save(tool)

        // 【步骤 2】注册快捷键
        // 注意：这里使用了闭包（Closure）作为回调
        // [weak self] 避免循环引用（Retain Cycle）
        try hotKeyCoordinator.registerToolHotKey(for: tool) { [weak self] in
            // 快捷键触发时的回调
            // Task { @MainActor in ... } 确保在主线程执行
            Task { @MainActor in
                // 执行工具
                try? await self?.executeTool(id: tool.toolID)
            }
        }
    }

    /// 更新工具
    ///
    /// 【更新流程】
    /// 更新比创建复杂，因为需要处理旧状态：
    /// 1. 注销旧快捷键（避免冲突）
    /// 2. 保存新数据
    /// 3. 注册新快捷键
    ///
    /// 【为什么要注销旧快捷键？】
    /// 假设用户修改了快捷键：
    /// - 旧快捷键：⌘⌥V
    /// - 新快捷键：⌘⌥C
    /// 如果不注销旧的，两个快捷键都会触发同一个工具
    func updateTool(_ tool: PromptTool) async throws {
        // 【步骤 1】注销旧快捷键
        // 即使工具没有快捷键，调用 unregister 也是安全的（幂等操作）
        hotKeyCoordinator.unregisterToolHotKey(for: tool.toolID)

        // 【步骤 2】保存更新
        try await repository.save(tool)

        // 【步骤 3】注册新快捷键
        try hotKeyCoordinator.registerToolHotKey(for: tool) { [weak self] in
            Task { @MainActor in
                try? await self?.executeTool(id: tool.toolID)
            }
        }
    }

    /// 删除工具
    ///
    /// 【删除流程】
    /// 删除也需要协调两个操作：
    /// 1. 注销快捷键（释放系统资源）
    /// 2. 删除数据
    ///
    /// 【顺序很重要】
    /// 先注销快捷键，再删除数据
    /// 为什么？如果先删除数据，快捷键回调可能找不到工具
    func deleteTool(id: ToolID) async throws {
        // 【步骤 1】注销快捷键
        hotKeyCoordinator.unregisterToolHotKey(for: id)

        // 【步骤 2】删除数据
        try await repository.delete(id: id)
    }

    /// 恢复默认工具
    func restoreDefaultTools() async throws {
        let existingTools = try await repository.findAll()
        let defaultTools = PromptTool.defaultTools

        for defaultTool in defaultTools {
            try await restoreOrCreateDefaultTool(defaultTool, existingTools: existingTools)
        }

        // 重新注册所有快捷键
        try await registerAllHotKeys()

        print("✅ 默认 Prompt Tools 已恢复")
    }

    /// 恢复或创建单个默认工具
    private func restoreOrCreateDefaultTool(_ defaultTool: PromptTool, existingTools: [PromptTool]) async throws {
        // 查找已存在的同名默认工具
        if let existing = existingTools.first(where: { $0.name == defaultTool.name && $0.isDefault }) {
            // 重置为默认 prompt
            let updated = PromptTool(
                id: existing.id,
                name: existing.name,
                prompt: defaultTool.prompt,
                capabilities: defaultTool.capabilities,
                shortcutKeyCode: existing.shortcutKeyCode,
                shortcutModifiers: existing.shortcutModifiers,
                isDefault: true,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                source: existing.source,
                remoteId: existing.remoteId,
                remoteAuthor: existing.remoteAuthor,
                remoteVotes: existing.remoteVotes,
                remoteUpdatedAt: existing.remoteUpdatedAt,
                langfuseName: existing.langfuseName,
                langfuseVersion: existing.langfuseVersion,
                langfuseLabels: existing.langfuseLabels,
                lastSyncedAt: existing.lastSyncedAt
            )
            try await repository.save(updated)
        } else if !existingTools.contains(where: { $0.name == defaultTool.name }) {
            // 工具名称不存在，创建新工具
            try await repository.save(defaultTool)
        }
    }

    // MARK: - Execution（执行流程）
    //
    // 【职责分离】
    // Coordinator 负责"找到工具"，Use Case 负责"执行工具"
    // 这是单一职责原则的体现

    /// 执行工具
    ///
    /// 【查找 + 执行模式】
    /// 这个方法展示了一个常见的模式：
    /// 1. 根据 ID 查找实体
    /// 2. 验证实体存在
    /// 3. 委托给 Use Case 执行
    ///
    /// 【为什么不直接传 PromptTool？】
    /// 因为快捷键回调只能传递简单的 ID
    /// 所以需要先查询，再执行
    ///
    /// 【错误处理】
    /// - 工具不存在：抛出 CoordinatorError.toolNotFound
    /// - 执行失败：抛出 Use Case 的错误
    func executeTool(id: ToolID) async throws {
        // 【步骤 1】查找工具
        // guard let 模式：早期返回，避免嵌套
        guard let tool = try await repository.find(by: id) else {
            // 抛出领域错误（Domain Error）
            throw CoordinatorError.toolNotFound
        }

        // 【步骤 2】委托给 Use Case 执行
        // 注意：Coordinator 不关心执行的细节
        // 所有业务逻辑都在 Use Case 中
        _ = try await executeToolUseCase.execute(tool: tool)
    }

    // MARK: - Initialization（初始化流程）
    //
    // 【首次启动逻辑】
    // 应用首次启动时需要创建默认工具
    // 这是一个常见的"数据迁移"场景

    /// 初始化默认工具（首次启动）
    ///
    /// 【幂等性（Idempotency）】
    /// 这个方法可以多次调用，但只会在首次启动时执行
    /// 这是一个重要的设计原则：操作应该是幂等的
    ///
    /// 【业务规则】
    /// - 如果已有工具：跳过初始化
    /// - 如果没有工具：创建默认工具
    ///
    /// 【为什么在 Coordinator 而不是 Repository？】
    /// 因为初始化涉及多个操作：
    /// 1. 检查现有工具
    /// 2. 创建默认工具
    /// 3. 确保 Smart AI 工具存在
    /// 这是业务逻辑，不是数据访问逻辑
    func initializeDefaultToolsIfNeeded() async throws {
        // 查询现有工具
        let existingTools = try await repository.findAll()
        try await applyBuiltinTemplateHotfixesIfNeeded(existingTools)

        // 【幂等性检查】
        // 如果已有工具，不再初始化
        guard existingTools.isEmpty else {
            print("📋 已存在 \(existingTools.count) 个 Prompt Tools，跳过初始化")
            return
        }

        print("🆕 首次启动，初始化默认 Prompt Tools")

        // 【批量插入】
        // 插入所有默认工具
        for tool in PromptTool.defaultTools {
            try await repository.save(tool)
        }

        // 【特殊处理】
        // 确保 Smart AI 工具存在（可能需要迁移旧配置）
        try await ensureSmartAIToolExists()
    }

    /// 修正历史内置模板中的已知语义重叠问题（仅对旧默认文案生效）
    private func applyBuiltinTemplateHotfixesIfNeeded(_ existingTools: [PromptTool]) async throws {
        guard
            let defaultXiaohongshu = PromptTool.defaultTools.first(where: { $0.name == "小红书成稿" }),
            var existingXiaohongshu = existingTools.first(where: { $0.name == "小红书成稿" && $0.isDefault })
        else {
            return
        }

        // 仅命中旧默认模板时替换，避免覆盖用户手工自定义 prompt。
        guard existingXiaohongshu.prompt.contains("开头使用吸引眼球的标题") else {
            return
        }

        existingXiaohongshu.prompt = defaultXiaohongshu.prompt
        existingXiaohongshu.capabilities = defaultXiaohongshu.capabilities
        try await repository.save(existingXiaohongshu)
        print("🔧 已修正内置工具模板：小红书成稿（去除标题生成职责）")
    }

    /// 确保 Smart AI 工具存在
    ///
    /// 【数据迁移（Data Migration）】
    /// 这个方法处理从旧版本到新版本的数据迁移
    ///
    /// 旧版本：Smart AI 配置存储在 UserDefaults
    /// 新版本：Smart AI 作为 PromptTool 存储在数据库
    ///
    /// 【向后兼容（Backward Compatibility）】
    /// 如果用户从旧版本升级，需要迁移旧配置
    private func ensureSmartAIToolExists() async throws {
        let tools = try await repository.findAll()

        // 检查是否已存在 Smart AI 工具
        let existingSmartTool = tools.first { $0.isSmart }

        if existingSmartTool == nil {
            // 【迁移旧配置】
            // 尝试从 UserDefaults 读取旧的快捷键配置
            let legacyKeyCode = UserDefaults.standard.integer(forKey: "smartAIShortcutKeyCode")
            let legacyModifiers = UserDefaults.standard.integer(forKey: "smartAIShortcutModifiers")

            let smartTool: PromptTool
            if legacyKeyCode > 0 {
                // 使用旧配置
                smartTool = PromptTool.createSmartAITool(
                    shortcutKeyCode: UInt16(legacyKeyCode),
                    shortcutModifiers: UInt32(legacyModifiers)
                )
                print("📱 迁移旧的 Smart AI 快捷键配置")
            } else {
                // 使用默认配置（⌘⌃V）
                smartTool = PromptTool.createSmartAITool()
            }

            // 插入到数据库
            try await repository.save(smartTool)
            print("✅ 创建 Smart AI 工具")
        }
    }

    // MARK: - Hot Key Management（快捷键管理）
    //
    // 【批量操作】
    // 这些方法处理批量注册/注销快捷键

    /// 注册所有工具的快捷键
    ///
    /// 【使用场景】
    /// 1. 应用启动时：注册所有工具的快捷键
    /// 2. 恢复默认工具后：重新注册所有快捷键
    ///
    /// 【错误处理】
    /// 如果某个工具的快捷键注册失败，会抛出错误
    /// 但已注册的快捷键不会回滚（部分成功）
    func registerAllHotKeys() async throws {
        let tools = try await repository.findAll()
        for tool in tools where !tool.isSmart {
            do {
                try hotKeyCoordinator.registerToolHotKey(for: tool) { [weak self] in
                    Task { @MainActor in
                        try? await self?.executeTool(id: tool.toolID)
                    }
                }
            } catch {
                print("⚠️ 跳过 Tool 快捷键注册失败：\\(tool.name) (\\(error.localizedDescription))")
            }
        }
    }

    /// 注销所有快捷键
    ///
    /// 【使用场景】
    /// 1. 应用退出时：释放系统资源
    /// 2. 重新加载配置前：清空旧配置
    ///
    /// 【幂等性】
    /// 多次调用是安全的，不会出错
    func unregisterAllHotKeys() {
        hotKeyCoordinator.unregisterAllToolHotKeys()
    }
}

// MARK: - Errors（错误定义）
//
// 【领域错误（Domain Error）】
// 这些是 Coordinator 层特有的错误
// 不同于 Use Case 的错误（ExecuteToolError）
//
// 【错误分层】
// - Domain Error：业务规则违反（工具未找到）
// - Infrastructure Error：技术问题（数据库连接失败）
// - Application Error：应用逻辑问题（参数无效）

enum CoordinatorError: LocalizedError {
    case toolNotFound

    var errorDescription: String? {
        switch self {
        case .toolNotFound:
            return "工具未找到"
        }
    }
}
