//
//  EmptyBackgroundView.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//

import SwiftUI

/// 顶部搜索栏视图
///
/// 在窗口架构中的位置：
/// NSPanel（整个窗口/大背景）
/// └── UnifiedPanelView
///     └── VStack
///         ├── EmptyBackgroundView（顶部搜索栏区域）← 此视图
///         ├── Color.clear（透明间隔，4pt）
///         └── ClipboardListView（主容器/卡片列表区域）
///
/// 布局：搜索胶囊（左）+ 3 个提示圆（文本/图片/App）+ 钉子圆（右）
/// 动画：窗口出现时，一条长 bar → 右侧分离出 3 个圆球（GlassEffectContainer morphing）
struct EmptyBackgroundView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: ClipboardListViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var isPinned: Bool = false
    @Binding var isExpanded: Bool  // 由父视图控制
    @State private var hoveredHint: String?
    @Namespace private var glassNamespace

    private let config = SearchBarConfig.default

    private let defaultPlaceholder = "搜索任意"

    private let hints: [(icon: String, text: String)] = [
        ("doc.text", "文本"),
        ("photo", "图片"),
        ("app.badge.checkmark", "应用")
    ]

    /// 容器 spacing 略大于元素间距 → 触发 matchedGeometry 形变
    private let glassSpacing: CGFloat = 10

    /// 元素之间的间距（略小于 glassSpacing）
    private let elementSpacing: CGFloat = 8

    /// 胶囊展开后的宽度
    private let expandedCapsuleWidth: CGFloat = 280

    /// 胶囊收起时的宽度（覆盖圆球占位区域，形成一条完整的 bar）
    private var collapsedCapsuleWidth: CGFloat {
        expandedCapsuleWidth + CGFloat(hints.count) * (config.buttonSize + elementSpacing)
    }

    // MARK: - Computed

    private var currentPlaceholder: String {
        if let hoveredHint,
           let match = hints.first(where: { $0.icon == hoveredHint }) {
            return match.text
        }
        return defaultPlaceholder
    }

    // MARK: - Body

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                glassBody
            } else {
                staticBody
            }
        }
    }

    // MARK: - Glass Body (macOS 26+)

    @available(macOS 26.0, *)
    private var glassBody: some View {
        GlassEffectContainer(spacing: glassSpacing) {
            HStack(spacing: elementSpacing) {
                // 搜索胶囊：左边固定，右边伸缩
                // 收起时覆盖圆球区域（一条完整的 bar）
                // 展开时缩窄，让圆球从右侧分离出来
                searchCapsule
                    .frame(
                        minWidth: config.minWidth,
                        maxWidth: isExpanded ? expandedCapsuleWidth : collapsedCapsuleWidth,
                        alignment: .leading
                    )
                    // 移除固定高度约束，让 glassEffect 自然确定尺寸（包括阴影）
                    // .frame(height: config.height)
                    .glassEffect(.regular, in: .capsule)
                    .glassEffectID("search", in: glassNamespace)

                // 提示圆球：从胶囊右侧分离出来
                if isExpanded {
                    ForEach(Array(hints.enumerated()), id: \.element.icon) { index, hint in
                        hintCircle(icon: hint.icon)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .glassEffectID("hint-\(hint.icon)", in: glassNamespace)
                            .glassEffectTransition(.matchedGeometry)
                    }
                }

                Spacer()

                pinButton
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("pin", in: glassNamespace)
                    .glassEffectTransition(.materialize)
            }
            .frame(maxWidth: .infinity)  // 只约束宽度，让高度自然确定
        }
    }

    // MARK: - Static Body (fallback)

    private var staticBody: some View {
        HStack(spacing: config.componentSpacing) {
            searchCapsule
                .frame(minWidth: config.minWidth, maxWidth: expandedCapsuleWidth, alignment: .leading)
                // 移除固定高度约束，让 material 自然确定尺寸
                // .frame(height: config.height)
                .background(config.material, in: Capsule())

            ForEach(hints, id: \.icon) { hint in
                hintCircle(icon: hint.icon)
                    .background(config.material, in: Circle())
            }

            Spacer()

            pinButton
                .background(config.material, in: Circle())
        }
        .frame(maxWidth: .infinity)  // 只约束宽度，让高度自然确定
    }

    // MARK: - Search Capsule (内容部分，不含 frame/glass)

    private var searchCapsule: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: config.iconSize))
                .foregroundStyle(.secondary)

            TextField(currentPlaceholder, text: $viewModel.searchQuery)
                .font(.system(size: config.fontSize))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: config.iconSize))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, config.horizontalPadding)
        .padding(.vertical, config.verticalPadding)
    }

    // MARK: - Hint Circle

    private func hintCircle(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: config.iconSize))
            .foregroundStyle(hoveredHint == icon ? .primary : .secondary)
            .frame(width: config.buttonSize, height: config.buttonSize)
            .contentShape(Circle())
            .onHover { isHovered in
                if isHovered {
                    hoveredHint = icon
                } else {
                    let leaving = icon
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if hoveredHint == leaving {
                            withAnimation(.snappy(duration: 0.2)) {
                                hoveredHint = nil
                            }
                        }
                    }
                }
            }
    }

    // MARK: - Pin Button

    private var pinButton: some View {
        Button {
            isPinned.toggle()
            FloatingWindowManager.shared.isPinned = isPinned
        } label: {
            PinIconView(isPinned: isPinned, size: config.iconSize)
                .frame(width: config.buttonSize, height: config.buttonSize)
        }
        .buttonStyle(.plain)
    }
}
