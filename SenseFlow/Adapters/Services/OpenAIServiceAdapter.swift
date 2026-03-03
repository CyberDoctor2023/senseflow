//
//  OpenAIServiceAdapter.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - 适配遗留代码】
//  这个 Adapter 展示了如何将现有的遗留代码集成到 Clean Architecture 中
//
//  什么是遗留代码（Legacy Code）？
//  - 已经存在的、正在运行的代码
//  - 可能没有遵循 Clean Architecture
//  - 可能使用单例模式（Singleton）
//  - 可能紧耦合
//
//  为什么需要适配遗留代码？
//  1. 渐进式重构：不需要一次性重写所有代码
//  2. 降低风险：保持现有功能正常运行
//  3. 平滑过渡：新代码使用新架构，旧代码逐步迁移
//
//  【重构策略：Strangler Fig Pattern（绞杀者模式）】
//  这是 Martin Fowler 提出的重构模式：
//  ```
//  1. 创建新架构（Clean Architecture）
//  2. 用 Adapter 包装旧代码
//  3. 新功能使用新架构
//  4. 逐步迁移旧功能
//  5. 最终移除旧代码
//  ```
//
//  就像绞杀榕（Strangler Fig）：
//  - 新树（新架构）围绕旧树（旧代码）生长
//  - 逐渐取代旧树
//  - 最终旧树消失，新树独立存在
//
//  【本项目的迁移路径】
//  ```
//  阶段 1：创建接口和 Adapter（当前阶段）
//  ┌─────────────────────────────────┐
//  │  New Architecture               │
//  │  ┌─────────────────────────┐    │
//  │  │ AIServiceProtocol       │    │
//  │  └─────────────────────────┘    │
//  │            ↑                    │
//  │  ┌─────────┴─────────────┐      │
//  │  │ OpenAIServiceAdapter  │      │  ← 这个文件
//  │  └───────────────────────┘      │
//  │            ↓                    │
//  └────────────┼────────────────────┘
//               ↓
//  ┌────────────┴────────────────────┐
//  │  Legacy Code                    │
//  │  AIService.shared (单例)        │
//  └─────────────────────────────────┘
//
//  阶段 2：新功能使用新架构
//  - Use Cases 依赖 AIServiceProtocol
//  - 通过 Adapter 调用旧代码
//
//  阶段 3：逐步迁移旧代码（未来）
//  - 将 AIService 的逻辑移到 Adapter 中
//  - 移除 AIService.shared 单例
//  - Adapter 直接调用 OpenAI SDK
//  ```
//
//  【对比两种 Adapter】
//  1. 适配外部框架（NSPasteboardAdapter）
//     - 适配 macOS 系统 API
//     - 我们无法修改 NSPasteboard
//     - Adapter 永久存在
//
//  2. 适配遗留代码（OpenAIServiceAdapter）
//     - 适配我们自己的旧代码
//     - 我们可以逐步重构
//     - Adapter 是临时的，最终会消失
//

import Foundation

/// OpenAI Service 适配器
///
/// 【职责】
/// 将现有的 AIService.shared（遗留代码）适配到 AIServiceProtocol 接口
///
/// 【为什么这么简单？】
/// 因为现有的 AIService 已经有类似的方法
/// Adapter 只需要"转发"调用，不需要复杂的转换
///
/// 【这是临时方案】
/// 这个 Adapter 是过渡性的：
/// - 短期：让新架构可以使用旧代码
/// - 长期：将 AIService 的逻辑移到这里，移除单例
///
/// 【设计模式】
/// 1. Adapter Pattern（适配器模式）：适配遗留代码
/// 2. Proxy Pattern（代理模式）：转发调用到真实对象
/// 3. Facade Pattern（外观模式）：简化复杂接口
///
/// 【依赖】
/// - SenseFlow.AIService：现有的 AI 服务实现（遗留代码）
/// - AIServiceProtocol：新架构的接口定义
final class OpenAIServiceAdapter: AIServiceProtocol {
    /// 遗留的 AI 服务实例
    ///
    /// 【为什么不直接用 AIService.shared？】
    /// 因为我们使用依赖注入（Dependency Injection）
    /// 即使是适配遗留代码，也要遵循 DI 原则
    ///
    /// 【好处】
    /// 1. 可测试：可以注入 Mock AIService
    /// 2. 灵活性：可以注入不同的 AIService 实例
    /// 3. 解耦：不直接依赖全局单例
    ///
    /// 【对比】
    /// ❌ 直接使用单例：
    /// ```swift
    /// func generate(...) async throws -> String {
    ///     return try await AIService.shared.generate(...)  // 紧耦合
    /// }
    /// ```
    ///
    /// ✅ 依赖注入：
    /// ```swift
    /// private let aiService: AIService  // 注入依赖
    /// func generate(...) async throws -> String {
    ///     return try await aiService.generate(...)  // 松耦合
    /// }
    /// ```
    private let aiService: SenseFlow.AIService

    /// 构造器注入
    ///
    /// 【依赖注入】
    /// 通过构造器注入 AIService 实例
    /// 在 DependencyContainer 中创建：
    /// ```swift
    /// OpenAIServiceAdapter(aiService: AIService.shared)
    /// ```
    ///
    /// 【未来重构】
    /// 当我们移除 AIService.shared 单例后：
    /// ```swift
    /// OpenAIServiceAdapter(apiKey: "...", model: "gpt-4")
    /// ```
    /// Adapter 内部直接调用 OpenAI SDK
    init(aiService: SenseFlow.AIService) {
        self.aiService = aiService
    }

    /// 生成文本
    ///
    /// 【实现方式：简单转发】
    /// 这个方法只是简单地转发调用到遗留代码
    /// 不做任何转换或处理
    ///
    /// 【为什么这么简单？】
    /// 因为遗留代码的接口和新接口几乎一样
    /// 这是幸运的情况，不是所有 Adapter 都这么简单
    ///
    /// 【如果接口不匹配怎么办？】
    /// 例如，遗留代码的方法签名是：
    /// ```swift
    /// func chat(messages: [Message]) async throws -> String
    /// ```
    /// 那么 Adapter 需要转换：
    /// ```swift
    /// func generate(systemPrompt: String, userInput: String) async throws -> String {
    ///     let messages = [
    ///         Message(role: "system", content: systemPrompt),
    ///         Message(role: "user", content: userInput)
    ///     ]
    ///     return try await aiService.chat(messages: messages)
    /// }
    /// ```
    ///
    /// 【错误处理】
    /// 直接传播错误（throws）
    /// 不捕获、不转换、不处理
    /// 让调用者决定如何处理错误
    func generate(systemPrompt: String, userInput: String) async throws -> String {
        // 简单转发调用
        return try await aiService.generate(
            systemPrompt: systemPrompt,
            userInput: userInput
        )
    }

    /// 推荐工具
    ///
    /// 【实现方式：简单转发】
    /// 同样是简单转发，不做任何处理
    ///
    /// 【Smart AI 功能】
    /// 这是 Smart AI 的核心方法
    /// 根据上下文推荐最合适的工具
    ///
    /// 【未来优化】
    /// 可以在 Adapter 中添加：
    /// 1. 缓存：相同上下文返回缓存结果
    /// 2. 重试：失败时自动重试
    /// 3. 降级：AI 失败时使用规则引擎
    /// 4. 监控：记录推荐准确率
    ///
    /// 但目前保持简单，只做转发
    func recommendTool(context: SmartContext, availableTools: [PromptTool]) async throws -> SmartRecommendation {
        // 简单转发调用
        return try await aiService.recommendTool(
            context: context,
            availableTools: availableTools
        )
    }
}

/// 用户可见 AI API 配置适配器（不包含 Langfuse）
///
/// 该适配器把遗留单例（AIService/KeychainManager）统一封装成
/// 一个面向 UI 的配置端口，避免视图层直接依赖单例。
final class UserAPISettingsServiceAdapter: UserAPISettingsServiceProtocol {
    private let aiService: SenseFlow.AIService
    private let keychainManager: KeychainManager

    init(
        aiService: SenseFlow.AIService,
        keychainManager: KeychainManager
    ) {
        self.aiService = aiService
        self.keychainManager = keychainManager
    }

    var currentServiceType: AIServiceType {
        aiService.currentServiceType
    }

    func updateCurrentServiceType(_ serviceType: AIServiceType) {
        aiService.currentServiceType = serviceType
        aiService.resetClient()
    }

    func loadAllAPIKeys() -> [AIServiceType: String] {
        let keys = keychainManager.getAllSettingsKeys()
        return [
            .openai: keys.openaiKey ?? "",
            .claude: keys.claudeKey ?? "",
            .gemini: keys.geminiKey ?? "",
            .deepseek: keys.deepseekKey ?? "",
            .openrouter: keys.openrouterKey ?? "",
            .ollama: ""
        ]
    }

    func apiKey(for serviceType: AIServiceType) -> String {
        keychainManager.getAPIKey(for: serviceType) ?? ""
    }

    @discardableResult
    func saveAPIKey(_ key: String, for serviceType: AIServiceType) -> Bool {
        keychainManager.saveAPIKey(key, for: serviceType)
    }

    func loadAllModelNames() -> [AIServiceType: String] {
        var result: [AIServiceType: String] = [:]
        for service in AIServiceType.allCases {
            result[service] = service.selectedModel
        }
        return result
    }

    func modelName(for serviceType: AIServiceType) -> String {
        serviceType.selectedModel
    }

    func saveModelName(_ model: String, for serviceType: AIServiceType) {
        serviceType.saveSelectedModel(model)
    }

    func testConnection() async throws -> Bool {
        try await aiService.testConnection()
    }
}

//
// 【扩展阅读】
//
// 渐进式重构的最佳实践：
// 1. 先创建接口（Port）
// 2. 用 Adapter 包装旧代码
// 3. 新代码使用新接口
// 4. 逐步迁移旧代码
// 5. 最终移除 Adapter
//
// 重构的时机：
// - ✅ 添加新功能时：使用新架构
// - ✅ 修复 Bug 时：顺便重构相关代码
// - ✅ 性能优化时：重构瓶颈代码
// - ❌ 为了重构而重构：风险高，收益低
//
// 如何判断重构是否成功？
// 1. 测试全部通过
// 2. 功能没有退化
// 3. 代码更易理解
// 4. 依赖更清晰
// 5. 易于测试
//
// 重构的风险控制：
// 1. 小步前进：每次只重构一小部分
// 2. 频繁测试：每次修改后立即测试
// 3. 版本控制：随时可以回滚
// 4. 代码审查：让团队成员审查
// 5. 监控指标：确保性能没有下降
//
// 本项目的重构进度：
// - ✅ 阶段 1：创建 Clean Architecture 框架
// - ✅ 阶段 2：用 Adapter 包装遗留代码
// - ✅ 阶段 3：新功能使用新架构
// - ⏳ 阶段 4：逐步迁移旧功能（进行中）
// - ⏳ 阶段 5：移除遗留代码（未来）
//
