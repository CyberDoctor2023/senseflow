//
//  UnifiedPanelView.swift
//  SenseFlow
//
//  Created on 2026-02-11.
//

import SwiftUI

/// 统一面板视图：整个窗口的根容器
///
/// 架构层级：
/// NSPanel（整个窗口/大背景）
/// └── UnifiedPanelView（SwiftUI根容器）
///     └── VStack
///         ├── EmptyBackgroundView（顶部搜索栏，高度50pt）
///         ├── Color.clear（透明间隔，高度4pt）
///         └── ClipboardListView（主容器/卡片列表区域）
///
/// 解决双窗口架构下 Liquid Glass 焦点问题：
/// macOS 只允许一个 key window，非 key window 的 `.glassEffect()` 会降级。
/// 合并为单窗口后，两个玻璃区域共享同一个 key window 状态，都保持活跃。
struct UnifiedPanelView: View {

    @ObservedObject var viewModel: ClipboardListViewModel

    let mainContainerConfig: MainContainerLayoutConfig  // 主容器配置
    let cardConfig: CardAreaLayoutConfig                // 卡片区域配置
    let topConfig: TopBackgroundLayoutConfig            // 顶部搜索栏配置

    var onItemSelected: ((ClipboardItem) -> Void)?

    @State private var isSearchBarExpanded: Bool = false  // 控制搜索栏展开状态

    var body: some View {
        VStack(spacing: 0) {
            // 顶部搜索栏区域（EmptyBackgroundView）
            // 用 ZStack 预留空间，但不裁剪内容
            ZStack {
                Color.clear
                    .frame(height: topConfig.windowHeight)  // 占位，预留空间
                EmptyBackgroundView(viewModel: viewModel, isExpanded: $isSearchBarExpanded)
                    // 不施加 frame 约束，让 glassEffect 自由渲染阴影
            }

            // 透明间隔（点击穿透）
            // 高度：topConfig.gapFromMainWindow (4pt)
            Color.clear
                .frame(height: topConfig.gapFromMainWindow)
                .allowsHitTesting(false)

            // 主容器/卡片列表区域（ClipboardListView）
            // 高度：由 mainContainerConfig 和 cardConfig 计算
            ClipboardListView(
                viewModel: viewModel,
                mainContainerConfig: mainContainerConfig,
                cardConfig: cardConfig,
                onItemSelected: onItemSelected
            )
        }
        // 给 glass 阴影预留透明溢出区，避免被窗口边界裁剪
        .padding(.horizontal, Constants.ClipboardWindow.shadowBleedHorizontal)
        .padding(.top, Constants.ClipboardWindow.shadowBleedTop)
        .padding(.bottom, Constants.ClipboardWindow.shadowBleedBottom)
        .containerBackground(.clear, for: .window)  // 窗口级背景透明
        .environment(\.appearsActive, true)  // 强制始终显示活跃外观，避免焦点切换卡顿
        .onReceive(NotificationCenter.default.publisher(for: .windowWillShow)) { _ in
            // 窗口即将显示：统一处理所有子视图的初始化

            // 1. 重置搜索栏状态并触发展开动画
            isSearchBarExpanded = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation {
                    isSearchBarExpanded = true
                }
            }

            // 2. 清空搜索查询
            viewModel.searchQuery = ""

            // 3. 重新加载数据
            Task {
                await viewModel.loadItems()
            }
        }
    }
}
