//
//  MenuBarIconView.swift
//  SenseFlow
//
//  Created on 2026-02-06 for v0.5.0
//  Animated menu bar icon with sliding dots
//

import SwiftUI

/// 菜单栏图标视图 - 备忘录 + 滑动点点动画
struct MenuBarIconView: View {
    @State private var activeIndex: Int = 0
    @State private var isAnimating: Bool = false
    @State private var animationStep: Int = 0

    var body: some View {
        HStack(spacing: 2) {
            // 备忘录图标
            Image(systemName: "note.text")
                .font(.system(size: 14))

            // 三个点点
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(dotColor(for: index))
                        .frame(width: 3, height: 3)
                        .scaleEffect(dotScale(for: index))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardDidUpdate)) { _ in
            triggerAnimation()
        }
    }

    // MARK: - Animation Logic

    /// 触发滑动动画
    private func triggerAnimation() {
        guard !isAnimating else { return }

        isAnimating = true
        activeIndex = 0
        animationStep = 0

        // 循环动画：0 -> 1 -> 2 -> 0 -> 1 -> 2 -> 0（两个完整循环）
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.1)) {
                activeIndex = (activeIndex + 1) % 3
                animationStep += 1
            }

            // 完成两个完整循环后停止（6 步）
            if animationStep >= 6 {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.1)) {
                    activeIndex = 0
                    isAnimating = false
                }
            }
        }
    }

    /// 点点颜色（高亮当前活跃的点）
    private func dotColor(for index: Int) -> Color {
        return index == activeIndex && isAnimating ? .primary : .secondary.opacity(0.5)
    }

    /// 点点缩放（活跃的点稍大）
    private func dotScale(for index: Int) -> CGFloat {
        return index == activeIndex && isAnimating ? 1.3 : 1.0
    }
}

#Preview {
    MenuBarIconView()
        .padding()
}
