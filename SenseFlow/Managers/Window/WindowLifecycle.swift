//
//  WindowLifecycle.swift
//  SenseFlow
//
//  Created on 2026-02-11.
//

import Cocoa

/// 窗口生命周期管理器：负责窗口的显示、隐藏、切换逻辑
/// 职责：控制窗口的显示/隐藏动画、跨屏幕切换、自动隐藏延迟
final class WindowLifecycle {

    private let windowConfigurator: WindowConfigurator
    private let windowPositioner: WindowPositioner
    private let layoutConfig: WindowLayoutConfigurable

    private var shouldAutoHide = true  // 是否应该自动隐藏（防止刚显示就隐藏）
    private var isTransitioning = false  // 防止递归切换
    private var isHiding = false  // 是否正在执行隐藏动画（防止动画期间重复触发）

    // 自动隐藏延迟：等于动画时长，确保动画完成后立即允许自动隐藏
    private let autoHideDelay: TimeInterval = FloatingWindowAnimator.duration

    init(
        windowConfigurator: WindowConfigurator,
        windowPositioner: WindowPositioner,
        layoutConfig: WindowLayoutConfigurable
    ) {
        self.windowConfigurator = windowConfigurator
        self.windowPositioner = windowPositioner
        self.layoutConfig = layoutConfig
    }

    /// 配置窗口显示参数
    func configureWindowForDisplay(_ window: NSPanel, windowHeight: CGFloat) {
        // 使用 .popUpMenu 层级：专门设计用于显示在 Dock 之上
        window.level = .popUpMenu

        // 动态调整窗口尺寸和位置（支持多显示器）
        windowPositioner.resizeAndPositionWindow(window, windowHeight: windowHeight)
        shouldAutoHide = false
    }

    /// 显示窗口并激活
    func displayWindow(_ window: NSPanel, completion: (() -> Void)? = nil) {
        // 重置隐藏状态
        isHiding = false

        // 提前触发数据加载（后台线程，不阻塞动画）
        NotificationCenter.default.post(name: .windowWillShow, object: nil)

        // 单窗口滑入并获取焦点
        FloatingWindowAnimator.animateSlideIn(window: window)

        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay) { [weak self] in
            self?.shouldAutoHide = true
            completion?()
        }
    }

    /// 隐藏窗口（对称的下滑 + 淡出动画）
    func hideWindow(_ window: NSPanel, completion: (() -> Void)? = nil) {
        guard window.isVisible else { return }
        guard !isHiding else { return }  // 防止动画期间重复触发

        isHiding = true
        FloatingWindowAnimator.animateSlideOut(window: window) { [weak self] in
            self?.isHiding = false
            completion?()
        }
    }

    /// 执行跨屏幕切换（使用 A/B 窗口池，避免创建新窗口）
    func performCrossFadeTransition(
        oldWindow: NSPanel,
        newWindow: NSPanel,
        targetScreen: NSScreen,
        windowHeight: CGFloat,
        completion: @escaping () -> Void
    ) {
        guard !isTransitioning else { return }

        isTransitioning = true

        // 计算新窗口位置（目标屏幕）
        let newFrame = windowPositioner.calculateWindowFrame(for: targetScreen, windowHeight: windowHeight)
        newWindow.setFrame(newFrame, display: false)
        newWindow.level = .popUpMenu

        // 旧窗口滑出
        FloatingWindowAnimator.animateSlideOut(window: oldWindow)

        // 新窗口滑入
        FloatingWindowAnimator.animateSlideIn(window: newWindow) { [weak self] in
            self?.isTransitioning = false
            completion()
        }
    }

    /// 获取自动隐藏状态
    var canAutoHide: Bool {
        return shouldAutoHide && !isTransitioning && !isHiding
    }

    /// 重置自动隐藏状态
    func resetAutoHideState() {
        shouldAutoHide = false
    }
}
