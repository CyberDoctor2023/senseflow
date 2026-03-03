//
//  RegisterToolHotKeyTests.swift
//  SenseFlowTests
//
//  Created on 2026-02-03.
//

import XCTest
@testable import SenseFlow

final class RegisterToolHotKeyTests: XCTestCase {

    // MARK: - Properties

    var mockRegistry: MockHotKeyRegistry!
    var sut: RegisterToolHotKey!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        mockRegistry = MockHotKeyRegistry()
        sut = RegisterToolHotKey(hotKeyRegistry: mockRegistry)
    }

    override func tearDown() {
        sut = nil
        mockRegistry = nil

        super.tearDown()
    }

    // MARK: - Tests: Registration

    func test_register_withValidTool_registersHotKey() throws {
        // Arrange
        let tool = PromptTool(
            name: "Test Tool",
            prompt: "Test Prompt",
            shortcutKeyCode: 0x09, // V key
            shortcutModifiers: 0x108 // Cmd+Ctrl
        )
        var handlerCalled = false
        let handler: @Sendable () -> Void = { handlerCalled = true }

        // Act
        try sut.register(tool: tool, handler: handler)

        // Assert
        XCTAssertEqual(mockRegistry.registerCallCount, 1, "应该调用注册方法一次")
        XCTAssertEqual(mockRegistry.lastRegisteredToolID, tool.toolID, "应该注册正确的工具 ID")
        XCTAssertNotNil(mockRegistry.lastRegisteredCombo, "应该传递快捷键组合")
    }

    func test_register_withToolWithoutHotKey_doesNotRegister() throws {
        // Arrange
        let tool = PromptTool(
            name: "No HotKey Tool",
            prompt: "Prompt",
            shortcutKeyCode: 0, // 无快捷键
            shortcutModifiers: 0
        )
        let handler: @Sendable () -> Void = { }

        // Act
        try sut.register(tool: tool, handler: handler)

        // Assert
        XCTAssertEqual(mockRegistry.registerCallCount, 0, "没有快捷键的工具不应该注册")
    }

    func test_register_withHandler_handlerCanBeCalled() throws {
        // Arrange
        let tool = PromptTool(
            name: "Tool",
            prompt: "Prompt",
            shortcutKeyCode: 0x09,
            shortcutModifiers: 0x108
        )
        var handlerCalled = false
        let handler: @Sendable () -> Void = { handlerCalled = true }

        // Act
        try sut.register(tool: tool, handler: handler)

        // 模拟触发快捷键
        mockRegistry.lastRegisteredHandler?()

        // Assert
        XCTAssertTrue(handlerCalled, "注册的回调应该可以被调用")
    }

    func test_register_withRegistryError_throwsError() {
        // Arrange
        mockRegistry.shouldThrowError = true
        mockRegistry.errorToThrow = MockError.generic

        let tool = PromptTool(
            name: "Tool",
            prompt: "Prompt",
            shortcutKeyCode: 0x09,
            shortcutModifiers: 0x108
        )
        let handler: @Sendable () -> Void = { }

        // Act & Assert
        XCTAssertThrowsError(try sut.register(tool: tool, handler: handler)) { error in
            XCTAssertTrue(error is MockError, "应该传播注册表的错误")
        }
    }

    // MARK: - Tests: Unregistration

    func test_unregister_withToolID_unregistersHotKey() {
        // Arrange
        let toolID = ToolID()

        // Act
        sut.unregister(toolID: toolID)

        // Assert
        XCTAssertEqual(mockRegistry.unregisterCallCount, 1, "应该调用注销方法一次")
        XCTAssertEqual(mockRegistry.lastUnregisteredToolID, toolID, "应该注销正确的工具 ID")
    }

    func test_unregisterAll_unregistersAllHotKeys() {
        // Act
        sut.unregisterAll()

        // Assert
        XCTAssertEqual(mockRegistry.unregisterAllCallCount, 1, "应该调用注销所有方法一次")
    }

    // MARK: - Tests: Multiple Registrations

    func test_register_multipleTools_registersAll() throws {
        // Arrange
        let tool1 = PromptTool(name: "Tool 1", prompt: "P1", shortcutKeyCode: 0x09, shortcutModifiers: 0x108)
        let tool2 = PromptTool(name: "Tool 2", prompt: "P2", shortcutKeyCode: 0x0B, shortcutModifiers: 0x108)
        let handler: @Sendable () -> Void = { }

        // Act
        try sut.register(tool: tool1, handler: handler)
        try sut.register(tool: tool2, handler: handler)

        // Assert
        XCTAssertEqual(mockRegistry.registerCallCount, 2, "应该注册两个工具")
    }
}
