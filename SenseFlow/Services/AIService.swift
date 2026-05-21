//
//  AIService.swift
//  SenseFlow
//
//  Created on 2026-01-19.
//  Updated on 2026-01-20: 迁移到 MacPaw OpenAI SDK
//

import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import Network
import OpenAI
import OpenTelemetryApi
import Security

/// Local Codex authentication status safe to show in Settings.
struct CodexAuthStatus: Equatable {
    /// Whether a usable Codex ChatGPT access token is available locally.
    let isAuthenticated: Bool

    /// Redacted account identifier metadata from Codex auth.
    let accountID: String?

    /// ChatGPT plan type metadata, when present in the Codex token.
    let planType: String?

    /// Profile email metadata, when present in the Codex token.
    let email: String?

    /// Access token expiry decoded from the JWT payload, when available.
    let expiresAt: Date?

    /// Human-readable status message for Settings.
    let message: String

    static func loggedOut(_ message: String = "未登录 Codex") -> CodexAuthStatus {
        CodexAuthStatus(
            isAuthenticated: false,
            accountID: nil,
            planType: nil,
            email: nil,
            expiresAt: nil,
            message: message
        )
    }
}

/// Local Codex credentials used only for authenticated requests.
struct CodexAuthCredentials {
    /// Bearer token read from local Codex auth state.
    let accessToken: String

    /// ChatGPT account identifier required by Codex backend for workspace routing.
    let accountID: String?
}

/// Reads SenseFlow-owned Codex auth state and launches the Codex browser OAuth flow.
final class CodexAuthManager {
    static let shared = CodexAuthManager()

    private let keychainStore: CodexKeychainStore

    private init(keychainStore: CodexKeychainStore = CodexKeychainStore()) {
        self.keychainStore = keychainStore
    }

    /// Current Codex auth status with all tokens redacted.
    var currentStatus: CodexAuthStatus {
        do {
            guard let credentials = try keychainStore.load() else {
                return .loggedOut("Codex 未登录，请先登录")
            }
            return status(for: credentials)
        } catch {
            return .loggedOut(error.localizedDescription)
        }
    }

    /// Whether SenseFlow has any saved Codex OAuth credentials that generation may refresh.
    var hasCachedCredentials: Bool {
        (try? keychainStore.load()) != nil
    }

    /// Credentials for Codex-authenticated network requests.
    func credentials() async throws -> CodexAuthCredentials {
        guard let cached = try keychainStore.load() else {
            throw PromptToolError.aiServiceNotConfigured
        }

        let usable = cached.isUsableNow ? cached : try await refresh(cached)
        return CodexAuthCredentials(
            accessToken: usable.accessToken,
            accountID: usable.accountID
        )
    }

    /// Starts Codex OAuth in the user's browser and stores the resulting credentials in SenseFlow Keychain.
    func startBrowserLogin() async throws -> CodexAuthStatus {
        let credentials = try await login()
        try keychainStore.save(credentials)
        return status(for: credentials)
    }

    /// Removes SenseFlow's saved Codex OAuth credentials.
    func signOut() throws {
        try keychainStore.delete()
    }

    private func login() async throws -> CodexStoredCredentials {
        let pkce = try CodexPKCE.make()
        let state = CodexPKCE.randomURLSafeString(byteCount: 16)
        let callbackServer = try LocalCodexOAuthCallbackServer(expectedState: state)
        try await callbackServer.start()

        let url = authorizationURL(challenge: pkce.challenge, state: state)
        return try await withTaskCancellationHandler {
            defer {
                callbackServer.stop()
            }

            return try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await callbackServer.waitForCode()
                }
                group.addTask { @MainActor in
                    try await CodexBrowserAuthenticator.open(url: url, expectedState: state)
                }

                guard let code = try await group.next() else {
                    throw PromptToolError.apiError("没有拿到 Codex 授权码")
                }
                group.cancelAll()

                return try await exchangeAuthorizationCode(code, verifier: pkce.verifier)
            }
        } onCancel: {
            callbackServer.stop()
        }
    }

    private func refresh(_ credentials: CodexStoredCredentials) async throws -> CodexStoredCredentials {
        let body = URLQueryItem.formBody([
            "grant_type": "refresh_token",
            "refresh_token": credentials.refreshToken,
            "client_id": CodexOAuthConstants.clientID
        ])

        do {
            let refreshed = try await tokenRequest(body: body)
            try keychainStore.save(refreshed)
            return refreshed
        } catch {
            try? keychainStore.delete()
            throw error
        }
    }

    private func exchangeAuthorizationCode(_ code: String, verifier: String) async throws -> CodexStoredCredentials {
        let body = URLQueryItem.formBody([
            "grant_type": "authorization_code",
            "client_id": CodexOAuthConstants.clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": CodexOAuthConstants.redirectURI
        ])
        return try await tokenRequest(body: body)
    }

    private func tokenRequest(body: Data) async throws -> CodexStoredCredentials {
        var request = URLRequest(url: URL(string: "https://auth.openai.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw PromptToolError.apiError(String(data: data, encoding: .utf8) ?? "Codex token 换取失败")
        }

        let payload = try JSONDecoder().decode(CodexTokenResponse.self, from: data)
        let metadata = decodeTokenMetadata(payload.accessToken)
        guard let accountID = metadata.accountID, !accountID.isEmpty else {
            throw PromptToolError.apiError("Codex 登录成功，但 token 里没有 accountId")
        }

        return CodexStoredCredentials(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn)),
            accountID: accountID
        )
    }

    private func authorizationURL(challenge: String, state: String) -> URL {
        var components = URLComponents(string: "https://auth.openai.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: CodexOAuthConstants.clientID),
            URLQueryItem(name: "redirect_uri", value: CodexOAuthConstants.redirectURI),
            URLQueryItem(name: "scope", value: "openid profile email offline_access"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "originator", value: "pi")
        ]
        return components.url!
    }

    private func status(for credentials: CodexStoredCredentials) -> CodexAuthStatus {
        let metadata = decodeTokenMetadata(credentials.accessToken)
        guard credentials.isUsableNow else {
            return CodexAuthStatus(
                isAuthenticated: false,
                accountID: credentials.accountID,
                planType: metadata.planType,
                email: metadata.email,
                expiresAt: credentials.expiresAt,
                message: "Codex 登录已过期，请重新登录"
            )
        }

        return CodexAuthStatus(
            isAuthenticated: true,
            accountID: credentials.accountID,
            planType: metadata.planType,
            email: metadata.email,
            expiresAt: credentials.expiresAt,
            message: "已登录 Codex"
        )
    }

    private func decodeTokenMetadata(_ accessToken: String) -> (accountID: String?, planType: String?, email: String?, expiresAt: Date?) {
        let parts = accessToken.split(separator: ".")
        guard parts.count == 3,
              let payloadData = decodeBase64URL(String(parts[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return (nil, nil, nil, nil)
        }

        let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        let profile = payload["https://api.openai.com/profile"] as? [String: Any]
        let expiresAt: Date?
        if let exp = payload["exp"] as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: exp)
        } else if let exp = payload["exp"] as? Int {
            expiresAt = Date(timeIntervalSince1970: TimeInterval(exp))
        } else {
            expiresAt = nil
        }

        return (
            auth?["chatgpt_account_id"] as? String,
            auth?["chatgpt_plan_type"] as? String,
            profile?["email"] as? String,
            expiresAt
        )
    }

    private func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: paddingLength))
        return Data(base64Encoded: base64)
    }
}

private enum CodexOAuthConstants {
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let redirectURI = "http://localhost:1455/auth/callback"
}

private struct CodexStoredCredentials: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let accountID: String

    var isUsableNow: Bool {
        expiresAt.timeIntervalSinceNow > 60
    }
}

private struct CodexTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct CodexPKCE {
    let verifier: String
    let challenge: String

    static func make() throws -> CodexPKCE {
        let verifier = randomURLSafeString(byteCount: 32)
        guard let data = verifier.data(using: .utf8) else {
            throw PromptToolError.apiError("生成 Codex 登录校验失败")
        }
        let digest = SHA256.hash(data: data)
        return CodexPKCE(verifier: verifier, challenge: base64URL(Data(digest)))
    }

    static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

@MainActor
private final class CodexBrowserAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var authSession: ASWebAuthenticationSession?

    static func open(url: URL, expectedState: String) async throws -> String {
        let authenticator = CodexBrowserAuthenticator()
        return try await authenticator.openBrowserAuth(url: url, expectedState: expectedState)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }

    private func openBrowserAuth(url: URL, expectedState: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "http") { callbackURL, error in
                if let callbackURL {
                    do {
                        continuation.resume(returning: try Self.parseCode(from: callbackURL, expectedState: expectedState))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                continuation.resume(throwing: error ?? PromptToolError.apiError("没有拿到 Codex 授权码"))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authSession = session

            if !session.start() {
                continuation.resume(throwing: PromptToolError.apiError("无法打开 Codex 登录浏览器"))
            }
        }
    }

    private static func parseCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw PromptToolError.apiError("没有拿到 Codex 授权码")
        }
        let query = components.queryItems ?? []
        guard query.first(where: { $0.name == "state" })?.value == expectedState else {
            throw PromptToolError.apiError("Codex 登录校验不一致，请重试")
        }
        guard let code = query.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw PromptToolError.apiError("没有拿到 Codex 授权码")
        }
        return code
    }
}

private final class LocalCodexOAuthCallbackServer {
    private let expectedState: String
    private var listener: NWListener?
    private var continuation: CheckedContinuation<String, Error>?

    init(expectedState: String) throws {
        self.expectedState = expectedState
        listener = try NWListener(using: .tcp, on: 1455)
    }

    func start() async throws {
        guard let listener else {
            throw PromptToolError.apiError("无法启动本机 OAuth 回调服务")
        }

        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: .main)
        }
    }

    func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            do {
                let code = try self.parseCode(from: request)
                self.respond(connection, status: "200 OK", body: "Authentication successful. Return to SenseFlow.")
                self.continuation?.resume(returning: code)
                self.continuation = nil
            } catch {
                self.respond(connection, status: "400 Bad Request", body: error.localizedDescription)
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    private func parseCode(from request: String) throws -> String {
        guard let firstLine = request.split(separator: "\r\n").first,
              let path = firstLine.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: "http://localhost\(path)") else {
            throw PromptToolError.apiError("没有拿到 Codex 授权码")
        }
        guard components.path == "/auth/callback" else {
            throw PromptToolError.apiError("没有拿到 Codex 授权码")
        }
        let query = components.queryItems ?? []
        guard query.first(where: { $0.name == "state" })?.value == expectedState else {
            throw PromptToolError.apiError("Codex 登录校验不一致，请重试")
        }
        guard let code = query.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw PromptToolError.apiError("没有拿到 Codex 授权码")
        }
        return code
    }

    private func respond(_ connection: NWConnection, status: String, body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private struct CodexKeychainStore {
    private let service = "SenseFlow.CodexOAuth"
    private let account = "default"

    func load() throws -> CodexStoredCredentials? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw PromptToolError.apiError("Codex 登录凭证读取失败")
        }
        return try JSONDecoder().decode(CodexStoredCredentials.self, from: data)
    }

    func save(_ credentials: CodexStoredCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        try delete()

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PromptToolError.apiError("Codex 登录凭证保存失败")
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PromptToolError.apiError("Codex 登录凭证删除失败")
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private extension URLQueryItem {
    static func formBody(_ values: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
        return Data((components.percentEncodedQuery ?? "").utf8)
    }
}

/// AI 服务管理器（单例）
/// 使用 MacPaw OpenAI SDK，支持 OpenAI 兼容 API（Claude/DeepSeek/Gemini 等）
class AIService {
    private let deterministicTemperature: Double = 0

    // MARK: - Singleton

    static let shared = AIService()

    // MARK: - Properties

    /// 当前选择的服务类型
    var currentServiceType: AIServiceType {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "selectedAIService") ?? "openai"
            // Migrate from legacy "custom" service to OpenAI
            if rawValue == "custom" {
                return .openai
            }
            return AIServiceType(rawValue: rawValue) ?? .openai
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedAIService")
        }
    }

    /// OpenAI 客户端实例（懒加载）
    private var openAIClient: OpenAI?

    /// API 请求记录器（记录真实 HTTP 请求负载）
    private let apiRequestRecorder: APIRequestRecorder

    // MARK: - Initialization

    private init(apiRequestRecorder: APIRequestRecorder = InMemoryAPIRequestRecorder.shared) {
        self.apiRequestRecorder = apiRequestRecorder
    }

    // MARK: - Public Methods

    /// 生成文本
    /// - Parameters:
    ///   - systemPrompt: 系统 Prompt（Tool 的 prompt）
    ///   - userInput: 用户输入（剪贴板内容）
    /// - Returns: AI 生成的结果
    func generate(systemPrompt: String, userInput: String) async throws -> String {
        let modelName = getModel()
        return try await TracingService.shared.withSpan(
            name: "ai.generate",
            kind: .client,
            attributes: [
                "gen_ai.system": .string(currentServiceType.rawValue),
                "gen_ai.request.model": .string(modelName)
            ]
        ) { span in
            try await validateAndGenerate(systemPrompt: systemPrompt, userInput: userInput, span: span)
        }
    }

    /// 验证配置并生成内容
    private func validateAndGenerate(systemPrompt: String, userInput: String, span: Span?) async throws -> String {
        // 检查 API Key
        guard KeychainManager.shared.hasAPIKey(for: currentServiceType) else {
            recordError(span: span, message: "AI service not configured")
            throw PromptToolError.aiServiceNotConfigured
        }

        // 记录输入
        span?.setAttribute(key: "gen_ai.prompt", value: .string(userInput))

        // 根据服务类型选择生成策略
        let result = try await generateWithCurrentService(
            systemPrompt: systemPrompt,
            userInput: userInput
        )

        // 记录输出
        span?.setAttribute(key: "gen_ai.completion", value: .string(result))

        return result
    }

    /// 根据当前服务类型生成内容
    private func generateWithCurrentService(systemPrompt: String, userInput: String) async throws -> String {
        if currentServiceType == .gemini {
            return try await generateWithGemini(systemPrompt: systemPrompt, userInput: userInput)
        } else if currentServiceType == .codex {
            return try await generateWithCodex(systemPrompt: systemPrompt, userInput: userInput)
        } else {
            return try await generateWithOpenAI(systemPrompt: systemPrompt, userInput: userInput)
        }
    }

    /// 使用 Gemini 服务生成
    private func generateWithGemini(systemPrompt: String, userInput: String) async throws -> String {
        let apiKey = KeychainManager.shared.getAPIKey(for: .gemini) ?? ""
        return try await GeminiService.shared.generate(
            systemPrompt: systemPrompt,
            userInput: userInput,
            apiKey: apiKey,
            modelName: getModel()
        )
    }

    /// 使用本机 Codex ChatGPT 登录态生成
    private func generateWithCodex(systemPrompt: String, userInput: String) async throws -> String {
        let serviceType = currentServiceType
        let modelName = getModel()
        let endpoint = buildEndpointURL(for: serviceType)
        let credentials = try await CodexAuthManager.shared.credentials()
        let messagesPayload = buildTextMessagesPayload(systemPrompt: systemPrompt, userInput: userInput)
        let requestBodyPayload = buildCodexResponsesRequestBodyPayload(
            modelName: modelName,
            systemPrompt: systemPrompt,
            userInput: userInput
        )
        let headersPayload = buildRequestHeadersPayload(for: serviceType)
        let parametersPayload: [String: Any] = [
            "model": modelName,
            "stream": false
        ]

        guard let url = URL(string: endpoint) else {
            throw PromptToolError.apiError("Invalid Codex endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "chatgpt-account-id")
        }
        request.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("pi", forHTTPHeaderField: "originator")
        request.setValue("SenseFlow", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBodyPayload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PromptToolError.apiError("Invalid Codex response")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let responseText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw PromptToolError.apiError("Codex request failed: \(responseText)")
            }

            let content = try extractCodexResponseText(from: data)
            await recordRequestPayload(
                toolName: APIRequestExecutionContext.toolName,
                serviceType: serviceType,
                modelName: modelName,
                httpMethod: "POST",
                endpoint: endpoint,
                headersPayload: headersPayload,
                requestBodyPayload: requestBodyPayload,
                messagesPayload: messagesPayload,
                parametersPayload: parametersPayload,
                hasImage: false,
                imageCount: 0,
                responseText: content,
                error: nil
            )
            return content
        } catch {
            let handledError = handleGenerationError(error)
            await recordRequestPayload(
                toolName: APIRequestExecutionContext.toolName,
                serviceType: serviceType,
                modelName: modelName,
                httpMethod: "POST",
                endpoint: endpoint,
                headersPayload: headersPayload,
                requestBodyPayload: requestBodyPayload,
                messagesPayload: messagesPayload,
                parametersPayload: parametersPayload,
                hasImage: false,
                imageCount: 0,
                responseText: nil,
                error: handledError
            )
            throw handledError
        }
    }

    /// 使用 OpenAI 兼容服务生成
    private func generateWithOpenAI(systemPrompt: String, userInput: String) async throws -> String {
        let client = try getOrCreateClient()
        let serviceType = currentServiceType
        let modelName = getModel()
        let endpoint = buildEndpointURL(for: serviceType)
        let headersPayload = buildRequestHeadersPayload(for: serviceType)
        let messagesPayload = buildTextMessagesPayload(systemPrompt: systemPrompt, userInput: userInput)
        let requestBodyPayload = buildOpenAIRequestBodyPayload(modelName: modelName, messagesPayload: messagesPayload)
        let parametersPayload = buildRequestParametersPayload(modelName: modelName)
        let query = buildChatQuery(systemPrompt: systemPrompt, userInput: userInput, modelName: modelName)

        do {
            let result = try await client.chats(query: query)
            let content = try extractAndRecordResponse(result)
            await recordRequestPayload(
                toolName: APIRequestExecutionContext.toolName,
                serviceType: serviceType,
                modelName: modelName,
                httpMethod: "POST",
                endpoint: endpoint,
                headersPayload: headersPayload,
                requestBodyPayload: requestBodyPayload,
                messagesPayload: messagesPayload,
                parametersPayload: parametersPayload,
                hasImage: false,
                imageCount: 0,
                responseText: content,
                error: nil
            )
            return content
        } catch {
            let handledError = handleGenerationError(error)
            await recordRequestPayload(
                toolName: APIRequestExecutionContext.toolName,
                serviceType: serviceType,
                modelName: modelName,
                httpMethod: "POST",
                endpoint: endpoint,
                headersPayload: headersPayload,
                requestBodyPayload: requestBodyPayload,
                messagesPayload: messagesPayload,
                parametersPayload: parametersPayload,
                hasImage: false,
                imageCount: 0,
                responseText: nil,
                error: handledError
            )
            throw handledError
        }
    }

    /// 构建聊天查询
    private func buildChatQuery(systemPrompt: String, userInput: String, modelName: String) -> ChatQuery {
        return ChatQuery(
            messages: [
                .system(.init(content: .textContent(systemPrompt))),
                .user(.init(content: .string(userInput)))
            ],
            model: modelName,
            temperature: deterministicTemperature
        )
    }

    /// 提取并记录响应
    private func extractAndRecordResponse(_ result: ChatResult) throws -> String {
        guard let firstChoice = result.choices.first else {
            throw PromptToolError.apiError("No response received")
        }

        let content = firstChoice.message.content ?? ""
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedContent
    }

    /// 处理生成错误
    private func handleGenerationError(_ error: Error) -> Error {
        if let urlError = error as? URLError {
            return PromptToolError.networkError(urlError)
        }
        return PromptToolError.apiError(error.localizedDescription)
    }

    /// 记录错误到 span
    private func recordError(span: Span?, message: String) {
        span?.setAttribute(key: "error", value: .bool(true))
        span?.setAttribute(key: "error.message", value: .string(message))
    }

    /// 测试 API 连接
    func testConnection() async throws -> Bool {
        _ = try await generate(systemPrompt: "Say 'OK'", userInput: "Test")
        return true
    }

    // MARK: - Private Methods

    /// 获取或创建 OpenAI 客户端
    private func getOrCreateClient() throws -> OpenAI {
        if let existingClient = openAIClient {
            return existingClient
        }

        let client = try createNewClient()
        openAIClient = client
        return client
    }

    /// 创建新的 OpenAI 客户端
    private func createNewClient() throws -> OpenAI {
        let configuration = buildClientConfiguration()
        return OpenAI(configuration: configuration)
    }

    /// 构建客户端配置
    private func buildClientConfiguration() -> OpenAI.Configuration {
        let serviceType = currentServiceType
        let apiKey = KeychainManager.shared.getAPIKey(for: serviceType) ?? ""
        let sdkConfig = serviceType.sdkConfiguration

        if serviceType.needsRelaxedParsing {
            return createRelaxedConfiguration(apiKey: apiKey, config: sdkConfig)
        } else {
            return createStandardConfiguration(apiKey: apiKey, config: sdkConfig)
        }
    }

    /// 创建 Relaxed Parsing 配置（非 OpenAI 服务）
    private func createRelaxedConfiguration(apiKey: String, config: (host: String, scheme: String, port: Int)) -> OpenAI.Configuration {
        return OpenAI.Configuration(
            token: apiKey,
            host: config.host,
            port: config.port,
            scheme: config.scheme,
            timeoutInterval: 30.0,
            parsingOptions: .relaxed
        )
    }

    /// 创建标准配置（OpenAI 和 Ollama）
    private func createStandardConfiguration(apiKey: String, config: (host: String, scheme: String, port: Int)) -> OpenAI.Configuration {
        return OpenAI.Configuration(
            token: apiKey,
            host: config.host,
            port: config.port,
            scheme: config.scheme,
            timeoutInterval: 30.0
        )
    }

    /// 获取当前服务的模型
    private func getModel() -> String {
        currentServiceType.selectedModel
    }

    /// 重置客户端（配置变更时调用）
    func resetClient() {
        openAIClient = nil
    }

    // MARK: - Smart Tool Recommendation

    /// Recommend most suitable Prompt Tool based on context
    /// - Parameters:
    ///   - context: Current user context (app, clipboard, screenshot)
    ///   - availableTools: List of available prompt tools
    /// - Returns: SmartRecommendation with suggested tool
    /// - Throws: PromptToolError if recommendation fails
    func recommendTool(context: SmartContext, availableTools: [PromptTool]) async throws -> SmartRecommendation {
        let modelName = getModel()
        return try await TracingService.shared.withSpan(
            name: "ai.recommend_tool",
            kind: .client,
            attributes: [
                "gen_ai.system": .string(currentServiceType.rawValue),
                "gen_ai.request.model": .string(modelName),
                "langfuse.observation.metadata.app_name": .string(context.applicationName),
                "langfuse.observation.metadata.tools_count": .int(availableTools.count)
            ]
        ) { span in
            let recommendationService = AIToolRecommendationService(aiClient: self)
            let recommendation = try await recommendationService.recommendTool(
                context: context,
                availableTools: availableTools
            )

            // Add recommendation result to span
            span?.setAttribute(key: "langfuse.observation.metadata.recommended_tool", value: .string(recommendation.toolName))
            span?.setAttribute(key: "langfuse.observation.metadata.confidence", value: .double(recommendation.confidence))

            return recommendation
        }
    }

    // MARK: - Vision API Support

    /// Smart AI 推荐入口（业务层统一调用）
    /// 业务只关心“有几张截图以及语义”，不关心具体供应商。
    internal func generateSmartRecommendationWithScreenshots(
        systemPrompt: String,
        userPrompt: String,
        screenshots: SmartContextScreenshots
    ) async throws -> String {
        let imageBase64List = screenshots.orderedAvailable
        guard !imageBase64List.isEmpty else {
            return try await generate(systemPrompt: systemPrompt, userInput: userPrompt)
        }

        let annotatedPrompt = buildSmartRecommendationVisionPrompt(
            userPrompt: userPrompt,
            hasAnnotatedUITreeScreenshot: screenshots.focusedApp != nil,
            hasFullScreenScreenshot: screenshots.fullScreen != nil
        )

        if currentServiceType == .gemini {
            let apiKey = KeychainManager.shared.getAPIKey(for: .gemini) ?? ""
            return try await GeminiService.shared.generateWithImages(
                systemPrompt: systemPrompt,
                userPrompt: annotatedPrompt,
                imageBase64List: imageBase64List,
                apiKey: apiKey
            )
        }

        if currentServiceType == .openai {
            return try await generateWithImages(
                systemPrompt: systemPrompt,
                userPrompt: annotatedPrompt,
                imageBase64List: imageBase64List
            )
        }

        // 其他服务当前未接入多图视觉，降级文本（仍带语义说明）
        return try await generate(systemPrompt: systemPrompt, userInput: annotatedPrompt)
    }

    /// Generate response with image (Vision API)
    internal func generateWithImage(systemPrompt: String, userPrompt: String, imageBase64: String) async throws -> String {
        return try await generateWithImages(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            imageBase64List: [imageBase64]
        )
    }

    /// Generate response with multiple images (Vision API)
    internal func generateWithImages(
        systemPrompt: String,
        userPrompt: String,
        imageBase64List: [String]
    ) async throws -> String {
        let imageDataURLs = Array(imageBase64List.prefix(2)).map { "data:image/jpeg;base64,\($0)" }
        guard !imageDataURLs.isEmpty else {
            return try await generate(systemPrompt: systemPrompt, userInput: userPrompt)
        }

        let client = try getOrCreateClient()
        let serviceType = currentServiceType
        let modelName = getVisionModel()
        let endpoint = buildEndpointURL(for: serviceType)
        let headersPayload = buildRequestHeadersPayload(for: serviceType)
        let messages: [ChatQuery.ChatCompletionMessageParam]
        if imageDataURLs.count >= 2 {
            messages = [
                .system(.init(content: .textContent(systemPrompt))),
                .user(.init(
                    content: .contentParts([
                        .image(.init(imageUrl: .init(
                            url: imageDataURLs[0],
                            detail: .auto
                        ))),
                        .image(.init(imageUrl: .init(
                            url: imageDataURLs[1],
                            detail: .auto
                        ))),
                        .text(.init(text: userPrompt))
                    ])
                ))
            ]
        } else {
            messages = [
                .system(.init(content: .textContent(systemPrompt))),
                .user(.init(
                    content: .contentParts([
                        .image(.init(imageUrl: .init(
                            url: imageDataURLs[0],
                            detail: .auto
                        ))),
                        .text(.init(text: userPrompt))
                    ])
                ))
            ]
        }

        let messagesPayload = buildVisionMessagesPayload(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            imageDataURLs: imageDataURLs
        )
        let requestBodyPayload = buildOpenAIRequestBodyPayload(modelName: modelName, messagesPayload: messagesPayload)
        let parametersPayload = buildRequestParametersPayload(modelName: modelName)

        let query = ChatQuery(
            messages: messages,
            model: modelName,
            temperature: deterministicTemperature
        )

        do {
            let result = try await client.chats(query: query)
            guard let firstChoice = result.choices.first else {
                throw PromptToolError.apiError("No response received")
            }

            let content = firstChoice.message.content ?? ""
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            await recordRequestPayload(
                toolName: APIRequestExecutionContext.toolName,
                serviceType: serviceType,
                modelName: modelName,
                httpMethod: "POST",
                endpoint: endpoint,
                headersPayload: headersPayload,
                requestBodyPayload: requestBodyPayload,
                messagesPayload: messagesPayload,
                parametersPayload: parametersPayload,
                hasImage: true,
                imageCount: imageDataURLs.count,
                responseText: trimmedContent,
                error: nil
            )
            return trimmedContent
        } catch {
            let handledError = handleAPIError(error)
            await recordRequestPayload(
                toolName: APIRequestExecutionContext.toolName,
                serviceType: serviceType,
                modelName: modelName,
                httpMethod: "POST",
                endpoint: endpoint,
                headersPayload: headersPayload,
                requestBodyPayload: requestBodyPayload,
                messagesPayload: messagesPayload,
                parametersPayload: parametersPayload,
                hasImage: true,
                imageCount: imageDataURLs.count,
                responseText: nil,
                error: handledError
            )
            throw handledError
        }
    }

    /// 处理 API 错误
    private func handleAPIError(_ error: Error) -> Error {
        if let urlError = error as? URLError {
            return PromptToolError.networkError(urlError)
        }
        return PromptToolError.apiError(error.localizedDescription)
    }

    /// Get vision-capable model for current service
    private func getVisionModel() -> String {
        getModel()
    }

    /// 文本请求的 messages 负载
    private func buildTextMessagesPayload(systemPrompt: String, userInput: String) -> [[String: Any]] {
        [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": userInput
            ]
        ]
    }

    /// 视觉请求的 messages 负载
    private func buildVisionMessagesPayload(
        systemPrompt: String,
        userPrompt: String,
        imageDataURLs: [String]
    ) -> [[String: Any]] {
        var userContent: [[String: Any]] = imageDataURLs.map { url in
            [
                "type": "image_url",
                "image_url": [
                    "url": url,
                    "detail": "auto"
                ]
            ]
        }
        userContent.append([
            "type": "text",
            "text": userPrompt
        ])

        return [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": userContent
            ]
        ]
    }

    /// 给 Smart AI 推荐场景补充双截图语义说明
    private func buildSmartRecommendationVisionPrompt(
        userPrompt: String,
        hasAnnotatedUITreeScreenshot: Bool,
        hasFullScreenScreenshot: Bool
    ) -> String {
        var hints: [String] = []
        if hasAnnotatedUITreeScreenshot {
            hints.append("Image 1 is the full-screen screenshot with UI-tree annotations.")
        }
        if hasAnnotatedUITreeScreenshot && hasFullScreenScreenshot {
            hints.append("Image 2 is the raw full-screen screenshot.")
        } else if !hasAnnotatedUITreeScreenshot && hasFullScreenScreenshot {
            hints.append("Image 1 is the full-screen screenshot.")
        }

        guard !hints.isEmpty else { return userPrompt }
        return """
        Vision Context:
        - \(hints.joined(separator: "\n- "))

        \(userPrompt)
        """
    }

    /// 请求参数负载（messages 之外的请求体参数）
    private func buildRequestParametersPayload(modelName: String) -> [String: Any] {
        [
            "model": modelName,
            "temperature": deterministicTemperature
        ]
    }

    /// 构建请求头（敏感信息脱敏）
    private func buildRequestHeadersPayload(for serviceType: AIServiceType) -> [String: String] {
        if serviceType == .codex {
            return [
                "Content-Type": "application/json",
                "Accept": "text/event-stream",
                "Authorization": "Bearer [REDACTED]",
                "chatgpt-account-id": "[REDACTED]",
                "OpenAI-Beta": "responses=experimental",
                "originator": "pi",
                "X-Provider": serviceType.rawValue
            ]
        }

        return [
            "Content-Type": "application/json",
            "Authorization": "Bearer [REDACTED]",
            "X-Provider": serviceType.rawValue
        ]
    }

    /// 构建 OpenAI 兼容请求体
    private func buildOpenAIRequestBodyPayload(modelName: String, messagesPayload: [[String: Any]]) -> [String: Any] {
        [
            "model": modelName,
            "messages": messagesPayload,
            "temperature": deterministicTemperature
        ]
    }

    /// 构建 Codex Responses 请求体
    private func buildCodexResponsesRequestBodyPayload(modelName: String, systemPrompt: String, userInput: String) -> [String: Any] {
        [
            "model": modelName,
            "store": false,
            "instructions": systemPrompt,
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": userInput
                        ]
                    ]
                ]
            ],
            "stream": true
        ]
    }

    /// 提取 Codex Responses 文本输出
    private func extractCodexResponseText(from data: Data) throws -> String {
        let raw = String(data: data, encoding: .utf8) ?? ""
        if raw.contains("data:") {
            return try extractCodexStreamedResponseText(from: raw)
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PromptToolError.apiError("Invalid Codex JSON response")
        }

        if let outputText = object["output_text"] as? String {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let output = object["output"] as? [[String: Any]] {
            let text = output
                .compactMap { item -> String? in
                    guard let content = item["content"] as? [[String: Any]] else { return nil }
                    return content.compactMap { part in
                        part["text"] as? String
                    }.joined()
                }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                return text
            }
        }

        throw PromptToolError.apiError("No Codex response text received")
    }

    private func extractCodexStreamedResponseText(from raw: String) throws -> String {
        var streamedText = ""
        var completedText: String?

        for chunk in raw.components(separatedBy: "\n\n") {
            let payload = chunk
                .split(separator: "\n")
                .compactMap { line -> String? in
                    guard line.hasPrefix("data:") else { return nil }
                    return String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .joined(separator: "\n")
            guard !payload.isEmpty, payload != "[DONE]" else { continue }
            guard let eventData = payload.data(using: .utf8),
                  let event = try JSONSerialization.jsonObject(with: eventData) as? [String: Any] else {
                continue
            }

            if event["type"] as? String == "error" {
                throw PromptToolError.apiError(event["message"] as? String ?? payload)
            }
            if event["type"] as? String == "response.failed" {
                let response = event["response"] as? [String: Any]
                let error = response?["error"] as? [String: Any]
                throw PromptToolError.apiError(error?["message"] as? String ?? payload)
            }
            if event["type"] as? String == "response.output_text.delta",
               let delta = event["delta"] as? String {
                streamedText += delta
            }
            if event["type"] as? String == "response.completed",
               let response = event["response"] as? [String: Any],
               let output = response["output"] as? [[String: Any]] {
                completedText = output
                    .compactMap { item -> String? in
                        guard let content = item["content"] as? [[String: Any]] else { return nil }
                        return content.compactMap { part in
                            part["text"] as? String
                        }.joined()
                    }
                    .joined(separator: "\n")
            }
        }

        let text = (completedText?.isEmpty == false ? completedText : streamedText)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw PromptToolError.apiError("No Codex response text received")
        }
        return text
    }

    /// 构建服务对应的请求 URL
    private func buildEndpointURL(for serviceType: AIServiceType) -> String {
        if serviceType == .codex {
            return "https://chatgpt.com/backend-api/codex/responses"
        }

        let config = serviceType.sdkConfiguration
        let defaultPort = (config.scheme == "https" && config.port == 443) || (config.scheme == "http" && config.port == 80)
        let portSuffix = defaultPort ? "" : ":\(config.port)"
        return "\(config.scheme)://\(config.host)\(portSuffix)/v1/chat/completions"
    }

    /// 记录真实发送到 API 的请求负载
    private func recordRequestPayload(
        toolName: String?,
        serviceType: AIServiceType,
        modelName: String,
        httpMethod: String,
        endpoint: String,
        headersPayload: [String: String],
        requestBodyPayload: [String: Any],
        messagesPayload: [[String: Any]],
        parametersPayload: [String: Any],
        hasImage: Bool,
        imageCount: Int,
        responseText: String?,
        error: Error?
    ) async {
        let record = APIRequestRecord(
            toolName: toolName ?? "Unknown Tool",
            serviceType: serviceType.displayName,
            modelName: modelName,
            httpMethod: httpMethod,
            endpoint: endpoint,
            headersJSON: serializeToPrettyJSON(headersPayload),
            requestBodyJSON: serializeToPrettyJSON(requestBodyPayload),
            messagesJSON: serializeToPrettyJSON(messagesPayload),
            parametersJSON: serializeToPrettyJSON(parametersPayload),
            hasImage: hasImage,
            imageCount: imageCount,
            responseText: responseText,
            error: error?.localizedDescription
        )

        await apiRequestRecorder.record(record)
    }

    /// 序列化为可读的 JSON 字符串
    private func serializeToPrettyJSON(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}

extension AIService: SmartRecommendationAIClient {}

// MARK: - AI Service Configuration

struct AIServiceConfiguration {
    var serviceType: AIServiceType
    var apiKey: String
    var host: String
    var scheme: String
    var port: Int
    var model: String

    static var current: AIServiceConfiguration {
        let service = AIService.shared
        let config = service.currentServiceType.sdkConfiguration
        return AIServiceConfiguration(
            serviceType: service.currentServiceType,
            apiKey: KeychainManager.shared.getAPIKey(for: service.currentServiceType) ?? "",
            host: config.host,
            scheme: config.scheme,
            port: config.port,
            model: service.currentServiceType.selectedModel
        )
    }
}
