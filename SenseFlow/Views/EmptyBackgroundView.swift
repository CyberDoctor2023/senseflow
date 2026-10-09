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
/// 布局：搜索胶囊（左）+ 2 个类型筛选圆（文本/图片）+ 钉子圆（右）
/// 动画：窗口出现时，一条长 bar → 右侧分离出 2 个圆球（GlassEffectContainer morphing）
struct EmptyBackgroundView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: ClipboardListViewModel
    @FocusState private var isSearchFocused: Bool
    @Binding var isExpanded: Bool  // 由父视图控制
    @State private var hoveredHint: String?
    @Namespace private var glassNamespace
    @Environment(\.clipboardOnboarding) private var onboarding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("filter_text_enabled") private var textEnabled = true
    @AppStorage("filter_image_enabled") private var imageEnabled = true
    @AppStorage("filter_code_enabled") private var codeEnabled = true
    @AppStorage("filter_screenshot_enabled") private var screenshotEnabled = false
    @AppStorage("filter_recording_enabled") private var recordingEnabled = false

    private let config = SearchBarConfig.default

    private let defaultPlaceholder = "搜索任意"

    private var hints: [(icon: String, text: String, type: ClipboardContentFilter)] {
        var result: [(icon: String, text: String, type: ClipboardContentFilter)] = []
        if textEnabled { result.append(("doc.text", "文字", .text)) }
        if imageEnabled { result.append(("photo", "图片", .image)) }
        if codeEnabled { result.append(("chevron.left.forwardslash.chevron.right", "代码", .code)) }
        if screenshotEnabled { result.append(("viewfinder", "截图", .screenshot)) }
        if recordingEnabled { result.append(("video", "录屏", .recording)) }
        return result
    }

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
        .onChange(of: hints.map(\.type), initial: true) { _, visible in
            Task { await viewModel.clearHiddenFilter(visible) }
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
                    ForEach(hints, id: \.icon) { hint in
                        typeButton(icon: hint.icon, title: hint.text, type: hint.type)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .glassEffectID("hint-\(hint.icon)", in: glassNamespace)
                            .glassEffectTransition(.matchedGeometry)
                            .modifier(CategorySurfaceFeedback())
                            .frame(width: config.buttonSize, height: config.buttonSize)
                            .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: viewModel.selectedType)
                            .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: hoveredHint)
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
                typeButton(icon: hint.icon, title: hint.text, type: hint.type)
                    .background(config.material, in: Circle())
                    .modifier(CategorySurfaceFeedback())
                    .frame(width: config.buttonSize, height: config.buttonSize)
                    .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: viewModel.selectedType)
                    .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: hoveredHint)
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
                .font(.pingFang(size: config.iconSize))
                .foregroundStyle(.secondary)

            TextField(currentPlaceholder, text: $viewModel.searchQuery)
                .disabled(viewModel.isWindowPinned)
                .font(.pingFang(size: config.fontSize))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.pingFang(size: config.iconSize))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .disabled(viewModel.isWindowPinned)
        .padding(.horizontal, config.horizontalPadding)
        .padding(.vertical, config.verticalPadding)
        .onboardingTarget(.search, radius: config.height / 2)
    }

    // MARK: - Hint Circle

    private func typeButton(icon: String, title: String, type: ClipboardContentFilter) -> some View {
        return Button {
            Task {
                let previous = viewModel.selectedType
                await viewModel.selectType(type)
                if viewModel.selectedType != previous { onboarding?.categorySelected() }
            }
        } label: {
            Image(systemName: icon)
                .font(.pingFang(size: config.iconSize))
                .foregroundStyle(viewModel.selectedType == type ? Color.primary : Color.secondary)
                .frame(width: config.buttonSize, height: config.buttonSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(title)
        .accessibilityValue(viewModel.selectedType == type ? "已选中" : "未选中")
        .help(viewModel.selectedType == type ? "再次点击显示全部" : "只显示\(title)")
        .onHover { hoveredHint = $0 ? icon : nil }
        .onboardingTarget(onboardingTarget(for: type), radius: config.buttonSize / 2)
    }

    private func onboardingTarget(for type: ClipboardContentFilter) -> OnboardingTarget {
        switch type {
        case .text: return .textFilter
        case .image: return .imageFilter
        case .code: return .codeFilter
        case .screenshot: return .screenshotFilter
        case .recording: return .recordingFilter
        }
    }

    // MARK: - Pin Button

    private var pinButton: some View {
        Button {
            if onboarding != nil {
                viewModel.isWindowPinned.toggle()
            } else {
                FloatingWindowManager.shared.isPinned = !viewModel.isWindowPinned
            }
        } label: {
            PinIconView(isPinned: viewModel.isWindowPinned, size: config.iconSize)
                .frame(width: config.buttonSize, height: config.buttonSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isWindowPinned ? "解锁剪贴板内容" : "锁定剪贴板内容")
        .help(viewModel.isWindowPinned ? "解锁并显示最新历史" : "锁定当前卡片，可拖入其他窗口")
        .onboardingTarget(.pin, radius: config.buttonSize / 2)
    }
}

/// Scales the complete category surface, including its glass shell.
private struct CategorySurfaceFeedback: ViewModifier {
    @GestureState private var pressed = false
    @State private var enlarged = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion || !enlarged ? 1 : 1.10)
            .animation(reduceMotion ? nil : .smooth(duration: enlarged ? 0.12 : 0.2), value: enlarged)
            .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in state = true })
            .task(id: pressed) {
                if pressed { enlarged = true }
                else {
                    do {
                        // Preserve feedback for a brief click without delaying the filter action.
                        try await Task.sleep(for: .milliseconds(100))
                        enlarged = false
                    } catch { /* A new press cancels the pending release. */ }
                }
            }
            .onDisappear { enlarged = false }
    }
}
