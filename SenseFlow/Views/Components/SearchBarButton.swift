//
//  SearchBarButton.swift
//  SenseFlow
//
//  Created on 2026-02-10.
//

import SwiftUI

/// 搜索栏圆形按钮组件
struct SearchBarButton: View, Identifiable {

    // MARK: - Properties

    /// 按钮唯一标识符（用于动画）
    let id: String

    /// SF Symbol 图标名称
    let icon: String

    /// 配置对象
    var config: SearchBarConfig

    /// 按钮动作
    let action: () -> Void

    // MARK: - State

    @State private var isHovering: Bool = false

    // MARK: - Body

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: config.iconSize))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: config.buttonSize, height: config.buttonSize)
                .background(config.material, in: Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.08 : 1.0)
        .animation(.snappy(duration: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Convenience Initializers

extension SearchBarButton {
    /// 使用默认配置创建按钮（ID 从图标名称生成）
    init(icon: String, action: @escaping () -> Void) {
        self.id = "button-\(icon)"
        self.icon = icon
        self.config = .default
        self.action = action
    }
}
