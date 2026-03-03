//
//  WindowLayoutConfig.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//

import Foundation
import CoreGraphics
import AppKit

/// 窗口布局配置（统一接口）
/// 聚合所有窗口布局相关的配置，提供统一的访问入口
struct WindowLayoutConfig: WindowLayoutConfigurable {

    // MARK: - Sub-Configurations

    /// 主容器配置（卡片列表区域）
    let mainContainer: MainContainerLayoutConfig

    /// 卡片区域配置
    let cardArea: CardAreaLayoutConfig

    /// 顶部搜索栏配置
    let topBackground: TopBackgroundLayoutConfig

    // MARK: - Convenience Methods

    /// 计算主容器的完整 frame
    func calculateMainWindowFrame(for screen: NSScreen) -> NSRect {
        return mainContainer.calculateWindowFrame(for: screen, cardConfig: cardArea)
    }

    /// 计算顶部窗口的完整 frame（相对于主窗口）
    func calculateTopWindowFrame(mainWindowFrame: NSRect) -> NSRect {
        return topBackground.calculateWindowFrame(mainWindowFrame: mainWindowFrame)
    }

    // MARK: - Default Configuration

    /// 默认配置
    static let `default` = WindowLayoutConfig(
        mainContainer: .default,
        cardArea: .default,
        topBackground: .default
    )
}
