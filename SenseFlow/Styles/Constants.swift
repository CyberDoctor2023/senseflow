//
//  Constants.swift
//  SenseFlow
//
//  Created on 2026-02-03.
//  Style constants aligned with Apple's Landmarks Liquid Glass design patterns.
//

import SwiftUI

/// Design constants and style parameters - Aligned with Apple Landmarks patterns
struct Constants {
    // MARK: - Window and Container Constants

    /// Clipboard list window - floating panel with Liquid Glass
    struct ClipboardWindow {
        static let minWidth: CGFloat = 320
        static let minHeight: CGFloat = 280
        static let maxWidth: CGFloat = 1200
        static let defaultWidth: CGFloat = 700
        static let defaultHeight: CGFloat = 400
        static let cornerRadius: CGFloat = 20

        // 给玻璃阴影预留外扩空间，避免被窗口边界裁切
        static let shadowBleedHorizontal: CGFloat = 10
        static let shadowBleedTop: CGFloat = 10
        static let shadowBleedBottom: CGFloat = 10
        static let totalHorizontalBleed: CGFloat = shadowBleedHorizontal * 2
        static let totalVerticalBleed: CGFloat = shadowBleedTop + shadowBleedBottom
    }

    /// Settings window dimensions
    struct SettingsWindow {
        static let minWidth: CGFloat = 600
        static let minHeight: CGFloat = 500
        static let defaultWidth: CGFloat = 850
        static let defaultHeight: CGFloat = 500
        static let cornerRadius: CGFloat = 20
    }

    // MARK: - Spacing Constants

    /// Standard spacing values for layout
    static let spacing4: CGFloat = 4
    static let spacing6: CGFloat = 6
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing14: CGFloat = 14
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing26: CGFloat = 26
    static let spacing30: CGFloat = 30
    static let spacing32: CGFloat = 32

    // Standard padding (alias for spacing)
    static let standardPadding: CGFloat = 14
    static let leadingContentInset: CGFloat = 26

    // MARK: - Clipboard Card Constants

    /// Card dimensions (180×180pt square, per v0.2.1 spec)
    struct Card {
        static let width: CGFloat = 180
        static let height: CGFloat = 180
        static let size: CGSize = CGSize(width: 180, height: 180)

        /// Corner radius - 20pt Liquid Glass style
        static let cornerRadius: CGFloat = 20

        /// Internal padding
        static let paddingHorizontal: CGFloat = 12
        static let paddingTop: CGFloat = 12
        static let paddingBottom: CGFloat = 8

        /// Content spacing
        static let contentSpacing: CGFloat = 8

        /// Metadata bar spacing
        static let metadataSpacing: CGFloat = 6
        static let iconSize: CGFloat = 14
        static let fontSize: CGFloat = 10

        /// Top indicator bar height
        static let indicatorHeight: CGFloat = 3

        /// Delete button and content
        static let deleteButtonSize: CGFloat = 20
        static let textMaxHeight: CGFloat = 140
        static let imageMaxHeight: CGFloat = 120
    }

    // MARK: - Corner Radii

    /// Corner radius values following Landmarks pattern
    static let cornerRadius: CGFloat = 15
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 20

    // MARK: - Material and Shadow Constants

    /// Shadow properties for cards and containers
    struct Shadow {
        static let color: Color = Color.black
        static let opacity: CGFloat = 0.10  // 10% black opacity
        static let radius: CGFloat = 6  // 减少阴影半径以提升性能
        static let offsetX: CGFloat = 0
        static let offsetY: CGFloat = 2
    }

    /// Glass effect transparency layers (Liquid Glass)
    struct GlassEffect {
        static let separatorTopOpacity: CGFloat = 0.08    // White separator
        static let separatorBottomOpacity: CGFloat = 0.12  // Black separator
        static let glassBackgroundOpacity: CGFloat = 0.08  // Glass background
    }

    // MARK: - Opacity Constants

    /// Opacity values for transparency effects
    static let opacity10: CGFloat = 0.1
    static let opacity20: CGFloat = 0.2
    static let opacity30: CGFloat = 0.3
    static let opacity70: CGFloat = 0.7
    static let opacity80: CGFloat = 0.8
    static let opacity90: CGFloat = 0.9

    // MARK: - Animation Constants

    /// Snappy animation for interactive elements
    static let snappyAnimationDuration: CGFloat = 0.25
    static let snappyAnimationBounce: CGFloat = 0.05  // 轻微回弹，让动画更自然

    /// Scale effect for hover states
    static let hoverScaleSmall: CGFloat = 1.05
    static let hoverScaleLarge: CGFloat = 1.10

    /// Scale effect for pressed/active states
    static let scalePressed: CGFloat = 0.95
    static let scaleSmall: CGFloat = 0.8
    static let scaleTiny: CGFloat = 0.7

    // MARK: - Dialog Window Constants

    struct DialogWindow {
        static let onboarding: CGSize = CGSize(width: 550, height: 500)
        static let settingsWindow: CGSize = CGSize(width: 500, height: 350)
        static let settingsForm: CGSize = CGSize(width: 500, height: 400)
        static let promptToolEditor: CGSize = CGSize(width: 500, height: 450)
        static let smartRecommendation: CGSize = CGSize(width: 400, height: 300)
        static let communityBrowser: CGSize = CGSize(width: 800, height: 600)
        static let hotKeyRecorder: CGFloat = 400
    }

    // MARK: - Search Bar Constants

    struct SearchBar {
        // Layout
        static let height: CGFloat = 36
        static let minWidth: CGFloat = 200
        static let maxWidth: CGFloat = 600

        // Spacing
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let componentSpacing: CGFloat = 8
        static let buttonSpacing: CGFloat = 6

        // Animation
        static let morphingSpacing: CGFloat = 40
        static let transitionDuration: TimeInterval = 0.35

        // Style
        static let fontSize: CGFloat = 14
        static let iconSize: CGFloat = 16
        static let buttonSize: CGFloat = 36
    }

    // MARK: - Empty State Constants

    struct EmptyState {
        static let iconFontSize: CGFloat = 48
        static let titleFontSize: CGFloat = 16
        static let subtitleFontSize: CGFloat = 12
        static let descriptionFontSize: CGFloat = 13
        static let spacing: CGFloat = 12
    }

    // MARK: - Settings Form Constants

    struct SettingsForm {
        /// Settings panel sidebar minimum width
        static let sidebarMinWidth: CGFloat = 150
        static let sidebarMaxWidth: CGFloat = 400
        static let sidebarIdealWidth: CGFloat = 200

        /// Form styling
        static let formCornerRadius: CGFloat = 20
        static let sectionSpacing: CGFloat = 12
    }

    // MARK: - PromptTools Editor Constants

    struct PromptToolsEditor {
        static let tagPaddingHorizontal: CGFloat = 4
        static let tagPaddingVertical: CGFloat = 2
        static let tagCornerRadius: CGFloat = 4
        static let tagFontSize: CGFloat = 11
        static let tagSpacing: CGFloat = 4
        static let editorTopPadding: CGFloat = 12
        static let fieldWidth: CGFloat = 100
        static let fieldMinWidth: CGFloat = 120
    }

    // MARK: - Typography Constants

    struct Typography {
        /// Font sizes
        static let smallCaption: CGFloat = 10
        static let caption: CGFloat = 12
        static let body: CGFloat = 14
        static let subtitle: CGFloat = 16
        static let title: CGFloat = 18
    }

    // MARK: - Additional Component Constants

    struct SettingsIcon {
        static let size: CGFloat = 22
        static let cornerRadius: CGFloat = 6
        static let iconFontSize: CGFloat = 13
        static let shadowRadius: CGFloat = 1
    }

    struct TextEditor {
        static let height: CGFloat = 100
        static let minHeight: CGFloat = 150
    }

    struct Onboarding {
        static let iconSize: CGFloat = 32
        static let topPadding: CGFloat = 32
        static let bottomPadding: CGFloat = 24
        static let horizontalPadding: CGFloat = 32
    }

    // MARK: - Border and Stroke Constants

    static let borderWidth1: CGFloat = 1
    static let borderWidth2: CGFloat = 2
}
