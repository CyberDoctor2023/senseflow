//
//  UnifiedPanelView.swift
//  SenseFlow
//
//  Created on 2026-02-11.
//

import SwiftUI
import Observation

/// Owns only the departing tutorial content until the native animation completes.
@MainActor @Observable final class ClipboardHistoryHandoff {
    private(set) var outgoingModel: ClipboardListViewModel?
    private(set) var departure: CGFloat = 0
    private(set) var arrival: CGFloat = 0
    private(set) var welcomeVisible = false
    private var started = false
    @ObservationIgnored private let welcomeSound: NSSound? = {
        let sound = NSSound(named: NSSound.Name("Glass"))
        sound?.volume = 0.22
        return sound
    }()
    @ObservationIgnored private let completion: () -> Void
    init(outgoingModel: ClipboardListViewModel, completion: @escaping () -> Void) {
        self.outgoingModel = outgoingModel
        self.completion = completion
    }
    func start(reduceMotion: Bool) {
        guard !started else { return }
        started = true
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.3), completionCriteria: .removed) {
            departure = 1
        } completion: { [weak self] in
            guard let self else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                self.welcomeVisible = true
            }
            self.welcomeSound?.play()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                guard let self else { return }
                withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2), completionCriteria: .removed) {
                    self.welcomeVisible = false
                } completion: { [weak self] in
                    self?.arrive(reduceMotion: reduceMotion)
                }
            }
        }
    }
    private func arrive(reduceMotion: Bool) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4), completionCriteria: .removed) {
            arrival = 1
        } completion: { [weak self] in
            guard let self else { return }
            self.outgoingModel = nil
            self.completion()
        }
    }
}

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
    var handoff: ClipboardHistoryHandoff? = nil

    @State private var isSearchBarExpanded: Bool = true  // 控制搜索栏展开状态
    @Environment(\.clipboardOnboarding) private var onboarding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            HistoryBackdrop(height: mainContainerConfig.windowHeight(cardConfig: cardConfig),
                            cornerRadius: mainContainerConfig.cornerRadius)
                .onboardingTarget(.history, radius: mainContainerConfig.cornerRadius)
            // Search and background keep their original baseline while a card grows above them.
            VStack(spacing: 0) {
                EmptyBackgroundView(viewModel: viewModel, isExpanded: $isSearchBarExpanded)
                    .frame(height: topConfig.windowHeight)
                    .allowsHitTesting(handoff == nil || handoff?.outgoingModel == nil)
                Color.clear
                    .frame(height: topConfig.gapFromMainWindow + mainContainerConfig.windowHeight(cardConfig: cardConfig))
                    .allowsHitTesting(false)
            }
            .frame(height: topConfig.windowHeight + topConfig.gapFromMainWindow + mainContainerConfig.windowHeight(cardConfig: cardConfig))

            GeometryReader { geometry in
                ZStack {
                    if let outgoing = handoff?.outgoingModel {
                        ClipboardListView(viewModel: outgoing, mainContainerConfig: mainContainerConfig,
                            cardConfig: cardConfig, loadOnAppear: false, observesUpdates: false)
                            .offset(y: geometry.size.height * (handoff?.departure ?? 0))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    ClipboardListView(viewModel: viewModel, mainContainerConfig: mainContainerConfig,
                        cardConfig: cardConfig, onItemSelected: onItemSelected,
                        loadOnAppear: handoff == nil)
                        .offset(y: geometry.size.height * (1 - (handoff?.arrival ?? 1)))
                        .allowsHitTesting(handoff == nil || handoff?.outgoingModel == nil)
                    if handoff?.welcomeVisible == true {
                        Text("你的剪贴板已准备好")
                            .font(.custom("PingFang SC", size: 24).weight(.medium))
                            .foregroundStyle(.primary)
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: mainContainerConfig.windowHeight(cardConfig: cardConfig))
            .task { handoff?.start(reduceMotion: reduceMotion) }
        }
        // 给 glass 阴影预留透明溢出区，避免被窗口边界裁剪
        .padding(.horizontal, Constants.ClipboardWindow.shadowBleedHorizontal)
        .padding(.top, Constants.ClipboardWindow.shadowBleedTop)
        .padding(.bottom, Constants.ClipboardWindow.shadowBleedBottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .containerBackground(.clear, for: .window)  // 窗口级背景透明
        .font(.pingFang(size: 13))
        .contextualOnboarding(onboarding, hasRecords: !viewModel.items.isEmpty)
        .environment(\.appearsActive, true)  // 强制始终显示活跃外观，避免焦点切换卡顿
        .onReceive(NotificationCenter.default.publisher(for: .windowWillShow)) { _ in
            guard !viewModel.isWindowPinned else { return }
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

/// Fixed history surface; document geometry is deliberately absent from its inputs.
private struct HistoryBackdrop: View {
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Color.clear
            .frame(height: height)
            .compatibleGlassEffect(cornerRadius: cornerRadius)
    }
}
