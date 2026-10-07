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

    /// One logical-point inset shared by all four sides of the history surface.
    var contentInset: CGFloat

    // MARK: - Card Layout

    /// 卡片高度
    var cardHeight: CGFloat

    /// 卡片之间的间距
    var cardSpacing: CGFloat

    // MARK: - Default Configuration

    /// 默认配置
    static let `default` = CardAreaLayoutConfig(
        contentInset: 28,           // 四边统一内边距，不随显示器分辨率缩放
        cardHeight: Constants.Card.height, // 与实际渲染卡片共用高度
        cardSpacing: 16              // 卡片间距16pt
    )
}
