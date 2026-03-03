//
//  MainContainerLayoutConfig.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//

import Foundation
import CoreGraphics
import AppKit

/// 主容器布局配置
///
/// 在窗口架构中的位置：
/// NSPanel（整个窗口/大背景）
/// └── UnifiedPanelView
///     └── VStack
///         ├── EmptyBackgroundView（顶部搜索栏，50pt）
///         ├── Color.clear（透明间隔，4pt）
///         └── ClipboardListView（主容器）← 此配置控制这个区域
///
/// 控制主容器（卡片列表区域）相对于屏幕的位置和样式
/// ⚠️ 注意：此配置只控制主容器，不包含顶部搜索栏
struct MainContainerLayoutConfig {

    // MARK: - Screen Position

    /// 屏幕边缘固定边距（与 Dock 底部间距对齐）
    var screenEdgeInset: CGFloat

    // MARK: - Size

    /// 窗口最小宽度
    var windowMinWidth: CGFloat

    /// 窗口最大宽度
    var windowMaxWidth: CGFloat

    // MARK: - Style

    /// 圆角半径
    var cornerRadius: CGFloat

    // MARK: - Computed Properties

    /// 水平边距（固定值）
    func horizontalInset(for screenWidth: CGFloat) -> CGFloat {
        return screenEdgeInset
    }

    /// 底部边距（与水平边距统一）
    func bottomInset(for screen: NSScreen) -> CGFloat {
        return screenEdgeInset
    }

    /// 计算主容器高度（卡片高度 + 上下边距）
    func windowHeight(cardConfig: CardAreaLayoutConfig) -> CGFloat {
        return cardConfig.cardHeight + cardConfig.backgroundTopOffset + cardConfig.backgroundBottomOffset
    }

    /// 计算主容器宽度（屏幕宽度 - 左右边距）
    func windowWidth(for screenWidth: CGFloat) -> CGFloat {
        let horizontalInset = horizontalInset(for: screenWidth)
        return screenWidth - (horizontalInset * 2)
    }

    /// 计算主容器在屏幕上的完整 frame
    func calculateWindowFrame(for screen: NSScreen, cardConfig: CardAreaLayoutConfig) -> NSRect {
        let screenFrame = screen.frame

        let horizontalInset = horizontalInset(for: screenFrame.width)
        let bottomInset = bottomInset(for: screen)
        let width = windowWidth(for: screenFrame.width)
        let height = windowHeight(cardConfig: cardConfig)

        let x = screenFrame.origin.x + horizontalInset
        let y = screenFrame.origin.y + bottomInset

        return NSRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Default Configuration

    /// 默认配置
    static let `default` = MainContainerLayoutConfig(
        screenEdgeInset: 6,       // 距离屏幕边缘固定 6pt
        windowMinWidth: 320,
        windowMaxWidth: 1200,
        cornerRadius: 20
    )
}
