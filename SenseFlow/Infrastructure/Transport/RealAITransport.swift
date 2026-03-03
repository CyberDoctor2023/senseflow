//
//  RealAITransport.swift
//  SenseFlow
//
//  Created on 2026-02-26.
//
//  【架构说明 - Real Transport Implementation】
//  真实的 AI 传输层实现
//
//  职责：
//  - 调用底层的 AIService 发送请求
//  - 将 AIServiceProtocol 适配到 AITransport 接口
//  - 处理错误转换
//
//  设计模式：
//  - Adapter Pattern：将 AIServiceProtocol 适配到 AITransport
//

import Foundation

/// 真实的 AI 传输层实现
///
/// 【实现说明】
/// - 委托给 AIServiceProtocol 执行真实的 API 调用
/// - 负责错误转换和响应封装
/// - 不包含记录、重试等横切关注点（由 Decorator 处理）
final class RealAITransport: AITransport {

    // MARK: - Dependencies

    /// AI 服务（底层实现）
    private let aiService: AIServiceProtocol

    // MARK: - Initialization

    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }

    // MARK: - AITransport

    func send(_ request: AITransportRequest) async throws -> AITransportResponse {
        do {
            // 调用底层 AI 服务
            let content = try await aiService.generate(
                systemPrompt: request.systemPrompt,
                userInput: request.userInput
            )

            // 获取当前服务信息
            let serviceType = AIService.shared.currentServiceType.displayName
            let modelName = AIService.shared.currentServiceType.selectedModel

            // 封装响应
            return AITransportResponse(
                content: content,
                serviceType: serviceType,
                modelName: modelName,
                metadata: nil
            )
        } catch {
            // 错误转换
            throw AITransportError.apiError(error.localizedDescription)
        }
    }
}
