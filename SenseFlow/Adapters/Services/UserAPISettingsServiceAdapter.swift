import Foundation

/// Settings access to provider configuration, credentials and connection checks.
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
    }

    func unlockSavedCredentials(for serviceType: AIServiceType) async -> Bool {
        await Task.detached {
            if serviceType == .codex { return CodexAuthManager.shared.unlockSavedCredentials() }
            return KeychainManager.shared.unlockSavedCredentials()
        }.value
    }

    func loadAllAPIKeys() -> [AIServiceType: String] {
        Dictionary(uniqueKeysWithValues: AIServiceType.allCases.map { ($0, apiKey(for: $0)) })
    }

    func apiKey(for serviceType: AIServiceType) -> String {
        let account: String
        switch serviceType {
        case .openai: account = KeychainManager.Keys.openaiAPIKey
        case .claude: account = KeychainManager.Keys.claudeAPIKey
        case .gemini: account = KeychainManager.Keys.geminiAPIKey
        case .deepseek: account = KeychainManager.Keys.deepseekAPIKey
        case .openrouter: account = KeychainManager.Keys.openrouterAPIKey
        case .codex, .ollama: return ""
        }
        return keychainManager.cachedValue(account: account) ?? ""
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

    var codexAuthStatus: CodexAuthStatus {
        CodexAuthManager.shared.currentStatus
    }

    func startCodexBrowserLogin() async throws {
        _ = try await CodexAuthManager.shared.startBrowserLogin()
    }

    func signOutCodex() throws {
        try CodexAuthManager.shared.signOut()
    }

    func testConnection() async throws -> Bool {
        try await aiService.testConnection()
    }
}
