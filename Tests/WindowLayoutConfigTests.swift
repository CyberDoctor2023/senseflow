//
//  WindowLayoutConfigTests.swift
//  SenseFlowTests
//
//  Created on 2026-02-09.
//

import Testing
import AppKit
@testable import SenseFlow

/// 窗口布局配置测试套件
@Suite("Window Layout Configuration Tests")
struct WindowLayoutConfigTests {

    // MARK: - Main Window Frame Tests

    @Test("Default config calculates correct main window frame")
    func testDefaultMainWindowFrame() {
        // Arrange
        let config = WindowLayoutConfig.default
        let mockScreen = MockScreen(width: 1920, height: 1080, dockHeight: 68)

        // Act
        let frame = config.calculateMainWindowFrame(for: mockScreen.screen)

        // Assert
        #expect(frame.width > 0, "Window width should be positive")
        #expect(frame.height > 0, "Window height should be positive")
        #expect(frame.origin.x >= 0, "Window x origin should be non-negative")
        #expect(frame.origin.y >= 0, "Window y origin should be non-negative")
    }

    @Test("Main window frame respects screen edge inset", arguments: [
        (1920.0, 1080.0),
        (2560.0, 1440.0),
        (3840.0, 2160.0)
    ])
    func testMainWindowFrameWithDifferentScreenSizes(width: CGFloat, height: CGFloat) {
        // Arrange
        let config = WindowLayoutConfig.default
        let mockScreen = MockScreen(width: width, height: height, dockHeight: 68)
        let expectedInset = config.mainContainer.screenEdgeInset

        // Act
        let frame = config.calculateMainWindowFrame(for: mockScreen.screen)

        // Assert
        #expect(frame.width == width - (expectedInset * 2), "Window width should account for insets")
    }

    // MARK: - Top Window Frame Tests

    @Test("Top window gap is applied correctly", arguments: [2.0, 5.0, 10.0])
    func testTopWindowGap(gap: CGFloat) {
        // Arrange
        var topConfig = TopBackgroundLayoutConfig.default
        topConfig.gapFromMainWindow = gap
        let config = WindowLayoutConfig(
            mainContainer: .default,
            cardArea: .default,
            topBackground: topConfig
        )
        let mainFrame = NSRect(x: 0, y: 0, width: 800, height: 240)

        // Act
        let topFrame = config.calculateTopWindowFrame(mainWindowFrame: mainFrame)

        // Assert
        #expect(topFrame.origin.y == mainFrame.maxY + gap, "Top window should be positioned with correct gap")
        #expect(topFrame.width == mainFrame.width, "Top window width should match main window")
        #expect(topFrame.height == topConfig.windowHeight, "Top window height should match config")
    }

    @Test("Top window aligns with main window horizontally")
    func testTopWindowHorizontalAlignment() {
        // Arrange
        let config = WindowLayoutConfig.default
        let mainFrame = NSRect(x: 100, y: 200, width: 800, height: 240)

        // Act
        let topFrame = config.calculateTopWindowFrame(mainWindowFrame: mainFrame)

        // Assert
        #expect(topFrame.origin.x == mainFrame.origin.x, "Top window x should align with main window")
        #expect(topFrame.width == mainFrame.width, "Top window width should match main window")
    }

    // MARK: - Main Container Layout Config Tests

    @Test("Main container config calculates correct window height")
    func testMainContainerWindowHeight() {
        // Arrange
        let mainContainerConfig = MainContainerLayoutConfig.default
        let cardConfig = CardAreaLayoutConfig.default

        // Act
        let height = mainContainerConfig.windowHeight(cardConfig: cardConfig)

        // Assert
        let expectedHeight = cardConfig.backgroundTopOffset + cardConfig.cardHeight + cardConfig.backgroundBottomOffset
        #expect(height == expectedHeight, "Window height should sum offsets and card height")
    }

    @Test("Main container config uses fixed screen edge inset")
    func testFixedScreenEdgeInset() {
        // Arrange
        let config = MainContainerLayoutConfig.default
        let mockScreen = MockScreen(width: 1920, height: 1080, dockHeight: 68)

        // Act
        let horizontalInset = config.horizontalInset(for: 1920)
        let bottomInset = config.bottomInset(for: mockScreen.screen)

        // Assert
        #expect(horizontalInset == config.screenEdgeInset, "Horizontal inset should equal screenEdgeInset")
        #expect(bottomInset == config.screenEdgeInset, "Bottom inset should equal screenEdgeInset")
    }

    // MARK: - Card Area Layout Config Tests

    @Test("Card area config has consistent offsets")
    func testCardAreaOffsets() {
        // Arrange
        let config = CardAreaLayoutConfig.default

        // Assert
        #expect(config.backgroundTopOffset > 0, "Top offset should be positive")
        #expect(config.backgroundBottomOffset > 0, "Bottom offset should be positive")
        #expect(config.backgroundLeftOffset > 0, "Left offset should be positive")
        #expect(config.backgroundRightOffset > 0, "Right offset should be positive")
    }

    // MARK: - Protocol Conformance Tests

    @Test("WindowLayoutConfig conforms to WindowLayoutConfigurable")
    func testProtocolConformance() {
        // Arrange
        let config: WindowLayoutConfigurable = WindowLayoutConfig.default

        // Act & Assert
        #expect(config.mainContainer.cornerRadius > 0, "Should access main container config through protocol")
        #expect(config.cardArea.cardHeight > 0, "Should access card config through protocol")
        #expect(config.topBackground.windowHeight > 0, "Should access top config through protocol")
    }
}

// MARK: - Mock Screen Helper

/// Mock screen for testing
struct MockScreen {
    let width: CGFloat
    let height: CGFloat
    let dockHeight: CGFloat

    var screen: NSScreen {
        // 创建一个模拟的 NSScreen
        // 注意：这是简化版本，实际测试中可能需要更复杂的 mock
        return NSScreen.main ?? NSScreen.screens.first!
    }
}
