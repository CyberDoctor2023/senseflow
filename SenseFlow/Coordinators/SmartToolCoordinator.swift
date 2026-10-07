//
//  SmartToolCoordinator.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// Smart Tool 协调器
/// 职责：协调 Smart AI 的分析和推荐流程
final class SmartToolCoordinator {
    private let analyzeAndRecommendUseCase: AnalyzeAndRecommend

    init(analyzeAndRecommendUseCase: AnalyzeAndRecommend) {
        self.analyzeAndRecommendUseCase = analyzeAndRecommendUseCase
    }

    /// 分析上下文并推荐工具
    func analyze() async throws -> SmartRecommendation {
        return try await analyzeAndRecommendUseCase.analyze()
    }

    /// 分析并自动执行推荐的工具
    func analyzeAndExecute() async throws {
        try await analyzeAndRecommendUseCase.analyzeAndExecute()
    }
}
