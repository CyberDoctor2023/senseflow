//
//  PinIconView.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//  使用 SF Symbols 的钉子图标，带专业 hover 效果
//
//  参考：
//  - Apple SF Symbols: pin.fill
//  - Hover 最佳实践: 使用 transform + opacity（硬件加速）
//

import SwiftUI

/// 钉子图标（使用 SF Symbols）
///
/// 设计理念：
/// - 使用系统 SF Symbol: pin.fill
/// - Hover: 轻微上移 + 放大 + 颜色变亮（"拔起来"的感觉）
/// - 未钉: 灰色，45° 斜向
/// - 钉下去: 快速旋转 + 缩放动画
/// - 已钉: 深色，垂直向下（0°）
struct PinIconView: View {
    let isPinned: Bool
    let size: CGFloat

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.pingFang(size: size))
            // 颜色：未钉=灰色，已钉=深色，hover=更亮
            .foregroundStyle(foregroundColor)
            // 旋转角度：未钉=45°斜向，已钉=0°垂直
            .rotationEffect(.degrees(isPinned ? 0 : 45))
            // Hover: 轻微上移（"拔起来"）
            .offset(y: isHovered && !isPinned ? -2 : 0)
            // Hover: 轻微放大
            .scaleEffect(isHovered ? 1.15 : 1.0)
            .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : isPinned)
            .animation(reduceMotion ? nil : .snappy, value: isHovered)
            .animation(reduceMotion ? nil : .snappy, value: isPinned)
            // Hover 检测
            .onHover { hovering in
                isHovered = hovering
            }
            // 扩大点击区域
            .contentShape(Rectangle().inset(by: -8))
    }

    /// 前景色（根据状态变化）
    private var foregroundColor: Color {
        if isHovered {
            return isPinned ? .primary.opacity(0.9) : .secondary.opacity(0.8)
        } else {
            return isPinned ? .primary : .secondary.opacity(0.6)
        }
    }
}
