//
//  MockAIService.swift
//  SenseFlowTests
//
//  Created on 2026-02-02.
//

import Foundation
@testable import SenseFlow

final class MockAIService: AIServiceProtocol {
    // 配置返回值
    var generateResult: String = ""
    var recommendResult: SmartRecommendation?

    // 记录调用
    var generateCallCount = 0
    var lastSystemPrompt: String?
    var lastUserInput: String?

    var recommendCallCount = 0
    var lastContext: SmartContext?
    var lastAvailableTools: [PromptTool]?

    // 模拟错误
    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic

    func generate(systemPrompt: String, userInput: String) async throws -> String {
        generateCallCount += 1
        lastSystemPrompt = systemPrompt
        lastUserInput = userInput

        if shouldThrowError {
            throw errorToThrow
        }

        return generateResult
    }

    func recommendTool(context: SmartContext, availableTools: [PromptTool]) async throws -> SmartRecommendation {
        recommendCallCount += 1
        lastContext = context
        lastAvailableTools = availableTools

        if shouldThrowError {
            throw errorToThrow
        }

        guard let result = recommendResult else {
            throw MockError.noRecommendationConfigured
        }

        return result
    }
}

enum MockError: Error {
    case generic
    case noRecommendationConfigured
}
