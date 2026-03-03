//
//  CardAreaLayoutConfig.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//

import Foundation
import CoreGraphics

/// 卡片区域布局配置
/// 控制卡片区域相对于大背景的位置和布局
struct CardAreaLayoutConfig {

    // MARK: - Background Offset

    /// 相对于背景顶部的偏移（内边距）
    var backgroundTopOffset: CGFloat

    /// 相对于背景底部的偏移（内边距）
    var backgroundBottomOffset: CGFloat

    /// 相对于背景左侧的偏移（内边距）
    var backgroundLeftOffset: CGFloat

    /// 相对于背景右侧的偏移（内边距）
    var backgroundRightOffset: CGFloat

    // MARK: - Card Layout

    /// 卡片高度
    var cardHeight: CGFloat

    /// 卡片之间的间距
    var cardSpacing: CGFloat

    // MARK: - Default Configuration

    /// 默认配置
    static let `default` = CardAreaLayoutConfig(
        backgroundTopOffset: 12,     // 距离背景顶部12pt
        backgroundBottomOffset: 12,  // 距离背景底部12pt
        backgroundLeftOffset: 12,    // 距离背景左侧12pt
        backgroundRightOffset: 12,   // 距离背景右侧12pt
        cardHeight: 216,             // 卡片高度
        cardSpacing: 16              // 卡片间距16pt
    )
}
