//
//  WindowFactory.swift
//  SenseFlow
//
//  Created on 2026-02-11.
//

import Cocoa
import SwiftUI
import SwiftUI

/// 窗口工厂：负责创建和初始化窗口
///
/// 架构层级：
/// NSPanel（整个窗口/大背景）
/// └── UnifiedPanelView（SwiftUI根容器）
///     └── VStack
///         ├── EmptyBackgroundView（顶部搜索栏，高度50pt）
///         ├── Color.clear（透明间隔，高度4pt）
///         └── ClipboardListView（主容器/卡片列表区域）
///
/// 职责：创建完整配置的 NSPanel（包括内容视图）
///
/// 关键计算：
/// 整个窗口高度 = topHeight + gap + cardAreaHeight
/// - topHeight: 顶部搜索栏高度（50pt）
/// - gap: 透明间隔高度（4pt）
/// - cardAreaHeight: 主容器高度（由卡片配置计算）
final class WindowFactory {

    private let layoutConfig: WindowLayoutConfigurable
    private let repository: ClipboardRepositoryProtocol

    init(
        layoutConfig: WindowLayoutConfigurable,
        repository: ClipboardRepositoryProtocol
    ) {
        self.layoutConfig = layoutConfig
        self.repository = repository
    }

    /// 创建窗口池（A 和 B 两个窗口）
    func createWindowPair(
        sharedViewModel: ClipboardListViewModel,
        onItemSelected: @escaping (ClipboardItem) -> Void
    ) -> (windowA: NSPanel, windowB: NSPanel) {
        let windowA = createWindow(
            sharedViewModel: sharedViewModel,
            onItemSelected: onItemSelected
        )
        let windowB = createWindow(
            sharedViewModel: sharedViewModel,
            onItemSelected: onItemSelected
        )
        return (windowA, windowB)
    }

    /// 创建单个窗口（完整配置，包括 contentView）
    private func createWindow(
        sharedViewModel: ClipboardListViewModel,
        onItemSelected: @escaping (ClipboardItem) -> Void
    ) -> NSPanel {
        let contentView = createContentView(
            viewModel: sharedViewModel,
            onItemSelected: onItemSelected
        )
        let hostingView = NSHostingView(rootView: contentView)

        // 关键：禁用 NSHostingView 的内容裁剪，允许 glassEffect 阴影溢出
        hostingView.clipsToBounds = false

        let panel = createPanel()
        panel.contentView = hostingView
        return panel
    }

    /// 创建 SwiftUI 内容视图
    private func createContentView(
        viewModel: ClipboardListViewModel,
        onItemSelected: @escaping (ClipboardItem) -> Void
    ) -> UnifiedPanelView {
        return UnifiedPanelView(
            viewModel: viewModel,
            mainContainerConfig: layoutConfig.mainContainer,
            cardConfig: layoutConfig.cardArea,
            topConfig: layoutConfig.topBackground,
            onItemSelected: onItemSelected
        )
    }

    /// 创建 NSPanel
    private func createPanel() -> KeyboardAcceptingPanel {
        let size = calculateWindowSize()
        return KeyboardAcceptingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    /// 计算窗口尺寸
    private func calculateWindowSize() -> NSSize {
        guard let screen = NSScreen.main else {
            return NSSize(
                width: layoutConfig.unifiedWindowWidth(for: 800),
                height: layoutConfig.unifiedWindowHeight
            )
        }
        let width = layoutConfig.unifiedWindowWidth(for: screen.frame.width)
        return NSSize(width: width, height: layoutConfig.unifiedWindowHeight)
    }
}
