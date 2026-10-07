//
//  ExecutePromptToolTests.swift
//  SenseFlowTests
//
//  Created on 2026-02-02.
//

import XCTest
@testable import SenseFlow

final class ExecutePromptToolTests: XCTestCase {

    // MARK: - Properties

    var mockAI: MockAIService!
    var mockReader: MockClipboardReader!
    var mockWriter: MockClipboardWriter!
    var mockNotification: MockNotificationService!
    var sut: ExecutePromptTool!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        mockAI = MockAIService()
        mockReader = MockClipboardReader()
        mockWriter = MockClipboardWriter()
        mockNotification = MockNotificationService()

        sut = ExecutePromptTool(
            aiService: mockAI,
            clipboardReader: mockReader,
            clipboardWriter: mockWriter,
            notificationService: mockNotification
        )
    }

    override func tearDown() {
        sut = nil
        mockNotification = nil
        mockWriter = nil
        mockReader = nil
        mockAI = nil

        super.tearDown()
    }

    // MARK: - Tests: Success Cases

    func test_execute_withValidInput_returnsAIResult() async throws {
        // Arrange
        mockReader.textToReturn = "Hello World"
        mockAI.generateResult = "你好世界"

        let tool = PromptTool(
            name: "翻译",
            prompt: "Translate to Chinese: {{input}}"
        )

        // Act
        let result = try await sut.execute(tool: tool)

        // Assert
        XCTAssertEqual(result, "你好世界", "应该返回 AI 生成的结果")
    }

    func test_execute_withValidInput_callsAIServiceWithCorrectPrompt() async throws {
        // Arrange
        mockReader.textToReturn = "Hello"
        mockAI.generateResult = "Result"

        let tool = PromptTool(
            name: "Test Tool",
            prompt: "System prompt here"
        )

        // Act
        _ = try await sut.execute(tool: tool)

        // Assert
        XCTAssertEqual(mockAI.generateCallCount, 1, "应该调用 AI 服务一次")
        XCTAssertEqual(mockAI.lastSystemPrompt, "System prompt here", "应该传递正确的系统提示词")
        XCTAssertEqual(mockAI.lastUserInput, "Hello", "应该传递剪贴板内容作为用户输入")
    }

    func test_execute_withValidInput_writesToClipboard() async throws {
        // Arrange
        mockReader.textToReturn = "Input"
        mockAI.generateResult = "AI Output"

        let tool = PromptTool(name: "Tool", prompt: "Prompt")

        // Act
        _ = try await sut.execute(tool: tool)

        // Assert
        XCTAssertTrue(mockWriter.didWrite, "应该写入剪贴板")
        XCTAssertEqual(mockWriter.writtenText, "AI Output", "应该写入 AI 生成的结果")
    }

    func test_execute_withValidInput_showsNotifications() async throws {
        // Arrange
        mockReader.textToReturn = "Input"
        mockAI.generateResult = "Output"

        let tool = PromptTool(name: "翻译工具", prompt: "Translate")

        // Act
        _ = try await sut.execute(tool: tool)

        // Assert
        XCTAssertEqual(mockNotification.showInProgressCallCount, 1, "应该显示进行中通知")
        XCTAssertEqual(mockNotification.lastInProgressTitle, "翻译工具")

        XCTAssertEqual(mockNotification.showSuccessCallCount, 1, "应该显示成功通知")
        XCTAssertEqual(mockNotification.lastSuccessTitle, "翻译工具")
        XCTAssertTrue(mockNotification.didShowSuccess, "应该显示成功通知")
    }

    // MARK: - Tests: Error Cases

    func test_execute_withEmptyClipboard_throwsError() async {
        // Arrange
        mockReader.textToReturn = nil  // 剪贴板为空

        let tool = PromptTool(name: "Tool", prompt: "Prompt")

        // Act & Assert
        do {
            _ = try await sut.execute(tool: tool)
            XCTFail("应该抛出错误")
        } catch {
            // 验证错误类型
            XCTAssertTrue(error is ExecuteToolError, "应该抛出 ExecuteToolError")
        }
    }

    func test_execute_withEmptyClipboard_showsErrorNotification() async {
        // Arrange
        mockReader.textToReturn = nil

        let tool = PromptTool(name: "测试工具", prompt: "Prompt")

        // Act
        do {
            _ = try await sut.execute(tool: tool)
        } catch {
            // 预期错误
        }

        // Assert
        XCTAssertTrue(mockNotification.didShowError, "应该显示错误通知")
        XCTAssertEqual(mockNotification.lastErrorTitle, "测试工具")
    }

    func test_execute_withAIServiceError_throwsError() async {
        // Arrange
        mockReader.textToReturn = "Input"
        mockAI.shouldThrowError = true
        mockAI.errorToThrow = MockError.generic

        let tool = PromptTool(name: "Tool", prompt: "Prompt")

        // Act & Assert
        do {
            _ = try await sut.execute(tool: tool)
            XCTFail("应该抛出错误")
        } catch {
            // 验证错误被正确传播
            XCTAssertTrue(error is MockError, "应该传播 AI 服务的错误")
        }
    }

    func test_execute_withAIServiceError_doesNotWriteToClipboard() async {
        // Arrange
        mockReader.textToReturn = "Input"
        mockAI.shouldThrowError = true

        let tool = PromptTool(name: "Tool", prompt: "Prompt")

        // Act
        do {
            _ = try await sut.execute(tool: tool)
        } catch {
            // 预期错误
        }

        // Assert
        XCTAssertFalse(mockWriter.didWrite, "出错时不应该写入剪贴板")
    }

    // MARK: - Tests: Edge Cases

    func test_execute_withEmptyString_stillCallsAI() async throws {
        // Arrange
        mockReader.textToReturn = ""  // 空字符串（不是 nil）
        mockAI.generateResult = "Result"

        let tool = PromptTool(name: "Tool", prompt: "Prompt")

        // Act
        let result = try await sut.execute(tool: tool)

        // Assert
        XCTAssertEqual(mockAI.generateCallCount, 1, "空字符串也应该调用 AI")
        XCTAssertEqual(result, "Result")
    }

    func test_execute_withLongInput_handlesCorrectly() async throws {
        // Arrange
        let longInput = String(repeating: "A", count: 10000)
        mockReader.textToReturn = longInput
        mockAI.generateResult = "Processed"

        let tool = PromptTool(name: "Tool", prompt: "Prompt")

        // Act
        let result = try await sut.execute(tool: tool)

        // Assert
        XCTAssertEqual(mockAI.lastUserInput, longInput, "应该处理长输入")
        XCTAssertEqual(result, "Processed")
    }
}
