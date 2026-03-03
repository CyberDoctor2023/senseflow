//
//  MockWindowLayoutConfig.swift
//  SenseFlowTests
//
//  Created on 2026-02-09.
//

import Foundation
import CoreGraphics
import AppKit
@testable import SenseFlow

/// Mock 窗口布局配置（用于测试）
/// 提供可预测的固定值，便于测试验证
struct MockWindowLayoutConfig: WindowLayoutConfigurable {

    // MARK: - Properties

    let mainContainer: MainContainerLayoutConfig
    let cardArea: CardAreaLayoutConfig
    let topBackground: TopBackgroundLayoutConfig

    // 可配置的返回值（用于测试不同场景）
    var mockMainWindowFrame: NSRect?
    var mockTopWindowFrame: NSRect?

    // MARK: - Initialization

    init(
        mainContainer: MainContainerLayoutConfig = .default,
        cardArea: CardAreaLayoutConfig = .default,
        topBackground: TopBackgroundLayoutConfig = .default,
        mockMainWindowFrame: NSRect? = nil,
        mockTopWindowFrame: NSRect? = nil
    ) {
        self.mainContainer = mainContainer
        self.cardArea = cardArea
        self.topBackground = topBackground
        self.mockMainWindowFrame = mockMainWindowFrame
        self.mockTopWindowFrame = mockTopWindowFrame
    }

    // MARK: - WindowLayoutConfigurable

    func calculateMainWindowFrame(for screen: NSScreen) -> NSRect {
        // 如果提供了 mock 值，直接返回
        if let mockFrame = mockMainWindowFrame {
            return mockFrame
        }

        // 否则使用真实计算（用于集成测试）
        return mainContainer.calculateWindowFrame(for: screen, cardConfig: cardArea)
    }

    func calculateTopWindowFrame(mainWindowFrame: NSRect) -> NSRect {
        // 如果提供了 mock 值，直接返回
        if let mockFrame = mockTopWindowFrame {
            return mockFrame
        }

        // 否则使用真实计算（用于集成测试）
        return topBackground.calculateWindowFrame(mainWindowFrame: mainWindowFrame)
    }

    // MARK: - Factory Methods

    /// 创建一个固定尺寸的 mock 配置（用于单元测试）
    static func fixed(
        mainFrame: NSRect = NSRect(x: 0, y: 0, width: 800, height: 240),
        topFrame: NSRect = NSRect(x: 0, y: 242, width: 800, height: 100)
    ) -> MockWindowLayoutConfig {
        return MockWindowLayoutConfig(
            mockMainWindowFrame: mainFrame,
            mockTopWindowFrame: topFrame
        )
    }

    /// 创建一个使用真实计算的 mock 配置（用于集成测试）
    static func realistic() -> MockWindowLayoutConfig {
        return MockWindowLayoutConfig()
    }
}
