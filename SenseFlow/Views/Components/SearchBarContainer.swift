//
//  SearchBarContainer.swift
//  SenseFlow
//
//  Created on 2026-02-10.
//

import SwiftUI

/// 搜索栏主容器组件
/// 支持可组合的 leading/trailing 内容，使用 Capsule 形状搜索框
/// 支持 GlassEffectContainer 动画（macOS 26.0+）
struct SearchBarContainer<Leading: View, Trailing: View>: View {

    // MARK: - Properties

    /// 搜索文本绑定
    @Binding var searchText: String

    /// 占位符文本
    var placeholder: String

    /// 配置对象
    var config: SearchBarConfig

    /// 是否启用动画效果（默认不展开）
    var enableAnimation: Bool

    /// 可选的焦点状态绑定（用于外部控制焦点）
    var focused: FocusState<Bool>.Binding?

    /// Leading 内容（搜索框左侧）
    @ViewBuilder var leading: Leading

    /// Trailing 内容（搜索框右侧，通常是按钮组）
    @ViewBuilder var trailing: Trailing

    // MARK: - State

    @FocusState private var internalFocused: Bool
    @Namespace private var namespace
    @State private var isExpanded: Bool = true  // 默认展开显示所有按钮

    // MARK: - Body

    var body: some View {
        if enableAnimation {
            if #available(macOS 26.0, *) {
                animatedSearchBar
            } else {
                staticSearchBar
            }
        } else {
            staticSearchBar
        }
    }

    // MARK: - Static Search Bar (No Animation)

    private var staticSearchBar: some View {
        HStack(spacing: config.componentSpacing) {
            // Leading content (if any)
            leading

            // Search capsule
            searchCapsule

            // Trailing content (buttons)
            HStack(spacing: config.buttonSpacing) {
                trailing
            }
        }
    }

    // MARK: - Animated Search Bar (GlassEffectContainer)

    @available(macOS 26.0, *)
    private var animatedSearchBar: some View {
        GlassEffectContainer(spacing: config.morphingSpacing) {
            HStack(spacing: isExpanded ? config.componentSpacing : 0) {
                // Leading content (if any)
                leading

                // Search capsule with glass effect
                searchCapsule
                    .glassEffect()
                    .glassEffectID("searchBar", in: namespace)

                // Trailing content (buttons) - animated appearance
                if isExpanded {
                    HStack(spacing: config.buttonSpacing) {
                        trailing
                    }
                    .glassEffect()
                    .glassEffectID("trailingButtons", in: namespace)
                    .glassEffectTransition(.matchedGeometry)
                }
            }
        }
        .animation(config.transitionAnimation, value: isExpanded)
    }

    // MARK: - Search Capsule

    private var searchCapsule: some View {
        HStack(spacing: 8) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: config.iconSize))
                .foregroundStyle(.secondary)

            // Text field
            TextField(placeholder, text: $searchText)
                .font(.system(size: config.fontSize))
                .textFieldStyle(.plain)
                .focused(focused ?? $internalFocused)

            // Clear button (visible when text is not empty)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
        .frame(minWidth: config.minWidth, maxWidth: config.maxWidth)
        .frame(height: config.height)
        .background(config.material, in: Capsule())
        .animation(config.transitionAnimation, value: searchText.isEmpty)
    }
}

// MARK: - Convenience Initializers

extension SearchBarContainer where Leading == EmptyView {
    /// 只有 trailing 内容的初始化器
    init(
        searchText: Binding<String>,
        placeholder: String = "搜索",
        enableAnimation: Bool = false,
        focused: FocusState<Bool>.Binding? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.config = SearchBarConfig.default
        self.enableAnimation = enableAnimation
        self.focused = focused
        self.leading = EmptyView()
        self.trailing = trailing()
    }
}


extension SearchBarContainer where Trailing == EmptyView {
    /// 只有 leading 内容的初始化器
    init(
        searchText: Binding<String>,
        placeholder: String = "搜索",
        enableAnimation: Bool = false,
        focused: FocusState<Bool>.Binding? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.config = SearchBarConfig.default
        self.enableAnimation = enableAnimation
        self.focused = focused
        self.leading = leading()
        self.trailing = EmptyView()
    }
}


extension SearchBarContainer where Leading == EmptyView, Trailing == EmptyView {
    /// 无额外内容的初始化器
    init(
        searchText: Binding<String>,
        placeholder: String = "搜索",
        enableAnimation: Bool = false,
        focused: FocusState<Bool>.Binding? = nil
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.config = SearchBarConfig.default
        self.enableAnimation = enableAnimation
        self.focused = focused
        self.leading = EmptyView()
        self.trailing = EmptyView()
    }
}
