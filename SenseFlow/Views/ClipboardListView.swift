//
//  ClipboardListView.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import SwiftUI
import Combine

/// 剪贴板列表视图（横向滚动）
///
/// 在窗口架构中的位置：
/// NSPanel（整个窗口/大背景）
/// └── UnifiedPanelView
///     └── VStack
///         ├── EmptyBackgroundView（顶部搜索栏，50pt）
///         ├── Color.clear（透明间隔，4pt）
///         └── ClipboardListView（主容器/卡片列表区域）← 此视图
///
/// 职责：显示剪贴板历史记录卡片的横向滚动列表
struct ClipboardListView: View {

    @ObservedObject var viewModel: ClipboardListViewModel  // 使用 DI 注入的 ViewModel

    var onItemSelected: ((ClipboardItem) -> Void)?

    // 布局配置（通过 DI 注入）
    var mainContainerConfig: MainContainerLayoutConfig
    var cardConfig: CardAreaLayoutConfig

    // 初始化器（接受注入的 ViewModel 和布局配置）
    init(
        viewModel: ClipboardListViewModel,
        mainContainerConfig: MainContainerLayoutConfig = .default,
        cardConfig: CardAreaLayoutConfig = .default,
        onItemSelected: ((ClipboardItem) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.mainContainerConfig = mainContainerConfig
        self.cardConfig = cardConfig
        self.onItemSelected = onItemSelected
    }

    var body: some View {
        // 直接在内容上应用 glassEffect，而不是分离的背景层
        VStack(spacing: 0) {
            // Card scroll area
            if viewModel.items.isEmpty {
                // Empty state
                VStack(spacing: Constants.EmptyState.spacing) {
                    Image(systemName: viewModel.searchQuery.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: Constants.EmptyState.iconFontSize))
                        .foregroundStyle(.secondary)

                    Text(viewModel.searchQuery.isEmpty ? "暂无历史记录" : "未找到匹配结果")
                        .font(.system(size: Constants.EmptyState.titleFontSize))
                        .foregroundStyle(.secondary)

                    if !viewModel.searchQuery.isEmpty {
                        Text("试试其他关键词")
                            .font(.system(size: Constants.EmptyState.subtitleFontSize))
                            .foregroundStyle(.secondary.opacity(Constants.opacity70))
                    } else {
                        Text("复制任意内容后会自动保存")
                            .font(.system(size: Constants.EmptyState.descriptionFontSize))
                            .foregroundStyle(.secondary.opacity(Constants.opacity80))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
                .animation(.snappy(duration: Constants.snappyAnimationDuration), value: viewModel.items.isEmpty)

            } else {
                // Horizontal scrolling list
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: cardConfig.cardSpacing) {
                            // 左边距占位符（Apple 官方推荐方式）
                            Spacer()
                                .frame(width: cardConfig.backgroundLeftOffset)
                                .id("leading-spacer")

                            ForEach(viewModel.items) { item in
                                ClipboardCardView(item: item) {
                                    handleItemSelection(item)
                                }
                                .id(item.id)
                            }

                            // 右边距占位符
                            Spacer()
                                .frame(width: cardConfig.backgroundRightOffset)
                        }
                        .padding(.top, cardConfig.backgroundTopOffset)
                        .padding(.bottom, cardConfig.backgroundBottomOffset)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .windowWillShow)) { _ in
                        // 重置滚动位置到最左边（滚动到左边距占位符）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.snappy(duration: 0.2)) {
                                proxy.scrollTo("leading-spacer", anchor: .leading)
                            }
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        // 在内容上直接应用 glassEffect，而不是分离的背景层
        .compatibleGlassEffect(cornerRadius: mainContainerConfig.cornerRadius)
        .task {
            await viewModel.loadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardDidUpdate)) { _ in
            if viewModel.searchQuery.isEmpty {
                Task {
                    await viewModel.loadItems()
                }
            }
        }
    }

    // MARK: - Actions

    private func handleItemSelection(_ item: ClipboardItem) {
        ClipboardMonitor.shared.ignoreNextChange()
        writeItemToClipboard(item)
        hideWindowAndPaste()
    }

    /// 将项目写入剪贴板
    private func writeItemToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            writeTextToClipboard(item, pasteboard: pasteboard)
        case .image:
            writeImageToClipboard(item, pasteboard: pasteboard)
        }
    }

    /// 写入文本到剪贴板
    private func writeTextToClipboard(_ item: ClipboardItem, pasteboard: NSPasteboard) {
        if let text = item.textContent {
            pasteboard.setString(text, forType: .string)
        }
    }

    /// 写入图片到剪贴板
    private func writeImageToClipboard(_ item: ClipboardItem, pasteboard: NSPasteboard) {
        // 使用图片缓存避免重复的磁盘 I/O
        if let image = ClipboardImageCache.shared.image(for: item) {
            pasteboard.writeObjects([image])
        }
    }

    /// 隐藏窗口并执行自动粘贴
    private func hideWindowAndPaste() {
        FloatingWindowManager.shared.hideWindowImmediately()
        AutoPasteManager.shared.performAutoPaste(delay: 0.5)
    }
}
