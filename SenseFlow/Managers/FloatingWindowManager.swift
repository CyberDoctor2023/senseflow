//
//  FloatingWindowManager.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Cocoa
import SwiftUI

/// 悬浮窗口管理器（单例）
@MainActor class FloatingWindowManager {

    // MARK: - Singleton

    static let shared = FloatingWindowManager()

    // MARK: - Properties

    // 双窗口池架构：只有 A、B 两个窗口交替使用
    private var windowA: NSPanel?
    private var windowB: NSPanel?
    private var activeWindow: NSPanel?  // 当前活跃的窗口（A 或 B）

    private var sharedViewModel: ClipboardListViewModel?  // 共享 ViewModel（DI 模式，用于多窗口数据同步）
    let workspace = WorkspaceWindowCoordinator()
    let onboarding: ClipboardOnboardingCoordinator
    private var tutorial: ClipboardTutorialSession?
    private var tutorialHandoffTask: Task<Void, Never>?
    lazy var documentPreview: DocumentPreviewCoordinator = {
        let preview = DocumentPreviewCoordinator(repository: documentRepository, writer: clipboardWriter,
            host: DocumentWindowHost(workspace: workspace))
        return preview
    }()
    private lazy var documentRepository = DocumentRepository(store: .shared)
    private lazy var clipboardWriter: ClipboardWriter = NSPasteboardAdapter(monitor: .shared)
    private lazy var historyActions = HistoryActionCoordinator(documents: documentPreview, repository: documentRepository, writer: clipboardWriter, onPaste: { [weak self] in
        if self?.isPinned != true { self?.hideWindowImmediately() }
        AutoPasteManager.shared.performAutoPaste(delay: 0.5)
    }, onDragEnded: { [weak self] in
        DispatchQueue.main.async { [weak self] in self?.hideIfOutsideWorkspace() }
    })
    private lazy var thumbnails = ClipboardThumbnailLoader(repository: documentRepository)
    private let repository: ClipboardRepositoryProtocol  // 数据仓库（依赖倒置）

    /// A/B windows share the model's single pin state.
    var isPinned: Bool {
        get { sharedViewModel?.isWindowPinned ?? false }
        set {
            sharedViewModel?.isWindowPinned = newValue
            if !newValue {
                DispatchQueue.main.async { [weak self] in self?.hideIfOutsideWorkspace() }
            }
        }
    }

    // MARK: - Layout Configuration

    private let layoutConfig: WindowLayoutConfigurable

    // MARK: - Helper Classes

    private let windowFactory: WindowFactory
    private let windowConfigurator: WindowConfigurator
    private let windowPositioner: WindowPositioner
    private let windowLifecycle: WindowLifecycle
    private let appStateManager: AppStateManager

    // MARK: - Initialization

    private init(layoutConfig: WindowLayoutConfigurable = WindowLayoutConfig.default) {
        self.layoutConfig = layoutConfig
        self.repository = DatabaseClipboardRepository()
        self.onboarding = ClipboardOnboardingCoordinator()

        // 初始化辅助类
        self.windowFactory = WindowFactory(layoutConfig: layoutConfig, repository: repository)
        self.windowConfigurator = WindowConfigurator()
        self.windowPositioner = WindowPositioner(layoutConfig: layoutConfig)
        self.windowLifecycle = WindowLifecycle(
            windowConfigurator: windowConfigurator,
            windowPositioner: windowPositioner,
            layoutConfig: layoutConfig
        )
        self.appStateManager = AppStateManager()

        onboarding.onComplete = { [weak self] in
            self?.completeTutorial()
        }
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Public Methods

    /// 显示窗口
    func showWindow() {
        guard tutorialHandoffTask == nil else { return }
        if !onboarding.isComplete {
            showTutorial()
            return
        }
        guard !isWindowVisible else { return }

        appStateManager.savePreviousApp()
        ensureWindowCreated()
        windowLifecycle.configureWindowForDisplay(activeWindow!, windowHeight: unifiedWindowHeight())
        documentPreview.historyShown()
        windowLifecycle.displayWindow(activeWindow!) { [weak self] in
            self?.hideIfOutsideWorkspace()
        }
    }

    /// Starts a fresh example workspace without exposing real history.
    func restartTutorial() {
        tutorialHandoffTask?.cancel()
        tutorialHandoffTask = nil
        tutorial?.close()
        tutorial = nil
        onboarding.restart()
        showTutorial()
    }
    private func completeTutorial() {
        SystemCaptureService.shared.start()
        guard tutorialHandoffTask == nil else { return }
        guard let session = tutorial else {
            ClipboardMonitor.shared.resumeAfterTutorial()
            TextSelectionMonitor.shared.startMonitoring()
            showWindow()
            return
        }
        ensureWindowCreated()
        guard let model = sharedViewModel, let window = activeWindow else { return }
        tutorialHandoffTask = Task { [weak self, weak session] in
            await model.loadItems()
            guard let self, let session, !Task.isCancelled,
                  self.tutorial === session, self.onboarding.isComplete else { return }
            self.tutorialHandoffTask = nil
            guard session.isHistoryVisible else {
                session.close()
                self.tutorial = nil
                ClipboardMonitor.shared.resumeAfterTutorial()
                TextSelectionMonitor.shared.startMonitoring()
                return
            }
            let handoff = ClipboardHistoryHandoff(outgoingModel: session.historyModel) { [weak self, weak session] in
                guard let self, let session, self.tutorial === session else { return }
                session.close()
                self.tutorial = nil
                ClipboardMonitor.shared.resumeAfterTutorial()
                TextSelectionMonitor.shared.startMonitoring()
            }
            self.windowFactory.installContent(on: window, viewModel: model, handoff: handoff,
                onItemSelected: { [weak self] _ in self?.hideWindow() })
            window.setFrame(session.historyFrame, display: false)
            window.alphaValue = 1
            self.documentPreview.historyShown()
            window.makeKeyAndOrderFront(nil)
            session.concealForHandoff()
        }
    }
    private func showTutorial() {
        SystemCaptureService.shared.stop()
        activeWindow?.orderOut(nil)
        if activeWindow != nil { documentPreview.historyHidden() }
        ClipboardMonitor.shared.stopMonitoring()
        TextSelectionMonitor.shared.stopMonitoring()
        if tutorial == nil {
            tutorial = ClipboardTutorialSession(tour: onboarding,
                writer: NSPasteboardAdapter(monitor: .shared),
                onPaste: { [weak self] in
                    self?.hideWindow()
                    AutoPasteManager.shared.performAutoPaste()
                })
        }
        tutorial?.show()
    }

    /// 确保窗口已创建（双窗口池：A 和 B）
    private func ensureWindowCreated() {
        if windowA == nil || windowB == nil {
            // 确保 ViewModel 已创建
            if sharedViewModel == nil {
                sharedViewModel = ClipboardListViewModel(repository: repository, actions: historyActions, thumbnails: thumbnails)
            }

            // 使用 WindowFactory 创建窗口池（包含完整配置）
            let windowPair = windowFactory.createWindowPair(
                sharedViewModel: sharedViewModel!,
                onItemSelected: { [weak self] _ in
                    self?.hideWindow()
                }
            )
            self.windowA = windowPair.windowA
            self.windowB = windowPair.windowB
            workspace.register(windowPair.windowA)
            workspace.register(windowPair.windowB)

            // 配置窗口属性
            windowConfigurator.configurePanel(windowA!)
            windowConfigurator.configurePanel(windowB!)
        }

        if activeWindow == nil {
            activeWindow = windowA
        }
    }

    /// 统一窗口高度 = 搜索栏高度 + 间隔 + 卡片区域高度
    private func unifiedWindowHeight() -> CGFloat {
        layoutConfig.unifiedWindowHeight
    }

    /// 判断窗口是否可见
    private var isWindowVisible: Bool {
        return activeWindow?.isVisible == true
    }

    /// 隐藏窗口（对称的下滑 + 淡出动画）
    func hideWindow() {
        if tutorialHandoffTask != nil { tutorial?.hide() }
        if !onboarding.isComplete { tutorial?.hide(); return }
        guard let window = activeWindow else { return }
        documentPreview.historyHidden()
        windowLifecycle.hideWindow(window)
    }

    /// 隐藏窗口并激活前一个应用（用于粘贴场景，也使用对称动画）
    func hideWindowImmediately() {
        guard let window = activeWindow else { return }
        documentPreview.historyHidden()
        windowLifecycle.hideWindow(window) {
            self.appStateManager.activatePreviousApp()
        }
    }

    /// Explicit downward edge input uses the existing dismissal and draft protection.
    func dismissFromTrackpad() {
        guard tutorial?.isVisible == true || isWindowVisible else { return }
        hideWindow()
    }

    /// The physical top-edge gesture reveals the same workspace without toggling it closed.
    func revealFromTrackpad() {
        if onboarding.step == .launch {
            onboarding.launchRequested()
            showTutorial()
        } else {
            showWindow()
        }
    }

    /// Advances the tutorial only when its registered launch shortcut is actually pressed.
    func launchShortcutPressed() {
        if onboarding.step == .launch {
            onboarding.launchRequested()
            showTutorial()
        } else {
            toggleWindow()
        }
    }

    /// 切换窗口显示/隐藏
    func toggleWindow() {
        if !onboarding.isComplete {
            if tutorial?.isVisible == true { tutorial?.hide() } else { showTutorial() }
            return
        }
        if activeWindow?.isVisible == true {
            // 窗口已显示，检查鼠标是否在不同屏幕
            let mouseScreen = windowPositioner.detectActiveScreen()

            // 判断窗口当前在哪个屏幕（通过窗口中心点判断）
            let windowCenter = NSPoint(
                x: activeWindow!.frame.midX,
                y: activeWindow!.frame.midY
            )
            let currentScreen = NSScreen.screens.first { screen in
                screen.frame.contains(windowCenter)
            }

            if mouseScreen !== currentScreen && mouseScreen != nil {
                // 鼠标在不同屏幕，执行跨屏幕切换
                performCrossFadeTransition(to: mouseScreen!)
            } else {
                // 同一屏幕，正常隐藏
                hideWindow()
            }
        } else {
            showWindow()
        }
    }

    /// 执行跨屏幕切换（使用 A/B 窗口池，避免创建新窗口）
    private func performCrossFadeTransition(to targetScreen: NSScreen) {
        guard let oldWindow = activeWindow else { return }

        // 获取备用窗口（A/B 交替）
        let newWindow = (oldWindow === windowA) ? windowB! : windowA!

        // 更新活跃窗口引用（在动画开始前切换）
        activeWindow = newWindow

        // 使用 WindowLifecycle 执行跨屏幕切换动画
        windowLifecycle.performCrossFadeTransition(
            oldWindow: oldWindow,
            newWindow: newWindow,
            targetScreen: targetScreen,
            windowHeight: unifiedWindowHeight()
        ) {
            // 切换完成
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // 监听窗口失去 key 状态（更精确的控制）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowResignKey),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleApplicationActivated),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // 监听屏幕配置变化（外接屏幕连接/断开）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigurationChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleScreenConfigurationChange(_ notification: Notification) {
        windowPositioner.clearScreenCache()
        documentPreview.screenChanged()
    }

    @objc private func handleApplicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        DispatchQueue.main.async { [weak self] in self?.hideIfOutsideWorkspace() }
    }

    private func hideIfOutsideWorkspace() {
        let outsideApp = NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier
        if tutorialHandoffTask != nil {
            if outsideApp { tutorial?.hide() }
            return
        }
        if !onboarding.isComplete {
            if outsideApp { tutorial?.hide() }
            return
        }
        guard windowLifecycle.canAutoHide, !isPinned, !historyActions.isDragging,
              activeWindow?.isVisible == true,
              outsideApp || !workspace.hasKeyWindow else { return }
        hideWindow()
    }

    @objc private func handleWindowResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              workspace.contains(window) else { return }
        DispatchQueue.main.async { [weak self] in self?.hideIfOutsideWorkspace() }
    }
}
