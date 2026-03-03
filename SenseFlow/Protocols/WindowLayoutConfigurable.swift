//
//  WindowLayoutConfigurable.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//

import Foundation
import CoreGraphics
import AppKit

/// 窗口布局配置协议
/// 定义窗口布局计算的抽象接口，用于依赖注入和测试隔离
protocol WindowLayoutConfigurable {

    /// 计算主窗口的完整 frame
    /// - Parameter screen: 目标屏幕
    /// - Returns: 主窗口的 frame
    func calculateMainWindowFrame(for screen: NSScreen) -> NSRect

    /// 计算顶部窗口的完整 frame（相对于主窗口）
    /// - Parameter mainWindowFrame: 主窗口的 frame
    /// - Returns: 顶部窗口的 frame
    func calculateTopWindowFrame(mainWindowFrame: NSRect) -> NSRect

    /// 获取主容器配置
    var mainContainer: MainContainerLayoutConfig { get }

    /// 获取卡片区域配置
    var cardArea: CardAreaLayoutConfig { get }

    /// 获取顶部背景配置
    var topBackground: TopBackgroundLayoutConfig { get }
}

// MARK: - Unified Metrics

extension WindowLayoutConfigurable {

    /// 主容器区域高度（卡片区）
    var cardAreaContainerHeight: CGFloat {
        mainContainer.windowHeight(cardConfig: cardArea)
    }

    /// 不含阴影 bleed 的统一内容高度
    var unifiedContentHeight: CGFloat {
        topBackground.windowHeight + topBackground.gapFromMainWindow + cardAreaContainerHeight
    }

    /// 含阴影 bleed 的统一窗口高度
    var unifiedWindowHeight: CGFloat {
        unifiedContentHeight + Constants.ClipboardWindow.totalVerticalBleed
    }

    /// 含阴影 bleed 的统一窗口宽度
    func unifiedWindowWidth(for screenWidth: CGFloat) -> CGFloat {
        let inset = mainContainer.screenEdgeInset
        return screenWidth - (inset * 2) + Constants.ClipboardWindow.totalHorizontalBleed
    }
}
