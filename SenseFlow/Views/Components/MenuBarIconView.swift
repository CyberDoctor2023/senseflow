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
    @State private var animationTrigger: UInt = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            // 备忘录图标
            Image(systemName: "note.text")
                .font(.pingFang(size: 14))

            // 三个点点
            PhaseAnimator([-1, 0, 1, 2, 0, 1, 2], trigger: animationTrigger) { activeIndex in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == activeIndex ? Color.primary : Color.secondary.opacity(0.5))
                            .frame(width: 3, height: 3)
                            .scaleEffect(index == activeIndex ? 1.3 : 1)
                    }
                }
            } animation: { _ in
                .snappy(duration: 0.15)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardDidUpdate)) { _ in
            if !reduceMotion { animationTrigger &+= 1 }
        }
    }
}

#Preview {
    MenuBarIconView()
        .padding()
}
