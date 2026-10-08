import Foundation

/// Generates text and recommends tools without exposing provider implementation details.
protocol AIServiceProtocol: Sendable {
    /// Executes a tool prompt; returns generated text or throws the provider error.
    func generate(systemPrompt: String, userInput: String) async throws -> String
    /// Recommends a tool for the supplied context and available tool list.
    func recommendTool(context: SmartContext, availableTools: [PromptTool]) async throws -> SmartRecommendation
}

/// Recommendation generation with explicit screenshot semantics.
protocol SmartRecommendationAIClient: Sendable {
    func generate(systemPrompt: String, userInput: String) async throws -> String
    func generateSmartRecommendationWithScreenshots(
        systemPrompt: String,
        userPrompt: String,
        screenshots: SmartContextScreenshots
    ) async throws -> String
}

/// User-facing provider configuration, independent from request execution.
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

    /// 当前 Codex 浏览器登录状态（不包含 token）
    var codexAuthStatus: CodexAuthStatus { get }

    /// 启动 Codex 浏览器登录流程，并将凭证保存到 SenseFlow Keychain
    func startCodexBrowserLogin() async throws

    /// 删除 SenseFlow 保存的 Codex 登录凭证
    func signOutCodex() throws

    /// 测试当前 AI 服务连接
    func testConnection() async throws -> Bool
}
