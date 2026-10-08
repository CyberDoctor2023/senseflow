import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import Network
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
                self.respond(connection, status: "200 OK", body: "Authentication successful. Return to senseflow.")
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
