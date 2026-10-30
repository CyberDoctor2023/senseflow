//
//  AppDelegate.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Cocoa
import SwiftUI

@MainActor class AppDelegate: NSObject, NSApplicationDelegate {

    private let sessionDiagnostics = SessionDiagnostics()
    private var terminationPending = false
    private let trackpadReveal = TrackpadRevealMonitor.shared

    // MARK: - Properties

    // Removed: statusItem and contextMenu (now managed by SwiftUI MenuBarExtra)

    /// 应用版本号（从 Info.plist 读取）
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "v\(version)"
        }
        return "v0.0.0"
    }

    // MARK: - Application Lifecycle

    /// Restores the current workspace when macOS reopens an app whose panel is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { FloatingWindowManager.shared.showWindow() }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        sessionDiagnostics.beginSession()
        // 不再设置 .accessory 策略，使用默认的 .regular
        // MenuBarExtra 会自动管理菜单栏图标

        // 注册 UserDefaults 默认值（必须在最开始）
        registerUserDefaultsDefaults()
        AppUpdateService.shared.start()

        // Removed: setupStatusBarItem() - now handled by MenuBarExtra

        // 初始化数据库（自动执行迁移）
        _ = DatabaseManager.shared

        // 启动剪贴板监听
        if FloatingWindowManager.shared.onboarding.isComplete {
            ClipboardMonitor.shared.startMonitoring()
            SystemCaptureService.shared.start()
        }

        // v0.5: 启动文本选择监听（划词即复制）
        if FloatingWindowManager.shared.onboarding.isComplete { TextSelectionMonitor.shared.startMonitoring() }

        // 注册全局快捷键
        AppHotKeyCoordinator.shared.configureCallbacks(onMainHotKey: { [weak self] in self?.openHistory() })
        Task { await AppHotKeyCoordinator.shared.registerAllHotKeys() }
        trackpadReveal.start { gesture in
            switch gesture {
            case .reveal: FloatingWindowManager.shared.revealFromTrackpad()
            case .dismiss: FloatingWindowManager.shared.dismissFromTrackpad()
            }
        }
        if !FloatingWindowManager.shared.onboarding.isComplete {
            DispatchQueue.main.async { FloatingWindowManager.shared.showWindow() }
        }

        // 监听设置窗口打开通知（供浮动窗口齿轮按钮使用）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettingsWindow,
            object: nil
        )

        print("✅ \(AppConstants.productName) \(appVersion) 启动成功")
        print("\n💡 提示: 现在可以复制任意文本或图片，系统会自动保存到数据库")
        print("💡 使用 \(HotKeyPreferences.load().displayString) 打开历史窗口")

    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationPending else { return .terminateLater }
        terminationPending = true
        Task { @MainActor in
            let allowed = await FloatingWindowManager.shared.documentPreview.prepareToClose()
            terminationPending = false
            sender.reply(toApplicationShouldTerminate: allowed)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        SystemCaptureService.shared.stop()
        trackpadReveal.stop()
        sessionDiagnostics.finishSession()
        // 停止剪贴板监听
        ClipboardMonitor.shared.stopMonitoring()

        // v0.5: 停止文本选择监听
        TextSelectionMonitor.shared.stopMonitoring()

        // 注销快捷键
        AppHotKeyCoordinator.shared.unregisterAllHotKeys()

        print("👋 \(AppConstants.productName) 退出")
    }

    // MARK: - Initialization

    /// 注册 UserDefaults 默认值
    private func registerUserDefaultsDefaults() {
        let defaults: [String: Any] = [
            UserDefaultsKeys.textSelectionAutoCopyEnabled: false,
            UserDefaultsKeys.textSelectionMinLength: 3,
            UserDefaultsKeys.textSelectionForcedExtractionEnabled: false
        ]
        UserDefaults.standard.register(defaults: defaults)
        print("✅ UserDefaults 默认值已注册")
    }

    // MARK: - Actions (Called from MenuBarContentView)

    @objc func openHistory() {
        print("📋 快捷键触发：打开历史窗口")
        FloatingWindowManager.shared.launchShortcutPressed()
    }

    /// 处理打开设置窗口通知（供浮动窗口齿轮按钮使用）
    @objc private func handleOpenSettings() {
        // 查找已有的设置窗口并激活
        for window in NSApp.windows where window.title == "设置" {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
    }

}
