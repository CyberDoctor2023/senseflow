//
//  TopBackgroundLayoutConfig.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//

import Foundation
import CoreGraphics

/// 顶部搜索栏布局配置
///
/// 在窗口架构中的位置：
/// NSPanel（整个窗口/大背景）
/// └── UnifiedPanelView
///     └── VStack
///         ├── EmptyBackgroundView ← 此配置控制这个区域
///         │   └── 高度：windowHeight (50pt)
///         ├── Color.clear（间隔：gapFromMainWindow 4pt）
///         └── ClipboardListView（主容器）
///
/// 控制顶部搜索栏区域相对于主容器的位置和样式
///
/// ⚠️ 重要：修改 windowHeight 会影响整个窗口的总高度
/// 整个窗口高度 = windowHeight + gapFromMainWindow + 主容器高度
struct TopBackgroundLayoutConfig {

    // MARK: - Position

    /// 相对于主窗口顶部的间距（gap）
    var gapFromMainWindow: CGFloat

    // MARK: - Size

    /// 顶部窗口的高度
    var windowHeight: CGFloat

    // MARK: - Style

    /// 圆角半径
    var cornerRadius: CGFloat

    // MARK: - Computed Properties

    /// 计算顶部窗口的完整 frame（相对于主窗口）
    func calculateWindowFrame(mainWindowFrame: NSRect) -> NSRect {
        return NSRect(
            x: mainWindowFrame.origin.x,
            y: mainWindowFrame.maxY + gapFromMainWindow,
            width: mainWindowFrame.width,
            height: windowHeight
        )
    }

    // MARK: - Default Configuration

    /// 默认配置
    static let `default` = TopBackgroundLayoutConfig(
        gapFromMainWindow: 4,   // 距离主窗口顶部 4pt
        windowHeight: 70,       // 顶部区域高度 70pt（内容36pt + 阴影空间34pt）
        cornerRadius: 25        // 圆角 = 高度/2（完美胶囊形）
    )
}
