//
//  AIService.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - AI 服务接口】
//  这是一个典型的"策略模式（Strategy Pattern）"应用
//
//  什么是策略模式？
//  - 定义一系列算法（OpenAI、Gemini、Claude）
//  - 将每个算法封装起来
//  - 让它们可以互相替换
//
//  为什么需要 AI 服务接口？
//  1. 多提供商支持：OpenAI、Google Gemini、Anthropic Claude
//  2. 易于切换：用户可以选择不同的 AI 服务
//  3. 易于测试：可以用 Mock AI 服务测试业务逻辑
//  4. 降低风险：不被单一供应商锁定（Vendor Lock-in）
//
//  【策略模式示例】
//  ```
//  ┌─────────────────────────┐
//  │   AIServiceProtocol     │  ← 策略接口
//  │   (Port)                │
//  └─────────────────────────┘
//              ↑
//              │ 实现
//    ┌─────────┼─────────┐
//    │         │         │
//  ┌─┴──┐   ┌─┴──┐   ┌─┴──┐
//  │OpenAI│  │Gemini│ │Claude│  ← 具体策略
//  └────┘   └────┘   └────┘
//  ```
//
//  使用方式：
//  ```swift
//  // 运行时切换策略
//  let aiService: AIServiceProtocol = OpenAIServiceAdapter()  // 或 GeminiAdapter
//  let result = try await aiService.generate(...)
//  ```
//
//  【对比紧耦合方式】
//  ❌ 紧耦合（直接依赖具体实现）：
//  ```swift
//  class ExecutePromptTool {
//      func execute() {
//          let openai = OpenAI(apiKey: "...")
//          let result = try await openai.chat(...)  // 直接依赖 OpenAI SDK
//      }
//  }
//  ```
//  问题：
//  - 无法切换到 Gemini 或 Claude
//  - 无法测试（依赖真实 API）
//  - 代码散落在各处（重复的 API 调用）
//
//  ✅ 松耦合（依赖接口）：
//  ```swift
//  class ExecutePromptTool {
//      private let aiService: AIServiceProtocol  // 依赖接口
//
//      func execute() {
//          let result = try await aiService.generate(...)  // 不关心具体实现
//      }
//  }
//  ```
//  好处：
//  - 可以切换任何实现（OpenAI、Gemini、Claude）
//  - 可以测试（注入 MockAIService）
//  - 统一接口（所有 AI 服务都用相同方法）
//

import Foundation

/// AI 服务协议（Port）
///
/// 【职责】
/// 定义 AI 能力的抽象接口，不依赖具体提供商
///
/// 【设计原则】
/// 1. 依赖倒置原则（DIP）：业务逻辑依赖接口，不依赖实现
/// 2. 开闭原则（OCP）：对扩展开放（新增 AI 提供商），对修改关闭
/// 3. 里氏替换原则（LSP）：任何实现都可以替换接口
///
/// 【实现者】
/// - OpenAIServiceAdapter：使用 OpenAI API
/// - GeminiServiceAdapter：使用 Google Gemini API
/// - ClaudeServiceAdapter：使用 Anthropic Claude API（未来）
/// - MockAIService：测试用实现
///
/// 【为什么叫 Adapter？】
/// 因为这些实现是"适配器"，将外部 SDK 适配到我们的接口
/// - OpenAI SDK → OpenAIServiceAdapter → AIServiceProtocol
/// - Gemini SDK → GeminiServiceAdapter → AIServiceProtocol
///
/// 【Sendable 协议】
/// 确保可以在并发环境中安全使用
protocol AIServiceProtocol: Sendable {
    /// 生成文本
    ///
    /// 【核心方法】
    /// 这是最基础的 AI 能力：根据提示词生成文本
    ///
    /// 【参数说明】
    /// - systemPrompt: 系统提示词（定义 AI 的角色和行为）
    ///   例如："你是一个翻译助手，将用户输入翻译成英文"
    /// - userInput: 用户输入（需要处理的内容）
    ///   例如："你好世界"
    ///
    /// 【返回值】
    /// AI 生成的结果文本
    /// 例如："Hello World"
    ///
    /// 【错误处理】
    /// - API 调用失败：抛出网络错误
    /// - API Key 无效：抛出认证错误
    /// - 内容被过滤：抛出内容安全错误
    ///
    /// 【实现要求】
    /// 所有实现必须：
    /// 1. 处理网络错误并重试
    /// 2. 处理 API 限流（Rate Limiting）
    /// 3. 记录日志（用于调试）
    /// 4. 超时控制（避免无限等待）
    ///
    /// - Parameters:
    ///   - systemPrompt: 系统提示词
    ///   - userInput: 用户输入
    /// - Returns: AI 生成的结果
    /// - Throws: 网络错误、API 错误、内容安全错误
    func generate(systemPrompt: String, userInput: String) async throws -> String

    /// 推荐工具
    ///
    /// 【高级方法】
    /// 这是 Smart AI 功能的核心：根据上下文推荐最合适的工具
    ///
    /// 【工作原理】
    /// 1. 收集上下文（剪贴板内容、当前应用、屏幕截图等）
    /// 2. 分析可用工具列表
    /// 3. 使用 AI 推理最合适的工具
    /// 4. 返回推荐结果（包含置信度和理由）
    ///
    /// 【参数说明】
    /// - context: 当前上下文信息
    ///   - 剪贴板内容
    ///   - 当前应用名称
    ///   - 屏幕截图（可选）
    /// - availableTools: 可用工具列表
    ///   - 工具名称
    ///   - 工具描述（Prompt）
    ///
    /// 【返回值】
    /// SmartRecommendation 对象：
    /// - toolID: 推荐的工具 ID
    /// - confidence: 置信度（0.0 - 1.0）
    /// - reasoning: 推荐理由（用于调试和用户理解）
    ///
    /// 【实现要求】
    /// 1. 置信度必须在 0.0 - 1.0 之间
    /// 2. 如果没有合适的工具，返回低置信度
    /// 3. 必须提供推荐理由（可解释性）
    ///
    /// 【使用场景】
    /// 用户按下 Smart AI 快捷键 → 收集上下文 → AI 推荐工具 → 自动执行
    ///
    /// - Parameters:
    ///   - context: 当前上下文
    ///   - availableTools: 可用工具列表
    /// - Returns: 推荐结果
    /// - Throws: AI 推理失败、网络错误
    func recommendTool(context: SmartContext, availableTools: [PromptTool]) async throws -> SmartRecommendation
}

/// Smart 推荐生成端口（业务层专用）
///
/// 职责：
/// - 提供文本生成能力
/// - 提供带截图语义的 Smart 推荐生成能力
///
/// 说明：
/// 业务层只依赖此端口，不关心底层使用哪个供应商。
protocol SmartRecommendationAIClient: Sendable {
    func generate(systemPrompt: String, userInput: String) async throws -> String
    func generateSmartRecommendationWithScreenshots(
        systemPrompt: String,
        userPrompt: String,
        screenshots: SmartContextScreenshots
    ) async throws -> String
}

/// 用户侧 AI API 配置入口（Port）
///
/// 职责：
/// - 管理当前选择的 AI 服务
/// - 管理各服务 API Key（不包含 Langfuse）
/// - 提供连接测试能力
protocol UserAPISettingsServiceProtocol {
    /// 当前用户选择的 AI 服务
    var currentServiceType: AIServiceType { get }

    /// 更新当前 AI 服务选择
    func updateCurrentServiceType(_ serviceType: AIServiceType)

    /// 批量读取所有 AI 服务 API Key（不包含 Langfuse）
    func loadAllAPIKeys() -> [AIServiceType: String]

    /// 读取单个服务 API Key
    func apiKey(for serviceType: AIServiceType) -> String

    /// 保存单个服务 API Key
    @discardableResult
    func saveAPIKey(_ key: String, for serviceType: AIServiceType) -> Bool

    /// 批量读取所有服务模型名（用户配置值，未配置则返回默认）
    func loadAllModelNames() -> [AIServiceType: String]

    /// 读取单个服务模型名（未配置则返回默认）
    func modelName(for serviceType: AIServiceType) -> String

    /// 保存单个服务模型名（空字符串表示回退默认）
    func saveModelName(_ model: String, for serviceType: AIServiceType)

    /// 测试当前 AI 服务连接
    func testConnection() async throws -> Bool
}

//
// 【扩展阅读】
//
// 为什么接口设计很重要？
// 1. 接口是契约（Contract）：定义了实现者必须遵守的规则
// 2. 接口是抽象（Abstraction）：隐藏实现细节，只暴露必要的能力
// 3. 接口是解耦（Decoupling）：让高层模块不依赖低层模块
//
// 好的接口设计原则：
// 1. 最小化：只包含必要的方法
// 2. 稳定性：接口应该很少改变
// 3. 可测试：易于创建 Mock 实现
// 4. 语义化：方法名清晰表达意图
// 5. 文档化：详细说明参数、返回值、错误
//
// 接口演化（Interface Evolution）：
// - 新增方法：可以，但要提供默认实现（Swift Extension）
// - 修改方法签名：不可以，会破坏现有实现
// - 删除方法：不可以，会破坏现有调用
//
// 版本控制：
// - V1: AIServiceProtocol（当前版本）
// - V2: AIServiceProtocolV2（新版本，保留旧版本兼容）
//
