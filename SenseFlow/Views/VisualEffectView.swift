//
//  VisualEffectView.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//  Updated on 2026-01-19 for v0.2.1 Liquid Glass upgrade
//  Updated on 2026-01-30 for backward compatibility (macOS 13+)
//

import SwiftUI
import AppKit

/// SwiftUI Glass Effect Background（macOS 26+ Liquid Glass）
/// 注意：根据 Apple 文档验证，SwiftUI .glassEffect() 只有 .regular 变体
/// 用于主面板背景（需要强毛玻璃效果）
///
/// 已弃用：请使用 View.compatibleGlassEffect() 扩展方法以支持 macOS 13+
@available(macOS 26, *)
struct LiquidGlassBackgroundView: View {

    var body: some View {
        Color.clear
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}
