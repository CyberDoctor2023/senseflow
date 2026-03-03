//
//  FloatingWindowManager.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Cocoa
import SwiftUI

/// 悬浮窗口管理器（单例）
class FloatingWindowManager {

    // MARK: - Singleton

    static let shared = FloatingWindowManager()

    // MARK: - Properties

    // 双窗口池架构：只有 A、B 两个窗口交替使用
    private var windowA: NSPanel?
    private var windowB: NSPanel?
    private var activeWindow: NSPanel?  // 当前活跃的窗口（A 或 B）

    private var sharedViewModel: ClipboardListViewModel?  // 共享 ViewModel（DI 模式，用于多窗口数据同步）
    private let repository: ClipboardRepositoryProtocol  // 数据仓库（依赖倒置）

    var isPinned = false  // 窗口是否固定（固定后失去焦点不会自动隐藏）

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

        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// 显示窗口
    func showWindow() {
        guard !isWindowVisible else { return }

        appStateManager.savePreviousApp()
        ensureWindowCreated()
        windowLifecycle.configureWindowForDisplay(activeWindow!, windowHeight: unifiedWindowHeight())
        windowLifecycle.displayWindow(activeWindow!)
    }

    /// 确保窗口已创建（双窗口池：A 和 B）
    private func ensureWindowCreated() {
        if windowA == nil || windowB == nil {
            // 确保 ViewModel 已创建
            if sharedViewModel == nil {
                sharedViewModel = ClipboardListViewModel(repository: repository)
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
        guard let window = activeWindow else { return }
        windowLifecycle.hideWindow(window)
    }

    /// 隐藏窗口并激活前一个应用（用于粘贴场景，也使用对称动画）
    func hideWindowImmediately() {
        guard let window = activeWindow else { return }
        windowLifecycle.hideWindow(window) {
            self.appStateManager.activatePreviousApp()
        }
    }

    /// 切换窗口显示/隐藏
    func toggleWindow() {
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
    }

    @objc private func handleWindowResignKey(_ notification: Notification) {
        // 处理窗口 A/B 的 resignKey
        guard let resignedWindow = notification.object as? NSWindow,
              (resignedWindow === windowA || resignedWindow === windowB),
              windowLifecycle.canAutoHide,
              !isPinned,  // 固定时不自动隐藏
              activeWindow?.isVisible == true else {
            return
        }

        // 同步检查：焦点是否转移到了我们的另一个窗口
        // 移除异步延迟，避免 glassEffect 降级导致的卡顿
        if let newKey = NSApp.keyWindow,
           (newKey === self.windowA || newKey === self.windowB) {
            return  // 焦点在我们窗口内部转移，不关闭
        }

        // 立即隐藏，避免视觉降级
        self.hideWindow()
    }
}
