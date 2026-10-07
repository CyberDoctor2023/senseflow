//
//  AnalyzeAndRecommend.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

protocol SmartAILiveOverlaySessionControlling: Sendable {
    @MainActor
    func beginSession()

    @MainActor
    func endSession()
}

struct NoopSmartAILiveOverlaySessionController: SmartAILiveOverlaySessionControlling {
    @MainActor
    func beginSession() {}

    @MainActor
    func endSession() {}
}

/// Smart AI 分析和推荐用例
/// 职责：收集上下文 → AI 推荐工具 → 执行推荐的工具
final class AnalyzeAndRecommend: Sendable {
    private let contextCollector: ContextCollector
    private let toolRepository: PromptToolRepository
    private let aiService: AIServiceProtocol
    private let executeToolUseCase: ExecutePromptTool
    private let notificationService: NotificationServiceProtocol
    private let liveOverlaySessionController: any SmartAILiveOverlaySessionControlling

    init(
        contextCollector: ContextCollector,
        toolRepository: PromptToolRepository,
        aiService: AIServiceProtocol,
        executeToolUseCase: ExecutePromptTool,
        notificationService: NotificationServiceProtocol,
        liveOverlaySessionController: any SmartAILiveOverlaySessionControlling = NoopSmartAILiveOverlaySessionController()
    ) {
        self.contextCollector = contextCollector
        self.toolRepository = toolRepository
        self.aiService = aiService
        self.executeToolUseCase = executeToolUseCase
        self.notificationService = notificationService
        self.liveOverlaySessionController = liveOverlaySessionController
    }

    /// 分析上下文并推荐工具
    /// - Returns: 推荐结果
    func analyze() async throws -> SmartRecommendation {
        await beginOverlaySession()
        defer { endOverlaySession() }
        return try await analyzeCore()
    }

    /// 分析并自动执行推荐的工具
    func analyzeAndExecute() async throws {
        await beginOverlaySession()
        defer { endOverlaySession() }

        // 1. 显示分析通知
        notificationService.showInProgress(
            title: "Smart AI",
            body: "正在分析上下文..."
        )

        // 2. 获取推荐
        let recommendation = try await analyzeCore()

        // 3. 查找推荐的工具
        guard let tool = try await toolRepository.find(by: ToolID(recommendation.toolID)) else {
            throw SmartAIError.toolNotFound
        }

        // 4. 显示执行通知
        notificationService.showInProgress(
            title: "Smart AI",
            body: "正在使用「\(tool.name)」处理..."
        )

        // 5. 执行工具
        _ = try await executeToolUseCase.execute(tool: tool)
    }

    private func analyzeCore() async throws -> SmartRecommendation {
        // 1. 收集上下文
        let context = try await contextCollector.collect()

        // 2. 获取可用工具
        let tools = try await toolRepository.findAll()
        guard !tools.isEmpty else {
            throw SmartAIError.noToolsAvailable
        }

        // 3. AI 推荐
        let recommendation = try await aiService.recommendTool(
            context: context,
            availableTools: tools
        )

        // 4. 验证推荐置信度
        guard recommendation.confidence >= 0.6 else {
            throw SmartAIError.lowConfidence(recommendation.confidence)
        }

        return recommendation
    }

    private func beginOverlaySession() async {
        await MainActor.run {
            liveOverlaySessionController.beginSession()
        }
    }

    private func endOverlaySession() {
        Task { @MainActor [liveOverlaySessionController] in
            liveOverlaySessionController.endSession()
        }
    }
}

// MARK: - Context Collector Protocol

/// 上下文收集器协议
protocol ContextCollector: Sendable {
    func collect() async throws -> SmartContext
}

// MARK: - Errors

enum SmartAIError: LocalizedError {
    case noToolsAvailable
    case lowConfidence(Double)
    case toolNotFound
    case contextCollectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noToolsAvailable:
            return "没有可用的 Prompt Tools"
        case .lowConfidence(let confidence):
            return "推荐置信度过低: \(String(format: "%.1f%%", confidence * 100))"
        case .toolNotFound:
            return "推荐的工具未找到"
        case .contextCollectionFailed(let error):
            return "上下文收集失败: \(error.localizedDescription)"
        }
    }
}
