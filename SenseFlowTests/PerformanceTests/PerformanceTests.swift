//
//  PerformanceTests.swift
//  SenseFlowTests
//
//  Created on 2026-02-03.
//

import XCTest
@testable import SenseFlow

final class PerformanceTests: XCTestCase {

    // MARK: - ExecutePromptTool Performance

    func test_executePromptTool_performance() {
        // Arrange
        let mockAI = MockAIService()
        let mockReader = MockClipboardReader()
        let mockWriter = MockClipboardWriter()
        let mockNotification = MockNotificationService()

        mockReader.textToReturn = "Test input"
        mockAI.generateResult = "Test output"

        let sut = ExecutePromptTool(
            aiService: mockAI,
            clipboardReader: mockReader,
            clipboardWriter: mockWriter,
            notificationService: mockNotification
        )

        let tool = PromptTool(name: "Test Tool", prompt: "Test prompt")

        // Measure
        measure {
            let expectation = self.expectation(description: "Execute tool")

            Task {
                _ = try? await sut.execute(tool: tool)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)
        }

        // Baseline: 应该在 0.01 秒内完成（不包括实际 AI 调用）
    }

    // MARK: - RegisterToolHotKey Performance

    func test_registerToolHotKey_performance() {
        // Arrange
        let mockRegistry = MockHotKeyRegistry()
        let sut = RegisterToolHotKey(hotKeyRegistry: mockRegistry)

        let tool = PromptTool(
            name: "Test Tool",
            prompt: "Test",
            shortcutKeyCode: 0x09,
            shortcutModifiers: 0x108
        )

        // Measure
        measure {
            try? sut.register(tool: tool) { }
        }

        // Baseline: 应该在 0.001 秒内完成
    }

    // MARK: - PromptToolCoordinator Performance

    func test_coordinatorLoadTools_performance() {
        // Arrange
        let mockRepo = MockPromptToolRepository()
        let mockExecute = ExecutePromptTool(
            aiService: MockAIService(),
            clipboardReader: MockClipboardReader(),
            clipboardWriter: MockClipboardWriter(),
            notificationService: MockNotificationService()
        )
        let mockHotKeyCoordinator = MockPerformancePromptToolHotKeyCoordinator()

        let sut = PromptToolCoordinator(
            repository: mockRepo,
            executeToolUseCase: mockExecute,
            hotKeyCoordinator: mockHotKeyCoordinator
        )

        // 创建 100 个工具
        mockRepo.toolsToReturn = (0..<100).map { i in
            PromptTool(name: "Tool \(i)", prompt: "Prompt \(i)")
        }

        // Measure
        measure {
            let expectation = self.expectation(description: "Load tools")

            Task {
                _ = try? await sut.loadTools()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)
        }

        // Baseline: 加载 100 个工具应该在 0.01 秒内完成
    }

    func test_coordinatorCreateTool_performance() {
        // Arrange
        let mockRepo = MockPromptToolRepository()
        let mockExecute = ExecutePromptTool(
            aiService: MockAIService(),
            clipboardReader: MockClipboardReader(),
            clipboardWriter: MockClipboardWriter(),
            notificationService: MockNotificationService()
        )
        let mockHotKeyCoordinator = MockPerformancePromptToolHotKeyCoordinator()

        let sut = PromptToolCoordinator(
            repository: mockRepo,
            executeToolUseCase: mockExecute,
            hotKeyCoordinator: mockHotKeyCoordinator
        )

        // Measure
        measure {
            let expectation = self.expectation(description: "Create tool")

            Task {
                try? await sut.createTool(
                    name: "Performance Test Tool",
                    prompt: "Test prompt",
                    capabilities: [],
                    shortcutKeyCode: 0x09,
                    shortcutModifiers: 0x108
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)
        }

        // Baseline: 创建工具应该在 0.01 秒内完成
    }

    // MARK: - AnalyzeAndRecommend Performance

    func test_analyzeAndRecommend_performance() {
        // Arrange
        let mockContext = MockContextCollector()
        let mockRepo = MockPromptToolRepository()
        let mockAI = MockAIService()
        let mockExecute = MockExecutePromptTool()
        let mockNotification = MockNotificationService()

        let tool = PromptTool(name: "Test Tool", prompt: "Test")
        mockRepo.toolsToReturn = [tool]

        mockAI.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.8,
            reasoning: "Test"
        )

        let sut = AnalyzeAndRecommend(
            contextCollector: mockContext,
            toolRepository: mockRepo,
            aiService: mockAI,
            executeToolUseCase: mockExecute,
            notificationService: mockNotification
        )

        // Measure
        measure {
            let expectation = self.expectation(description: "Analyze")

            Task {
                _ = try? await sut.analyze()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)
        }

        // Baseline: 分析应该在 0.01 秒内完成（不包括实际 AI 调用）
    }

    // MARK: - Batch Operations Performance

    func test_registerMultipleHotKeys_performance() {
        // Arrange
        let mockRepo = MockPromptToolRepository()
        let mockExecute = ExecutePromptTool(
            aiService: MockAIService(),
            clipboardReader: MockClipboardReader(),
            clipboardWriter: MockClipboardWriter(),
            notificationService: MockNotificationService()
        )
        let mockHotKeyCoordinator = MockPerformancePromptToolHotKeyCoordinator()

        let sut = PromptToolCoordinator(
            repository: mockRepo,
            executeToolUseCase: mockExecute,
            hotKeyCoordinator: mockHotKeyCoordinator
        )

        // 创建 50 个带快捷键的工具
        mockRepo.toolsToReturn = (0..<50).map { i in
            PromptTool(
                name: "Tool \(i)",
                prompt: "Prompt \(i)",
                shortcutKeyCode: UInt16(0x09 + i % 10),
                shortcutModifiers: 0x108
            )
        }

        // Measure
        measure {
            let expectation = self.expectation(description: "Register all")

            Task {
                try? await sut.registerAllHotKeys()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }

        // Baseline: 注册 50 个快捷键应该在 0.1 秒内完成
    }

    // MARK: - Memory Performance

    func test_coordinatorMemoryUsage() {
        // Arrange
        let mockRepo = MockPromptToolRepository()
        let mockExecute = ExecutePromptTool(
            aiService: MockAIService(),
            clipboardReader: MockClipboardReader(),
            clipboardWriter: MockClipboardWriter(),
            notificationService: MockNotificationService()
        )
        let mockHotKeyCoordinator = MockPerformancePromptToolHotKeyCoordinator()

        // 创建 1000 个工具测试内存使用
        mockRepo.toolsToReturn = (0..<1000).map { i in
            PromptTool(name: "Tool \(i)", prompt: "Prompt \(i)")
        }

        // Measure
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let sut = PromptToolCoordinator(
                repository: mockRepo,
                executeToolUseCase: mockExecute,
                hotKeyCoordinator: mockHotKeyCoordinator
            )

            startMeasuring()

            let expectation = self.expectation(description: "Load 1000 tools")

            Task {
                _ = try? await sut.loadTools()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)

            stopMeasuring()

            // 清理
            _ = sut
        }

        // Baseline: 加载 1000 个工具应该在 0.1 秒内完成
    }
}

private final class MockPerformancePromptToolHotKeyCoordinator: PromptToolHotKeyHandling, @unchecked Sendable {
    func registerToolHotKey(for tool: PromptTool, handler: @escaping @Sendable () -> Void) throws { }
    func unregisterToolHotKey(for toolID: ToolID) { }
    func unregisterAllToolHotKeys() { }
}
