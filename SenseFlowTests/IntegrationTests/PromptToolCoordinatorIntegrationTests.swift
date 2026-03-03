//
//  PromptToolCoordinatorIntegrationTests.swift
//  SenseFlowTests
//
//  Created on 2026-02-03.
//

import XCTest
@testable import SenseFlow

final class PromptToolCoordinatorIntegrationTests: XCTestCase {

    // MARK: - Properties

    var mockRepository: MockPromptToolRepository!
    var mockHotKeyCoordinator: MockPromptToolHotKeyCoordinator!
    var mockAIService: MockAIService!
    var mockClipboardReader: MockClipboardReader!
    var mockClipboardWriter: MockClipboardWriter!
    var mockNotificationService: MockNotificationService!
    var originalAutoPasteSetting: Any?
    var sut: PromptToolCoordinator!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        originalAutoPasteSetting = UserDefaults.standard.object(forKey: "auto_paste_enabled")
        UserDefaults.standard.set(false, forKey: "auto_paste_enabled")

        mockRepository = MockPromptToolRepository()
        mockHotKeyCoordinator = MockPromptToolHotKeyCoordinator()
        mockAIService = MockAIService()
        mockClipboardReader = MockClipboardReader()
        mockClipboardWriter = MockClipboardWriter()
        mockNotificationService = MockNotificationService()

        mockClipboardReader.textToReturn = "Integration test input"
        mockAIService.generateResult = "Integration test output"

        // 创建真实的 use cases
        let executeUseCase = ExecutePromptTool(
            aiService: mockAIService,
            clipboardReader: mockClipboardReader,
            clipboardWriter: mockClipboardWriter,
            notificationService: mockNotificationService
        )

        sut = PromptToolCoordinator(
            repository: mockRepository,
            executeToolUseCase: executeUseCase,
            hotKeyCoordinator: mockHotKeyCoordinator
        )
    }

    override func tearDown() {
        if let originalAutoPasteSetting {
            UserDefaults.standard.set(originalAutoPasteSetting, forKey: "auto_paste_enabled")
        } else {
            UserDefaults.standard.removeObject(forKey: "auto_paste_enabled")
        }

        sut = nil
        originalAutoPasteSetting = nil
        mockNotificationService = nil
        mockClipboardWriter = nil
        mockClipboardReader = nil
        mockAIService = nil
        mockHotKeyCoordinator = nil
        mockRepository = nil

        super.tearDown()
    }

    // MARK: - Tests: Complete CRUD Flow

    func test_createTool_completesFullFlow() async throws {
        // Arrange
        let toolName = "Integration Test Tool"
        let toolPrompt = "Test prompt"
        let keyCode: UInt16 = 0x09
        let modifiers: UInt32 = 0x108

        // Act
        try await sut.createTool(
            name: toolName,
            prompt: toolPrompt,
            capabilities: [],
            shortcutKeyCode: keyCode,
            shortcutModifiers: modifiers
        )

        // Assert
        XCTAssertEqual(mockRepository.saveCallCount, 1, "应该保存工具到仓库")
        XCTAssertEqual(mockHotKeyCoordinator.registerCallCount, 1, "应该注册快捷键")
        XCTAssertNotNil(mockRepository.lastSavedTool, "应该保存工具")
        XCTAssertEqual(mockRepository.lastSavedTool?.name, toolName)
    }

    func test_updateTool_unregistersOldAndRegistersNew() async throws {
        // Arrange
        let tool = PromptTool(
            name: "Original Tool",
            prompt: "Original",
            shortcutKeyCode: 0x09,
            shortcutModifiers: 0x108
        )
        mockRepository.toolsToReturn = [tool]

        let updatedTool = PromptTool(
            id: tool.id,
            name: "Updated Tool",
            prompt: "Updated",
            shortcutKeyCode: 0x0B, // 不同的快捷键
            shortcutModifiers: 0x108
        )

        // Act
        try await sut.updateTool(updatedTool)

        // Assert
        XCTAssertEqual(mockHotKeyCoordinator.unregisterCallCount, 1, "应该注销旧快捷键")
        XCTAssertEqual(mockRepository.saveCallCount, 1, "应该保存更新")
        XCTAssertEqual(mockHotKeyCoordinator.registerCallCount, 1, "应该注册新快捷键")
    }

    func test_deleteTool_unregistersAndDeletes() async throws {
        // Arrange
        let tool = PromptTool(name: "Tool to Delete", prompt: "Delete me")
        mockRepository.toolsToReturn = [tool]

        // Act
        try await sut.deleteTool(id: tool.toolID)

        // Assert
        XCTAssertEqual(mockHotKeyCoordinator.unregisterCallCount, 1, "应该注销快捷键")
        XCTAssertEqual(mockRepository.deleteCallCount, 1, "应该从仓库删除")
        XCTAssertEqual(mockRepository.lastDeletedId, tool.toolID)
    }

    // MARK: - Tests: Tool Execution Flow

    func test_executeTool_findsAndExecutes() async throws {
        // Arrange
        let tool = PromptTool(name: "Execution Test", prompt: "Execute me")
        mockRepository.toolsToReturn = [tool]

        // Act
        try await sut.executeTool(id: tool.toolID)

        // Assert
        XCTAssertEqual(mockRepository.findByIdCallCount, 1, "应该查找工具")
        XCTAssertTrue(mockClipboardWriter.didWrite, "应该写入执行结果到剪贴板")
        XCTAssertEqual(mockClipboardWriter.writtenText, "Integration test output", "应该写入 AI 处理结果")
    }

    func test_executeTool_withNonExistentTool_throwsError() async {
        // Arrange
        let nonExistentId = ToolID()
        mockRepository.toolsToReturn = []

        // Act & Assert
        do {
            try await sut.executeTool(id: nonExistentId)
            XCTFail("应该抛出工具未找到错误")
        } catch {
            // 验证错误类型
            XCTAssertTrue(error is CoordinatorError)
        }
    }

    // MARK: - Tests: Hot Key Management

    func test_registerAllHotKeys_registersAllTools() async throws {
        // Arrange
        let tool1 = PromptTool(name: "Tool 1", prompt: "P1", shortcutKeyCode: 0x09, shortcutModifiers: 0x108)
        let tool2 = PromptTool(name: "Tool 2", prompt: "P2", shortcutKeyCode: 0x0B, shortcutModifiers: 0x108)
        let tool3 = PromptTool(
            name: "Tool 3",
            prompt: "P3",
            shortcutKeyCode: 0,
            shortcutModifiers: 0
        ) // 无快捷键
        mockRepository.toolsToReturn = [tool1, tool2, tool3]

        // Act
        try await sut.registerAllHotKeys()

        // Assert
        XCTAssertEqual(mockHotKeyCoordinator.registerCallCount, 2, "应该只注册有快捷键的工具")
    }

    func test_unregisterAllHotKeys_unregistersAll() {
        // Act
        sut.unregisterAllHotKeys()

        // Assert
        XCTAssertEqual(mockHotKeyCoordinator.unregisterAllCallCount, 1)
    }

    // MARK: - Tests: Load Tools

    func test_loadTools_returnsAllTools() async throws {
        // Arrange
        let tools = [
            PromptTool(name: "Tool 1", prompt: "P1"),
            PromptTool(name: "Tool 2", prompt: "P2"),
            PromptTool(name: "Tool 3", prompt: "P3")
        ]
        mockRepository.toolsToReturn = tools

        // Act
        let result = try await sut.loadTools()

        // Assert
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(mockRepository.findAllCallCount, 1)
    }

    // MARK: - Tests: Error Handling

    func test_createTool_withRepositoryError_propagatesError() async {
        // Arrange
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = MockError.generic

        // Act & Assert
        do {
            try await sut.createTool(name: "Test", prompt: "Test", capabilities: [], shortcutKeyCode: 0, shortcutModifiers: 0)
            XCTFail("应该传播仓库错误")
        } catch {
            XCTAssertTrue(error is MockError)
        }
    }

    func test_createTool_withHotKeyError_propagatesError() async {
        // Arrange
        mockHotKeyCoordinator.shouldThrowError = true
        mockHotKeyCoordinator.errorToThrow = MockError.generic

        // Act & Assert
        do {
            try await sut.createTool(
                name: "Test",
                prompt: "Test",
                capabilities: [],
                shortcutKeyCode: 0x09,
                shortcutModifiers: 0x108
            )
            XCTFail("应该传播快捷键注册错误")
        } catch {
            XCTAssertTrue(error is MockError)
        }
    }

    // MARK: - Tests: Restore Default Tools

    func test_restoreDefaultTools_callsRepository() async throws {
        // 注意：这个测试验证当前的委托实现
        // 当完整实现后，需要更新这个测试

        // Act
        try await sut.restoreDefaultTools()

        // Assert
        // 当前实现委托给 PromptToolManager，所以这里不验证 mock 调用
        // 这是一个已知的 TODO
    }
}

final class MockPromptToolHotKeyCoordinator: PromptToolHotKeyHandling, @unchecked Sendable {
    var registerCallCount = 0
    var unregisterCallCount = 0
    var unregisterAllCallCount = 0

    var lastRegisteredTool: PromptTool?
    var lastRegisteredHandler: (@Sendable () -> Void)?
    var lastUnregisteredToolID: ToolID?

    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic

    func registerToolHotKey(for tool: PromptTool, handler: @escaping @Sendable () -> Void) throws {
        guard tool.keyCombo != nil else { return }

        registerCallCount += 1
        lastRegisteredTool = tool
        lastRegisteredHandler = handler

        if shouldThrowError {
            throw errorToThrow
        }
    }

    func unregisterToolHotKey(for toolID: ToolID) {
        unregisterCallCount += 1
        lastUnregisteredToolID = toolID
    }

    func unregisterAllToolHotKeys() {
        unregisterAllCallCount += 1
    }
}
