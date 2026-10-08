//
//  ClipboardListView.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import SwiftUI
import Combine
import AppKit
import QuickLook

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
    var loadOnAppear: Bool
    var observesUpdates: Bool

    // 布局配置（通过 DI 注入）
    var mainContainerConfig: MainContainerLayoutConfig
    var cardConfig: CardAreaLayoutConfig
    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var userIsScrolling = false
    @State private var tutorialViewportWidth: CGFloat = 0
    @State private var pointerX: CGFloat?
    @AppStorage(HistoryCardMotion.preferenceKey) private var cardMotion = HistoryCardMotion.wave
    @Environment(\.clipboardOnboarding) private var onboarding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 初始化器（接受注入的 ViewModel 和布局配置）
    init(
        viewModel: ClipboardListViewModel,
        mainContainerConfig: MainContainerLayoutConfig = .default,
        cardConfig: CardAreaLayoutConfig = .default,
        onItemSelected: ((ClipboardItem) -> Void)? = nil,
        loadOnAppear: Bool = true,
        observesUpdates: Bool = true
    ) {
        self.viewModel = viewModel
        self.mainContainerConfig = mainContainerConfig
        self.cardConfig = cardConfig
        self.onItemSelected = onItemSelected
        self.loadOnAppear = loadOnAppear
        self.observesUpdates = observesUpdates
    }

    var body: some View {
        @Bindable var actions = viewModel.actions
        // 直接在内容上应用 glassEffect，而不是分离的背景层
        VStack(spacing: 0) {
            // Card scroll area
            if viewModel.items.isEmpty {
                // Empty state
                VStack(spacing: Constants.EmptyState.spacing) {
                    Image(systemName: viewModel.searchQuery.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.pingFang(size: Constants.EmptyState.iconFontSize))
                        .foregroundStyle(.secondary)

                    Text(viewModel.searchQuery.isEmpty ? "暂无历史记录" : "未找到匹配结果")
                        .font(.pingFang(size: Constants.EmptyState.titleFontSize))
                        .foregroundStyle(.secondary)

                    if !viewModel.searchQuery.isEmpty {
                        Text("试试其他关键词")
                            .font(.pingFang(size: Constants.EmptyState.subtitleFontSize))
                            .foregroundStyle(.secondary.opacity(Constants.opacity70))
                    } else {
                        Text("复制任意内容后会自动保存")
                            .font(.pingFang(size: Constants.EmptyState.descriptionFontSize))
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
                Group {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .bottom, spacing: cardConfig.cardSpacing) {
                            ForEach(viewModel.items) { item in
                                ClipboardCardView(item: item, actions: viewModel.actions, thumbnails: viewModel.thumbnails)
                                    .modifier(HistoryPointerWave(pointerX: pointerX, strength: cardMotion == .wave ? 1 : 0,
                                        reduceMotion: reduceMotion || cardMotion == .classic))
                                    .id(item.id)
                                    .anchorPreference(key: OnboardingAnchors.self, value: .bounds) { anchor in
                                        onboarding?.historyStep == .preview && item.type == .text ? [.card(item.id): OnboardingAnchor(bounds: anchor, radius: Constants.Card.cornerRadius)] : [:]
                                    }
                            }

                        }
                        .frame(minWidth: onboarding != nil && tutorialViewportWidth > 0
                            ? tutorialViewportWidth + 80 : nil, alignment: .leading)
                        .scrollTargetLayout()
                        .compatibleGlassGroup(spacing: max(1, cardConfig.cardSpacing / 2))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.vertical, cardConfig.contentInset)
                        .id("history-content")
                    }
                    .compatibleHiddenHorizontalScrollEdges()
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location): pointerX = location.x
                        case .ended: pointerX = nil
                        }
                    }
                    .contentMargins(.horizontal, cardConfig.contentInset, for: .scrollContent)
                    .scrollPosition($scrollPosition)
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.containerSize.width
                    } action: { _, width in
                        if onboarding != nil { tutorialViewportWidth = width }
                    }
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.visibleRect.maxX >= geometry.contentSize.width - geometry.containerSize.width
                    } action: { _, nearEnd in
                        if nearEnd {
                            Task { await viewModel.loadMoreIfNeeded(after: viewModel.items.last?.id) }
                        }
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        min(max(0, geometry.contentOffset.x + geometry.contentInsets.leading),
                            max(0, geometry.contentSize.width - geometry.containerSize.width))
                    } action: { old, new in
                        if userIsScrolling { onboarding?.historyScrolled(by: new - old) }
                    }
                    .background(HorizontalWheelRegion(
                        onScroll: {
                            userIsScrolling = true
                            viewModel.actions.documents.historyScrolled()
                        }
                    ))
                    .onScrollPhaseChange { _, phase in
                        userIsScrolling = phase != .idle && phase != .animating
                        if phase != .idle {
                            viewModel.actions.documents.historyScrolled()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .windowWillShow)) { _ in
                        guard !viewModel.isWindowPinned else { return }
                        // 重置滚动位置到最左边（滚动到左边距占位符）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.snappy(duration: 0.2)) {
                                scrollPosition.scrollTo(edge: .leading)
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if let error = viewModel.errorMessage ?? viewModel.actions.errorMessage ?? viewModel.actions.documents.errorMessage {
                Text(error).font(.pingFang(.caption)).foregroundStyle(.red).padding(8).background(.regularMaterial)
            }
        }
        .quickLookPreview($actions.quickLookURL)
        .contentShape(Rectangle())
        .task {
            if loadOnAppear { await viewModel.loadItems() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardDidUpdate)) { _ in
            if observesUpdates { viewModel.historyDidChange() }
        }
    }

}

/// Routes adapted wheel gestures through AppKit's native scrolling and elasticity.
struct HorizontalWheelRegion: NSViewRepresentable {
    var isEnabled = true
    let onScroll: () -> Void
    func makeNSView(context: Context) -> WheelView {
        let view = WheelView()
        view.isEnabled = isEnabled
        view.onScroll = onScroll
        return view
    }
    func updateNSView(_ view: WheelView, context: Context) {
        view.isEnabled = isEnabled
        view.onScroll = onScroll
    }
    static func dismantleNSView(_ view: WheelView, coordinator: ()) { view.unregister() }
    final class WheelView: NSView, HistoryWheelRouting {
        var isEnabled = true {
            didSet { if !isEnabled { finishWheelGesture() } }
        }
        var onScroll: (() -> Void)?
        private weak var registeredPanel: KeyboardAcceptingPanel?
        private weak var gestureScroll: NSScrollView?
        private var wheelEndTimer: Timer?
        private var lastMouseWheelDelta: CGFloat = 0
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            unregister()
            guard let panel = window as? KeyboardAcceptingPanel else { return }
            panel.historyWheelRouter = self
            registeredPanel = panel
        }
        func unregister() {
            finishWheelGesture()
            lastMouseWheelDelta = 0
            if registeredPanel?.historyWheelRouter === self { registeredPanel?.historyWheelRouter = nil }
            registeredPanel = nil
        }
        func routeHistoryWheel(_ event: NSEvent) -> Bool {
            guard let window else { return false }
            // Unassociated wheel events carry screen coordinates, even when the panel receives them.
            let point = event.window === window ? event.locationInWindow : window.convertPoint(fromScreen: event.locationInWindow)
            guard !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control),
                  bounds.contains(convert(point, from: nil)),
                  let scroll = historyScroll(in: window.contentView, point: convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)) else {
                return false
            }
            guard isEnabled else { return true }
            let vertical = abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX)
            // Precision describes units, not the input device. High-resolution wheels
            // can deliver pixel deltas without the phases of a trackpad gesture.
            let phasedGesture = !event.phase.isEmpty || !event.momentumPhase.isEmpty
            if vertical && event.hasPreciseScrollingDeltas && phasedGesture {
                finishWheelGesture()
                lastMouseWheelDelta = 0
                return true
            }
            configure(scroll)
            onScroll?()
            if vertical {
                let pixels = event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 24)
                let discrete = event.phase.isEmpty && event.momentumPhase.isEmpty
                if discrete {
                    guard pixels != 0 else { return true }
                    if pixels * lastMouseWheelDelta < 0 {
                        // A reversal is a new intent: do not feed it through the previous elastic gesture.
                        wheelEndTimer?.invalidate()
                        wheelEndTimer = nil
                        if let cancelled = NativeHistoryWheelEvent.make(pixels: 0,
                            phase: Int64(CGScrollPhase.cancelled.rawValue)) {
                            scroll.scrollWheel(with: cancelled)
                        }
                        gestureScroll = nil
                        let clip = scroll.contentView
                        let boundary = clip.constrainBoundsRect(clip.bounds)
                        if abs(boundary.minX - clip.bounds.minX) > 0.5 {
                            // End only the outstanding elastic displacement before the new gesture.
                            scroll.horizontalScrollElasticity = .none
                            clip.scroll(to: boundary.origin)
                            scroll.reflectScrolledClipView(clip)
                            scroll.horizontalScrollElasticity = .allowed
                        }
                    }
                    lastMouseWheelDelta = pixels
                } else {
                    finishWheelGesture()
                    lastMouseWheelDelta = 0
                }
                let phase = discrete ? (gestureScroll == nil ? Int64(CGScrollPhase.began.rawValue) : Int64(CGScrollPhase.changed.rawValue)) : NativeHistoryWheelEvent.phase(event.phase)
                guard let forwarded = NativeHistoryWheelEvent.make(pixels: pixels, phase: phase,
                    momentum: discrete ? 0 : NativeHistoryWheelEvent.momentum(event.momentumPhase)) else { return false }
                scroll.scrollWheel(with: forwarded)
                if discrete {
                    gestureScroll = scroll
                    wheelEndTimer?.invalidate()
                    let timer = Timer(timeInterval: 0.12, repeats: false) { [weak self] _ in
                        MainActor.assumeIsolated { self?.finishWheelGesture() }
                    }
                    wheelEndTimer = timer
                    RunLoop.main.add(timer, forMode: .common)
                }
            } else {
                finishWheelGesture()
                lastMouseWheelDelta = 0
                scroll.scrollWheel(with: event)
            }
            return true
        }
        private func finishWheelGesture() {
            wheelEndTimer?.invalidate(); wheelEndTimer = nil
            if let scroll = gestureScroll,
               let ended = NativeHistoryWheelEvent.make(pixels: 0, phase: Int64(CGScrollPhase.ended.rawValue)) {
                scroll.scrollWheel(with: ended)
            }
            gestureScroll = nil
        }
        private func configure(_ scroll: NSScrollView) {
            if scroll.horizontalScrollElasticity != .allowed { scroll.horizontalScrollElasticity = .allowed }
            if scroll.verticalScrollElasticity != .none { scroll.verticalScrollElasticity = .none }
            if scroll.horizontalLineScroll != 24 { scroll.horizontalLineScroll = 24 }
            if scroll.hasHorizontalScroller { scroll.hasHorizontalScroller = false }
            if scroll.hasVerticalScroller { scroll.hasVerticalScroller = false }
            if scroll.drawsBackground { scroll.drawsBackground = false }
            if scroll.borderType != .noBorder { scroll.borderType = .noBorder }
        }
        private func historyScroll(in view: NSView?, point: NSPoint) -> NSScrollView? {
            guard let view else { return nil }
            // Compare in window coordinates; NSHostingView may be flipped.
            if let scroll = view as? NSScrollView,
               !(scroll.documentView is DocumentTextView),
               scroll.convert(scroll.bounds, to: nil).contains(point) { return scroll }
            for child in view.subviews {
                if let scroll = historyScroll(in: child, point: point) { return scroll }
            }
            return nil
        }
    }
}

/// Builds a pixel gesture from the delivered NSEvent values rather than rewriting device-specific backing fields.
enum NativeHistoryWheelEvent {
    static func make(pixels: CGFloat, phase: Int64, momentum: Int64 = 0) -> NSEvent? {
        guard pixels.isFinite else { return nil }
        let delta = min(CGFloat(Int32.max), max(CGFloat(Int32.min), pixels))
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                  wheel1: 0, wheel2: Int32(delta.rounded()), wheel3: 0) else { return nil }
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Int64((delta * 65536).rounded()))
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
        return NSEvent(cgEvent: event)
    }
    static func phase(_ phase: NSEvent.Phase) -> Int64 {
        if phase.contains(.began) { return Int64(CGScrollPhase.began.rawValue) }
        if phase.contains(.changed) { return Int64(CGScrollPhase.changed.rawValue) }
        if phase.contains(.ended) { return Int64(CGScrollPhase.ended.rawValue) }
        if phase.contains(.cancelled) { return Int64(CGScrollPhase.cancelled.rawValue) }
        if phase.contains(.mayBegin) { return Int64(CGScrollPhase.mayBegin.rawValue) }
        return 0
    }
    static func momentum(_ phase: NSEvent.Phase) -> Int64 {
        if phase.contains(.began) { return 1 }
        if phase.contains(.changed) { return 2 }
        if phase.contains(.ended) || phase.contains(.cancelled) { return 3 }
        return 0
    }
}

/// Layout-preserving Dock-like elevation around the pointer.
private struct HistoryPointerWave: ViewModifier {
    let pointerX: CGFloat?
    let strength: CGFloat
    let reduceMotion: Bool
    func body(content: Content) -> some View {
        content.visualEffect { effect, geometry in
            let lift: CGFloat = elevation(geometry)
            return effect.scaleEffect(1 + lift * 0.02, anchor: .bottom).offset(y: -12 * lift)
        }
    }
    private func elevation(_ geometry: GeometryProxy) -> CGFloat {
        guard !reduceMotion, let pointerX else { return 0 }
        let center = geometry.frame(in: .scrollView(axis: .horizontal)).midX
        let distance = (center - pointerX) / max(CGFloat(Constants.Card.width) * 1.3, 1)
        return strength * CGFloat(exp(-Double(distance * distance)))
    }
}
