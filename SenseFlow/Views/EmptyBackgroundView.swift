//
//  EmptyBackgroundView.swift
//  SenseFlow
//
//  Created on 2026-02-09.
//

import SwiftUI
import AppKit

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
    var toolRestingOffset: CGFloat
    @State private var tools: [PromptTool] = []
    @State private var toolRevision = UUID()
    @State private var hoveredTool: UUID?
    @State private var targetedTool: UUID?
    @State private var runningTool: UUID?
    @State private var toolError: String?
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: showsTools)
        .animation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.12), value: toolsEngaged)
        .task(id: toolRevision) { await reloadTools() }
        .onReceive(NotificationCenter.default.publisher(for: .promptToolsDidUpdate).receive(on: RunLoop.main)) { _ in
            toolRevision = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowWillShow)) { _ in
            toolRevision = UUID()
        }
        .alert("工具未完成", isPresented: Binding(get: { toolError != nil }, set: { if !$0 { toolError = nil } })) {
            Button("好", role: .cancel) { toolError = nil }
        } message: { Text(toolError ?? "") }
        .onChange(of: hints.map(\.type), initial: true) { _, visible in
            Task { await viewModel.clearHiddenFilter(visible) }
        }
    }

    // MARK: - Glass Body (macOS 26+)

    @available(macOS 26.0, *)
    private var glassBody: some View {
        Group {
            HStack(spacing: elementSpacing) {
                GlassEffectContainer(spacing: isExpanded ? 0 : glassSpacing) {
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
                    HStack(spacing: elementSpacing) {
                    ForEach(hints, id: \.icon) { hint in
                        typeButton(icon: hint.icon, title: hint.text, type: hint.type)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .glassEffectID("hint-\(hint.icon)", in: glassNamespace)
                            .glassEffectTransition(.matchedGeometry)
                            .modifier(CategorySurfaceFeedback(hovered: hoveredHint == hint.icon))
                            .frame(width: config.buttonSize, height: config.buttonSize)
                            .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: viewModel.selectedType)
                            .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: hoveredHint)
                    }
                    }
                    .contentShape(Rectangle())
                    .onContinuousHover { updateCategoryHover($0) }
                }

                }
                }

                Spacer()

                contextualToolTargets

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

            HStack(spacing: elementSpacing) {
            ForEach(hints, id: \.icon) { hint in
                typeButton(icon: hint.icon, title: hint.text, type: hint.type)
                    .background(config.material, in: Circle())
                    .modifier(CategorySurfaceFeedback(hovered: hoveredHint == hint.icon))
                    .frame(width: config.buttonSize, height: config.buttonSize)
                    .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: viewModel.selectedType)
                    .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: hoveredHint)
            }
            }
            .contentShape(Rectangle())
            .onContinuousHover { updateCategoryHover($0) }

            Spacer()

            contextualToolTargets

            Spacer()

            pinButton
                .background(config.material, in: Circle())
        }
        .frame(maxWidth: .infinity)  // 只约束宽度，让高度自然确定
    }

    private var toolsEngaged: Bool {
        let document = viewModel.actions.documents
        return viewModel.actions.isDragging || document.isLoading || document.previewWindowNumber != nil
    }

    private var showsTools: Bool { toolsEngaged || viewModel.actions.pressedItemID != nil }

    @ViewBuilder private var contextualToolTargets: some View {
        if showsTools {
            toolTargets
                .offset(y: toolsEngaged ? 0 : toolRestingOffset - 6)
                .allowsHitTesting(toolsEngaged)
                .accessibilityHidden(!toolsEngaged)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: toolsEngaged)
        }
    }

    private var toolTargets: some View {
        HStack(spacing: 36) {
            ForEach(Array(tools.prefix(9).enumerated()), id: \.element.id) { index, tool in
                Button {
                    runTool(tool, input: nil)
                } label: {
                    Group {
                        if runningTool == tool.id { ProgressView().controlSize(.small) }
                        else { Image(systemName: toolSymbol(tool)).overlay(alignment: .bottomTrailing) {
                            Text("\(index + 1)").font(.pingFang(size: 8)).offset(x: 8, y: 7)
                        } }
                    }
                    .font(.pingFang(size: config.iconSize))
                    .opacity(toolsEngaged ? 1 : 0)
                    .frame(width: config.buttonSize, height: config.buttonSize)
                }
                .buttonStyle(.plain)
                .modifier(ToolGlassSurface(id: tool.id, namespace: glassNamespace,
                                           active: showsTools, selected: targetedTool == tool.id))
                .scaleEffect(targetedTool == tool.id ? 1.16 : (hoveredTool == tool.id ? Constants.SelectionFeedback.scale : 1))
                .overlay {
                    Circle().stroke(.primary.opacity(targetedTool == tool.id ? 0.28 : 0), lineWidth: 1.5)
                        .allowsHitTesting(false)
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: targetedTool)
                .onHover { inside in
                    if inside { hoveredTool = tool.id }
                    else if hoveredTool == tool.id { hoveredTool = nil }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: Constants.SelectionFeedback.duration), value: hoveredTool)
                .disabled(runningTool != nil)
                .help("\(tool.name) · 拖入文字卡片 · ⌘⇧\(index + 1)")
                .accessibilityLabel(tool.name)
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .shift])
                .overlay {
                    NativeToolDropTarget(enabled: runningTool == nil, reduceMotion: reduceMotion,
                        symbol: toolSymbol(tool), number: index + 1,
                        onTargetChanged: { targeted in
                            if targeted { targetedTool = tool.id }
                            else if targetedTool == tool.id { targetedTool = nil }
                        }, onActivate: { runTool(tool, input: nil) }, onDrop: { text in
                            guard runningTool == nil else { return false }
                            runningTool = tool.id
                            targetedTool = nil
                            Task { await executeTool(tool, input: text) }
                            return true
                        })
                }
            }
        }
    }

    private func toolSymbol(_ tool: PromptTool) -> String {
        switch tool.name {
        case "Markdown 格式化": return "textformat"
        case "表格生成": return "tablecells"
        case "邮件规范化": return "envelope"
        case "提取标题": return "textformat.size"
        default: return "wand.and.stars"
        }
    }

    @MainActor private func reloadTools() async {
        do {
            let current = try await AppDependencies.shared.promptToolCoordinator.loadTools().filter { !$0.isSmart }
            try Task.checkCancellation()
            tools = current
            if let targetedTool, !current.contains(where: { $0.id == targetedTool }) { self.targetedTool = nil }
            if let hoveredTool, !current.contains(where: { $0.id == hoveredTool }) { self.hoveredTool = nil }
        } catch is CancellationError {
            // A newer repository change owns the next toolbar snapshot.
        } catch {
            guard !Task.isCancelled else { return }
            tools = []
            toolError = error.localizedDescription
        }
    }

    @MainActor private func runTool(_ tool: PromptTool, input: String?) {
        guard runningTool == nil else { return }
        runningTool = tool.id
        Task {
            do {
                let current = try input ?? viewModel.actions.documents.toolInput()
                await executeTool(tool, input: current)
            } catch { runningTool = nil; toolError = error.localizedDescription }
        }
    }

    @MainActor private func executeTool(_ tool: PromptTool, input: String?) async {
        defer { runningTool = nil }
        do {
            _ = try await AppDependencies.shared.promptToolCoordinator.executeTool(id: tool.toolID, input: input, autoPaste: false)
        } catch { toolError = error.localizedDescription }
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
        .onboardingTarget(onboardingTarget(for: type), radius: config.buttonSize / 2)
    }

    /// Keeps the gap between adjacent category surfaces inside the hover region.
    private func updateCategoryHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            guard !hints.isEmpty else { return }
            let index = min(hints.count - 1, max(0,
                Int((location.x + elementSpacing / 2) / (config.buttonSize + elementSpacing))))
            let icon = hints[index].icon
            if hoveredHint != icon { hoveredHint = icon }
        case .ended:
            hoveredHint = nil
        }
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
    let hovered: Bool
    @GestureState private var pressed = false
    @State private var enlarged = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : enlarged ? 1.10 : hovered ? Constants.SelectionFeedback.scale : 1)
            .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: hovered)
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

/// Adapts the native whole-card drag image to a tool destination without changing its payload.
private struct NativeToolDropTarget: NSViewRepresentable {
    let enabled: Bool
    let reduceMotion: Bool
    let symbol: String
    let number: Int
    let onTargetChanged: (Bool) -> Void
    let onActivate: () -> Void
    let onDrop: (String) -> Bool

    func makeNSView(context: Context) -> DestinationView {
        let view = DestinationView()
        view.registerForDraggedTypes([.string])
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ view: DestinationView, context: Context) {
        view.symbol = symbol
        view.number = number
        view.enabled = enabled
        view.reduceMotion = reduceMotion
        view.onTargetChanged = onTargetChanged
        view.onActivate = onActivate
        view.onDrop = onDrop
    }

    final class DestinationView: NSView, HistoryToolSurface {
        var symbol = "wand.and.stars"
        var number = 1
        var enabled = true
        var reduceMotion = false
        var onTargetChanged: ((Bool) -> Void)?
        var onActivate: (() -> Void)?
        var onDrop: ((String) -> Bool)?

        override func mouseUp(with event: NSEvent) { if enabled { onActivate?() } }
        override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
            guard enabled, sender.draggingPasteboard.string(forType: .string) != nil else { return [] }
            if let window {
                CardDragPresentation.shared.targetFrame = window.convertToScreen(convert(bounds, to: nil))
                CardDragPresentation.shared.targetSymbol = symbol
                CardDragPresentation.shared.targetNumber = number
            }
            onTargetChanged?(true)
            return sender.draggingSource is CardPointerRegion.PointerView ? .generic : .copy
        }
        override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
            enabled ? (sender.draggingSource is CardPointerRegion.PointerView ? .generic : .copy) : []
        }
        override func draggingExited(_ sender: (any NSDraggingInfo)?) {
            CardDragPresentation.shared.targetFrame = nil
            onTargetChanged?(false)
        }
        override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool { enabled }
        override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
            guard enabled, let text = sender.draggingPasteboard.string(forType: .string),
                  onDrop?(text) == true else { return false }
            // The live card surface owns the visible arrival; native dragging carries only the data.
            sender.animatesToDestination = false
            return true
        }
        override func draggingEnded(_ sender: any NSDraggingInfo) {
            CardDragPresentation.shared.targetFrame = nil
            onTargetChanged?(false)
        }
    }
}

/// Only the current destination shares the dragged card's glass extraction group.
private struct ToolGlassSurface: ViewModifier {
    let id: UUID
    let namespace: Namespace.ID
    let active: Bool
    let selected: Bool

    private var toolsAreDragging: Bool { CardDragPresentation.shared.surface != nil }

    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if active {
                if selected && CardDragPresentation.shared.inside { content.opacity(0) }
                else if !toolsAreDragging { surface(content) }
                else { GlassEffectContainer(spacing: 0) { surface(content) } }
            }
        } else {
            content.background(.regularMaterial, in: Circle()).opacity(active ? 1 : 0)
        }
    }

    @available(macOS 26.0, *)
    private func surface(_ content: Content) -> some View {
        content.foregroundStyle(selected ? Color.primary : Color.secondary)
            .glassEffect(.regular.interactive(), in: .circle)
            .glassEffectID(id, in: namespace)
            .glassEffectTransition(.matchedGeometry)
    }
}
