//
//  DesignSystem.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//  统一的设计系统常量
//

import Foundation

/// 设计系统 - 全局设计规范
enum DesignSystem {
    /// 间距系统
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    /// 字体大小
    enum FontSize {
        static let caption: CGFloat = 10
        static let small: CGFloat = 11
        static let body: CGFloat = 13
        static let bodyLarge: CGFloat = 14
        static let title: CGFloat = 16
        static let largeTitle: CGFloat = 24
    }

    /// 圆角半径
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }

    /// 边框宽度
    enum BorderWidth {
        static let thin: CGFloat = 1
        static let regular: CGFloat = 2
    }

    /// 窗口尺寸
    enum WindowSize {
        struct Size {
            let width: CGFloat
            let height: CGFloat
        }

        static let settingsWindow = Size(width: 600, height: 400)
    }

    /// 屏幕边距（浮动窗口与屏幕边缘的距离）
    enum ScreenInsets {
        static let horizontal: CGFloat = 6  // 左右边距
        static let bottom: CGFloat = 6      // 底部边距
    }

    /// 文本编辑器
    enum TextEditor {
        static let height: CGFloat = 100
    }
}
