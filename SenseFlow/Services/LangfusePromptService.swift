//
//  LangfusePromptService.swift
//  SenseFlow
//
//  Created on 2026-01-27.
//  Langfuse Prompt Management integration
//

import Foundation

/// Langfuse Prompt 管理服务
/// 负责从 Langfuse 获取、创建、更新和删除 prompts
class LangfusePromptService {

    // MARK: - Singleton

    static let shared = LangfusePromptService()

    // MARK: - Properties

    private let baseURL: String

    /// 动态读取 Public Key（支持运行时更新）
    /// 读取顺序：环境变量 → UserDefaults → ""
    private var publicKey: String {
        return ProcessInfo.processInfo.environment["LANGFUSE_PUBLIC_KEY"]
            ?? UserDefaults.standard.string(forKey: "langfusePublicKey")
            ?? ""
    }

    /// 动态读取 Secret Key（支持运行时更新）
    /// 读取顺序：环境变量 → UserDefaults → ""
    private var secretKey: String {
        return ProcessInfo.processInfo.environment["LANGFUSE_SECRET_KEY"]
            ?? UserDefaults.standard.string(forKey: "langfuseSecretKey")
            ?? ""
    }

    /// 本地缓存（避免频繁网络请求）
    private var promptCache: [String: CachedPrompt] = [:]
    private let cacheQueue = DispatchQueue(label: "com.senseflow.promptcache")

    /// 缓存有效期（5分钟）
    private let cacheTTL: TimeInterval = BusinessRules.Langfuse.serviceCacheTTL

    // MARK: - Initialization

    private init() {
        // 从环境变量或 UserDefaults 读取配置
        self.baseURL = ProcessInfo.processInfo.environment["LANGFUSE_BASE_URL"]
            ?? UserDefaults.standard.string(forKey: "langfuseBaseURL")
            ?? "https://cloud.langfuse.com"
    }

    // MARK: - Public Methods

    /// 获取 Prompt（带缓存）
    /// - Parameters:
    ///   - name: Prompt 名称
    ///   - label: 标签（默认 "production"）
    ///   - version: 版本号（可选，如果指定则忽略 label）
    /// - Returns: LangfusePrompt 对象
    func getPrompt(name: String, label: String = "production", version: Int? = nil) async throws -> LangfusePrompt {
        let cacheKey = "\(name):\(version?.description ?? label)"

        // 检查缓存
        if let cached = cacheQueue.sync(execute: { promptCache[cacheKey] }),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            print("📦 [Langfuse] Using cached prompt: \(name)")
            return cached.prompt
        }

        // 构建 URL
        var urlString = "\(baseURL)/api/public/v2/prompts/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)"
        var queryItems: [URLQueryItem] = []

        if let version = version {
            queryItems.append(URLQueryItem(name: "version", value: "\(version)"))
        } else if label != "production" {
            queryItems.append(URLQueryItem(name: "label", value: label))
        }

        if !queryItems.isEmpty {
            var components = URLComponents(string: urlString)!
            components.queryItems = queryItems
            urlString = components.url!.absoluteString
        }

        guard let url = URL(string: urlString) else {
            throw LangfusePromptError.invalidURL
        }

        // 发送请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(createBasicAuthHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LangfusePromptError.networkError
        }

        guard httpResponse.statusCode == BusinessRules.HTTPStatus.ok else {
            throw LangfusePromptError.apiError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8) ?? "Unknown error")
        }

        // 解析响应
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let prompt = try decoder.decode(LangfusePrompt.self, from: data)

        // 更新缓存
        cacheQueue.sync {
            promptCache[cacheKey] = CachedPrompt(prompt: prompt, timestamp: Date())
        }

        print("✅ [Langfuse] Fetched prompt: \(name) (version \(prompt.version))")
        return prompt
    }

    /// 列出所有 Prompts
    func listPrompts(page: Int = 1, limit: Int = 50) async throws -> [LangfusePromptMeta] {
        var components = URLComponents(string: "\(baseURL)/api/public/v2/prompts")!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components.url else {
            throw LangfusePromptError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(createBasicAuthHeader(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LangfusePromptError.networkError
        }

        // 打印响应状态和数据用于调试
        print("📡 [Langfuse API] Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📡 [Langfuse API] Response: \(responseString)")
        }

        guard httpResponse.statusCode == BusinessRules.HTTPStatus.ok else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LangfusePromptError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let result = try decoder.decode(LangfusePromptListResponse.self, from: data)
            return result.data
        } catch {
            print("❌ [Langfuse API] Decode error: \(error)")
            throw error
        }
    }

    /// 创建新 Prompt
    func createPrompt(name: String, prompt: String, type: String = "text", labels: [String] = ["production"], config: [String: Any] = [:]) async throws -> LangfusePrompt {
        guard let url = URL(string: "\(baseURL)/api/public/v2/prompts") else {
            throw LangfusePromptError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(createBasicAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "name": name,
            "prompt": prompt,
            "type": type,
            "labels": labels,
            "config": config
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LangfusePromptError.networkError
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let prompt = try decoder.decode(LangfusePrompt.self, from: data)

        print("✅ [Langfuse] Created prompt: \(name)")
        return prompt
    }

    /// 删除 Prompt
    func deletePrompt(name: String) async throws {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string: "\(baseURL)/api/public/v2/prompts/\(encodedName)") else {
            throw LangfusePromptError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(createBasicAuthHeader(), forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LangfusePromptError.networkError
        }

        // 清除缓存
        cacheQueue.sync {
            promptCache = promptCache.filter { !$0.key.hasPrefix("\(name):") }
        }

        print("✅ [Langfuse] Deleted prompt: \(name)")
    }

    /// 清除缓存
    func clearCache() {
        cacheQueue.sync {
            promptCache.removeAll()
        }
    }

    // MARK: - Private Methods

    private func createBasicAuthHeader() -> String {
        let credentials = "\(publicKey):\(secretKey)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        return "Basic \(base64Credentials)"
    }
}

// MARK: - Models

struct LangfusePrompt: Codable {
    let id: String
    let createdAt: Date
    let updatedAt: Date
    let projectId: String
    let createdBy: String
    let prompt: String  // 对于 text 类型，这是字符串；对于 chat 类型，需要解析为消息数组
    let name: String
    let version: Int
    let type: String  // "text" or "chat"
    let config: [String: AnyCodable]
    let tags: [String]
    let labels: [String]
}

struct LangfusePromptMeta: Codable {
    let name: String
    let versions: [Int]  // API 返回版本号数组
    let type: String
    let labels: [String]
    let tags: [String]
    let lastUpdatedAt: Date  // API 返回最后更新时间
    let lastConfig: AnyCodable?  // 可选的最后配置

    // 便捷属性：获取最新版本号
    var latestVersion: Int? {
        return versions.max()
    }
}

struct LangfusePromptListResponse: Codable {
    let data: [LangfusePromptMeta]
    let meta: PaginationMeta
}

struct PaginationMeta: Codable {
    let page: Int
    let limit: Int
    let totalItems: Int
    let totalPages: Int
}

struct CachedPrompt {
    let prompt: LangfusePrompt
    let timestamp: Date
}

// MARK: - Errors

enum LangfusePromptError: LocalizedError {
    case invalidURL
    case networkError
    case apiError(statusCode: Int, message: String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Langfuse URL"
        case .networkError:
            return "Network request failed"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .notConfigured:
            return "Langfuse credentials not configured"
        }
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
