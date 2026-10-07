//
//  SearchBarConfig.swift
//  SenseFlow
//
//  Created on 2026-02-10.
//

import SwiftUI

/// 搜索栏布局和样式配置
struct SearchBarConfig {

    // MARK: - Layout

    /// 搜索栏高度
    var height: CGFloat

    /// 最小宽度
    var minWidth: CGFloat

    /// 最大宽度
    var maxWidth: CGFloat

    // MARK: - Spacing

    /// 搜索框内部水平 padding
    var horizontalPadding: CGFloat

    /// 搜索框内部垂直 padding
    var verticalPadding: CGFloat

    /// 搜索框与按钮组之间的间距
    var componentSpacing: CGFloat

    /// 按钮之间的间距
    var buttonSpacing: CGFloat

    // MARK: - Animation

    /// GlassEffectContainer morphing spacing（控制形状融合距离）
    var morphingSpacing: CGFloat

    /// 过渡动画时长
    var transitionDuration: TimeInterval

    /// 过渡动画类型
    var transitionAnimation: Animation

    // MARK: - Style

    /// Material 背景材质
    var material: Material

    /// 按钮尺寸（圆形按钮的直径）
    var buttonSize: CGFloat

    /// 字体大小
    var fontSize: CGFloat

    /// 图标大小
    var iconSize: CGFloat

    // MARK: - Default Configuration

    /// 默认配置
    static let `default` = SearchBarConfig(
        height: 36,
        minWidth: 200,
        maxWidth: 600,
        horizontalPadding: 12,
        verticalPadding: 8,
        componentSpacing: 8,
        buttonSpacing: 6,
        morphingSpacing: 40,
        transitionDuration: 0.35,
        transitionAnimation: .snappy(duration: 0.35),
        material: .regularMaterial,
        buttonSize: 36,
        fontSize: 14,
        iconSize: 16
    )
}
