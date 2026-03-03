//
//  LoggingAITransport.swift
//  SenseFlow
//
//  Created on 2026-02-26.
//
//  【架构说明 - Context Transport Decorator】
//  传输层上下文透传装饰器
//
//  职责：
//  - 装饰另一个 Transport，透传调用上下文（toolName）
//  - 委托给被装饰的 Transport 执行真实操作
//
//  设计模式：
//  - Decorator Pattern：动态添加上下文能力
//  - Chain of Responsibility：可以串联多个装饰器
//
//  为什么用 Decorator？
//  - 开闭原则：不修改 RealTransport，通过装饰添加上下文能力
//  - 单一职责：RealTransport 只负责调用 API，Decorator 只负责上下文
//  - 灵活组合：可以继续串联 Retry/Tracing 等装饰器
//
//  使用示例：
//  ```swift
//  let realTransport = RealAITransport(aiService: aiService)
//  let loggingTransport = LoggingAITransport(transport: realTransport)
//  // toolName 会在调用链中透传到 Provider 层
//  let response = try await loggingTransport.send(request)
//  ```
//

import Foundation

/// 传输层装饰器：负责透传调用上下文
///
/// 注意：
/// - 真实请求记录已下沉到 Provider 层（AIService / GeminiService）
/// - 此装饰器只负责把 toolName 透传到异步上下文
final class LoggingAITransport: AITransport {

    // MARK: - Dependencies

    private let transport: AITransport

    // MARK: - Initialization

    init(transport: AITransport) {
        self.transport = transport
    }

    // MARK: - AITransport

    func send(_ request: AITransportRequest) async throws -> AITransportResponse {
        try await APIRequestExecutionContext.$toolName.withValue(request.toolName) {
            try await transport.send(request)
        }
    }
}
