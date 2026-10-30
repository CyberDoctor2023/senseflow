import SwiftUI
import AppKit

/// Screen-relative geometry shared by preview and its tool palette.
enum CentralToolLayout {
    static func frames(visible: CGRect, historyTop: CGFloat, desiredHeight: CGFloat) -> (preview: CGRect, tools: CGRect) {
        let gap: CGFloat = 24
        let floor = min(max(historyTop + gap, visible.minY + gap), visible.maxY - 240)
        let available = max(216, visible.maxY - floor - gap)
        let toolsHeight = min(176, max(104, available - 244))
        let previewHeight = min(max(220, desiredHeight), available - toolsHeight - gap)
        let totalHeight = previewHeight + toolsHeight + gap
        let bottom = min(visible.maxY - totalHeight - gap, max(floor, visible.midY - totalHeight / 2))
        let previewWidth = min(760, visible.width * 0.82)
        let toolsWidth = min(1100, visible.width - gap * 2)
        return (CGRect(x: visible.midX - previewWidth / 2, y: bottom + toolsHeight + gap,
                       width: previewWidth, height: previewHeight),
                CGRect(x: visible.midX - toolsWidth / 2, y: bottom, width: toolsWidth, height: toolsHeight))
    }
}

/// Independent tool presentation; repository and execution remain shared with settings.
@MainActor private final class ToolPalettePresentation: ObservableObject {
    @Published var isVisible = false
}

struct CentralToolPaletteHost: NSViewRepresentable {
    let viewModel: ClipboardListViewModel
    let workspace: WorkspaceWindowCoordinator
    let visible: Bool

    func makeNSView(context: Context) -> AnchorView { AnchorView() }
    func updateNSView(_ view: AnchorView, context: Context) {
        view.configure(model: viewModel, workspace: workspace, visible: visible)
    }
    static func dismantleNSView(_ view: AnchorView, coordinator: ()) { view.removePalette() }

    final class AnchorView: NSView {
        private var palette: PalettePanel?
        private let presentation = ToolPalettePresentation()
        private var hideTransition: UUID?
        private var wantsVisible = false
        private weak var model: ClipboardListViewModel?
        private weak var workspace: WorkspaceWindowCoordinator?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refresh() }
        func configure(model: ClipboardListViewModel, workspace: WorkspaceWindowCoordinator, visible: Bool) {
            self.model = model
            self.workspace = workspace
            wantsVisible = visible
            refresh()
        }
        func removePalette() {
            hideTransition = nil
            if let palette { palette.parent?.removeChildWindow(palette); palette.orderOut(nil) }
            palette = nil
        }
        private func hidePalette() {
            guard let palette, hideTransition == nil else { return }
            palette.ignoresMouseEvents = true
            guard presentation.isVisible else {
                palette.parent?.removeChildWindow(palette)
                palette.orderOut(nil)
                return
            }
            let token = UUID()
            hideTransition = token
            withAnimation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeInOut(duration: 0.28), completionCriteria: .removed) {
                presentation.isVisible = false
            } completion: { [weak self, weak palette] in
                guard let self, let palette, self.hideTransition == token else { return }
                self.hideTransition = nil
                palette.parent?.removeChildWindow(palette)
                palette.orderOut(nil)
            }
        }
        private func refresh() {
            guard wantsVisible, let parent = window, parent.isVisible, let model, let workspace,
                  let screen = parent.screen else {
                hidePalette()
                return
            }
            let panel: PalettePanel
            if let palette { panel = palette }
            else {
                panel = PalettePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                panel.isReleasedWhenClosed = false
                panel.hidesOnDeactivate = false
                panel.ignoresMouseEvents = true
                panel.contentView = NSHostingView(rootView: CentralToolPalette(viewModel: model, workspace: workspace, presentation: presentation, onAvailabilityChanged: { [weak self, weak panel] available in
                    guard let self, let panel else { return }
                    panel.ignoresMouseEvents = !available || !self.wantsVisible
                    if available, self.wantsVisible, self.window?.isVisible == true { panel.orderFront(nil) }
                })
                    .environment(\.appearsActive, true))
                palette = panel
                workspace.register(panel)
            }
            if panel.parent !== parent { parent.addChildWindow(panel, ordered: .above) }
            let layout = CentralToolLayout.frames(visible: screen.visibleFrame, historyTop: parent.frame.maxY,
                                                   desiredHeight: model.actions.documents.previewSize.height)
            panel.setFrame(layout.tools, display: false)
            panel.level = parent.level
            hideTransition = nil
            withAnimation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeInOut(duration: 0.28)) {
                presentation.isVisible = true
            }
            // Mount even while the repository is loading; otherwise the hosted .task
            // cannot load tools and make this initially transparent window interactive.
            panel.orderFront(nil)
        }
    }
    final class PalettePanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
}

private struct CentralToolPalette: View {
    @ObservedObject var viewModel: ClipboardListViewModel
    let workspace: WorkspaceWindowCoordinator
    @ObservedObject var presentation: ToolPalettePresentation
    let onAvailabilityChanged: (Bool) -> Void
    @State private var tools: [PromptTool] = []
    @State private var toolRevision = UUID()
    @State private var hoveredTool: UUID?
    @State private var targetedTool: UUID?
    @State private var runningTool: UUID?
    @State private var toolError: String?
    @State private var outcomes: [UUID: String] = [:]
    @State private var result: String?
    @State private var resultTarget: NSRunningApplication?
    @State private var fillingResult = false
    @State private var fillFeedback: String?
    @State private var showingResult = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 24) {
                    if presentation.isVisible {
                        ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                            toolButton(tool, number: index + 1, size: min(136, max(64, geometry.size.height - 40)))
                        }
                    }
                }
                .frame(minWidth: max(0, geometry.size.width - 40))
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .compatibleGlassGroup(spacing: 8)
        .font(.pingFang(size: 15))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if presentation.isVisible, let result {
                HStack(spacing: 16) {
                    Button("关闭结果") {
                        self.result = nil
                        viewModel.actions.isToolSessionPresented = false
                    }
                    Text(fillFeedback ?? "最近一次结果").foregroundStyle(.secondary)
                    Button("查看结果") { showingResult = true }
                    Button("复制结果") {
                        Task { await AppDependencies.shared.copyToolResult(result) }
                    }
                    if let target = resultTarget, !target.isTerminated {
                        Button("填入 \(target.localizedName ?? "原应用")") {
                            guard !fillingResult else { return }
                            fillingResult = true
                            fillFeedback = "正在填入…"
                            showingResult = false
                            Task {
                                defer { fillingResult = false }
                                if !(await FloatingWindowManager.shared.fillToolResult(result, into: target)) {
                                    fillFeedback = "请复制后粘贴"
                                    toolError = "未能发送粘贴。请确认原应用仍在前台、剪贴板未被覆盖且辅助功能权限已开启；结果仍可复制。"
                                } else { fillFeedback = "已发送粘贴" }
                            }
                        }
                        .disabled(fillingResult || runningTool != nil)
                    }
                }
                .font(.pingFang(size: 12))
                .padding(.bottom, 8)
                .background(ToolResultWorkspaceRegion(workspace: workspace))
                .popover(isPresented: $showingResult) {
                    ScrollView {
                        Text(result).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    }
                    .font(.pingFang(size: 15))
                    .frame(width: 480, height: 320)
                    .background(ToolResultWorkspaceRegion(workspace: workspace))
                }
            }
        }
        .task(id: toolRevision) { await reloadTools() }
        .onChange(of: tools.isEmpty, initial: true) { _, empty in onAvailabilityChanged(!empty) }
        .onChange(of: presentation.isVisible) { _, visible in
            if visible { onAvailabilityChanged(!tools.isEmpty) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptToolsDidUpdate).receive(on: RunLoop.main)) { _ in
            toolRevision = UUID()
        }
        .alert("工具未完成", isPresented: Binding(get: { toolError != nil }, set: { if !$0 { toolError = nil } })) {
            Button("好", role: .cancel) {
                toolError = nil
                if result == nil { viewModel.actions.isToolSessionPresented = false }
            }
        } message: { Text(toolError ?? "") }
    }

    private func toolButton(_ tool: PromptTool, number: Int, size: CGFloat) -> some View {
        Button { runTool(tool, input: nil) } label: {
            VStack(spacing: 14) {
                if runningTool == tool.id { ProgressView() }
                else { Image(systemName: toolSymbol(tool)).font(.system(size: 28, weight: .regular)) }
                Text(tool.name).lineLimit(2).multilineTextAlignment(.center)
                if let outcome = outcomes[tool.id] {
                    Text(outcome).font(.pingFang(size: 11))
                        .foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(12)
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .modifier(CentralToolGlass(id: tool.id, namespace: namespace, selected: targetedTool == tool.id))
        .scaleEffect(reduceMotion ? 1 : targetedTool == tool.id ? 1.08 : hoveredTool == tool.id ? 1.04 : 1)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0), value: targetedTool)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: hoveredTool)
        .onHover { inside in
            if inside { hoveredTool = tool.id }
            else if hoveredTool == tool.id { hoveredTool = nil }
        }
        .disabled(runningTool != nil || fillingResult)
        .accessibilityLabel(tool.name)
        .overlay {
            NativeToolDropTarget(enabled: presentation.isVisible && runningTool == nil && !fillingResult, number: number,
                onTargetChanged: { targeted in
                    if targeted { targetedTool = tool.id }
                    else if targetedTool == tool.id { targetedTool = nil }
                }, onActivate: { runTool(tool, input: nil) }, onDrop: { text in
                    guard runningTool == nil, !fillingResult else { return false }
                    viewModel.actions.isToolSessionPresented = true
                    runningTool = tool.id
                    outcomes[tool.id] = "正在处理…"
                    targetedTool = nil
                    Task { await executeTool(tool, input: text) }
                    return true
                })
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
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                tools = current
            }
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
        guard runningTool == nil, !fillingResult else { return }
        runningTool = tool.id
        outcomes[tool.id] = "正在处理…"
        Task {
            do {
                let current = try input ?? viewModel.actions.documents.toolInput()
                await executeTool(tool, input: current)
            } catch {
                runningTool = nil
                outcomes[tool.id] = "未完成"
                toolError = error.localizedDescription
            }
        }
    }

    @MainActor private func executeTool(_ tool: PromptTool, input: String?) async {
        defer { runningTool = nil }
        let target = FloatingWindowManager.shared.toolOutputTarget()
        do {
            result = try await AppDependencies.shared.promptToolCoordinator.executeTool(id: tool.toolID, input: input, autoPaste: false)
            resultTarget = target
            fillFeedback = nil
            outcomes[tool.id] = "已写入剪贴板"
        } catch {
            outcomes[tool.id] = "未完成"
            toolError = error.localizedDescription
        }
    }

}

/// Keeps result selection inside the same workspace as the preview and tool controls.
private struct ToolResultWorkspaceRegion: NSViewRepresentable {
    let workspace: WorkspaceWindowCoordinator
    func makeNSView(context: Context) -> RegionView { RegionView(workspace: workspace) }
    func updateNSView(_ view: RegionView, context: Context) {}

    final class RegionView: NSView, HistoryToolSurface {
        private let workspace: WorkspaceWindowCoordinator
        init(workspace: WorkspaceWindowCoordinator) {
            self.workspace = workspace
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { nil }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { workspace.register(window) }
        }
    }
}

/// Adapts the native whole-card drag image to a tool destination without changing its payload.
private struct NativeToolDropTarget: NSViewRepresentable {
    let enabled: Bool
    let number: Int
    let onTargetChanged: (Bool) -> Void
    let onActivate: () -> Void
    let onDrop: (String) -> Bool

    func makeNSView(context: Context) -> DestinationView {
        let view = DestinationView()
        view.registerForDraggedTypes([.string])
        updateNSView(view, context: context)
        CardDragPresentation.shared.registerTool(view)
        return view
    }
    func updateNSView(_ view: DestinationView, context: Context) {
        view.number = number
        view.enabled = enabled
        view.onTargetChanged = onTargetChanged
        view.onActivate = onActivate
        view.onDrop = onDrop
    }

    static func dismantleNSView(_ view: DestinationView, coordinator: ()) {
        CardDragPresentation.shared.unregisterTool(view)
    }

    final class DestinationView: NSView, HistoryToolSurface, CardToolDropSurface {
        var number = 1
        var enabled = true
        var onTargetChanged: ((Bool) -> Void)?
        var onActivate: (() -> Void)?
        var onDrop: ((String) -> Bool)?

        var toolScreenFrame: CGRect? {
            guard enabled, !isHiddenOrHasHiddenAncestor, let window, window.isVisible else { return nil }
            let exposed = bounds.intersection(visibleRect)
            guard !exposed.isNull, !exposed.isEmpty else { return nil }
            return window.convertToScreen(convert(exposed, to: nil))
        }
        var toolNumber: Int { number }
        func setCardTargeted(_ targeted: Bool) { onTargetChanged?(targeted) }
        func acceptCardText(_ text: String) -> Bool { toolScreenFrame != nil && onDrop?(text) == true }

        override func mouseUp(with event: NSEvent) { if enabled { onActivate?() } }
        override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
            guard toolScreenFrame != nil, sender.draggingPasteboard.string(forType: .string) != nil else { return [] }
            if !(sender.draggingSource is CardPointerRegion.PointerView) { onTargetChanged?(true) }
            return .copy
        }
        override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
            toolScreenFrame != nil && sender.draggingPasteboard.string(forType: .string) != nil ? .copy : []
        }
        override func draggingExited(_ sender: (any NSDraggingInfo)?) {
            if sender?.draggingSource is CardPointerRegion.PointerView { return }
            onTargetChanged?(false)
        }
        override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool { toolScreenFrame != nil }
        override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
            guard toolScreenFrame != nil, let window,
                  let text = sender.draggingPasteboard.string(forType: .string) else { return false }
            let accepted = sender.draggingSource is CardPointerRegion.PointerView
                ? CardDragPresentation.shared.deliver(text, to: self,
                    at: window.convertPoint(toScreen: sender.draggingLocation)) : acceptCardText(text)
            guard accepted else { return false }
            // AppKit owns the thumbnail throughout this native copy session.
            sender.animatesToDestination = false
            return true
        }
        override func draggingEnded(_ sender: any NSDraggingInfo) {
            if !(sender.draggingSource is CardPointerRegion.PointerView) { onTargetChanged?(false) }
        }
    }
}


private struct CentralToolGlass: ViewModifier {
    let id: UUID
    let namespace: Namespace.ID
    let selected: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .glassEffect(selected ? .regular.tint(.primary.opacity(0.08)).interactive() : .regular.interactive(),
                             in: .rect(cornerRadius: 28))
                .glassEffectID(id, in: namespace)
                .glassEffectTransition(.materialize)
        } else { content.background(.regularMaterial, in: .rect(cornerRadius: 28)) }
    }
}
