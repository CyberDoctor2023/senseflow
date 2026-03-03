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
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: size))
            // 颜色：未钉=灰色，已钉=深色，hover=更亮
            .foregroundStyle(foregroundColor)
            // 旋转角度：未钉=45°斜向，已钉=0°垂直
            .rotationEffect(.degrees(isPinned ? 0 : 45))
            // Hover: 轻微上移（"拔起来"）
            .offset(y: isHovered && !isPinned ? -2 : 0)
            // Hover: 轻微放大
            .scaleEffect(isHovered ? 1.15 : 1.0)
            // "钉下去"的动画
            .scaleEffect(isAnimating ? 0.8 : 1.0)
            .rotationEffect(.degrees(isAnimating ? -15 : 0))
            // 流畅的动画
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPinned)
            // Hover 检测
            .onHover { hovering in
                isHovered = hovering
            }
            // "钉下去"动画触发
            .onChange(of: isPinned) { newValue in
                if newValue {
                    // 钉下去：快速旋转 + 缩小
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        isAnimating = true
                    }
                    // 回弹
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isAnimating = false
                        }
                    }
                }
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
