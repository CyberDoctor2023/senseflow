//
//  AITransport.swift
//  SenseFlow
//
//  Created on 2026-02-26.
//
//  【架构说明 - Transport Layer】
//  传输层：负责所有与 AI API 的通信
//
//  职责：
//  - 发送请求到 AI 服务
//  - 记录请求/响应（用于调试、追踪、审计）
//  - 处理重试、超时等横切关注点
//  - 提供统一的错误处理
//
//  为什么需要 Transport 层？
//  1. 关注点分离：Use Case 只关心业务逻辑，不关心传输细节
//  2. 横切关注点：记录、追踪、重试等逻辑集中管理
//  3. 可测试性：可以注入 Mock Transport
//  4. 可观测性：所有 API 调用都经过这一层，便于监控
//
//  设计模式：
//  - Strategy Pattern：不同的 Transport 实现（Real、Mock、Logging）
//  - Decorator Pattern：LoggingTransport 装饰 RealTransport
//  - Chain of Responsibility：可以串联多个 Transport（Logging → Retry → Real）
//

import Foundation

/// AI 传输请求
///
/// 【Domain Entity】
/// 表示一次 AI 请求的完整信息
struct AITransportRequest: Sendable {
    /// 工具名称（用于追踪）
    let toolName: String

    /// System Prompt
    let systemPrompt: String

    /// User Input
    let userInput: String

    /// 请求元数据（可选）
    let metadata: [String: String]?

    init(
        toolName: String,
        systemPrompt: String,
        userInput: String,
        metadata: [String: String]? = nil
    ) {
        self.toolName = toolName
        self.systemPrompt = systemPrompt
        self.userInput = userInput
        self.metadata = metadata
    }
}

/// AI 传输响应
///
/// 【Domain Entity】
/// 表示 AI 响应的完整信息
struct AITransportResponse: Sendable {
    /// 响应内容
    let content: String

    /// 使用的服务类型
    let serviceType: String

    /// 使用的模型
    let modelName: String

    /// 响应元数据（可选）
    let metadata: [String: String]?

    init(
        content: String,
        serviceType: String,
        modelName: String,
        metadata: [String: String]? = nil
    ) {
        self.content = content
        self.serviceType = serviceType
        self.modelName = modelName
        self.metadata = metadata
    }
}

/// AI 传输层协议（Port）
///
/// 【职责】
/// 定义与 AI 服务通信的抽象接口
///
/// 【实现者】
/// - RealAITransport：真实的 API 调用
/// - LoggingAITransport：带记录的传输层（Decorator）
/// - MockAITransport：测试用实现
/// - RetryAITransport：带重试的传输层（Decorator）
///
/// 【为什么不直接用 AIServiceProtocol？】
/// - AIServiceProtocol 是业务层接口（generate 方法）
/// - AITransport 是传输层接口（send 方法）
/// - Transport 层可以包含更多横切关注点（记录、重试、追踪）
/// - Transport 层可以装饰组合（Logging + Retry + Real）
protocol AITransport: Sendable {
    /// 发送请求
    ///
    /// - Parameter request: 传输请求
    /// - Returns: 传输响应
    /// - Throws: 传输错误
    func send(_ request: AITransportRequest) async throws -> AITransportResponse
}

/// API 请求执行上下文
///
/// 用于在异步调用链中传递调用来源（例如 Prompt Tool 名称），
/// 让底层真实请求记录可以关联到业务语义。
enum APIRequestExecutionContext {
    @TaskLocal static var toolName: String?
}

/// AI 传输错误
enum AITransportError: LocalizedError {
    case networkError(Error)
    case apiError(String)
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .timeout:
            return "请求超时"
        case .invalidResponse:
            return "无效的响应"
        }
    }
}
