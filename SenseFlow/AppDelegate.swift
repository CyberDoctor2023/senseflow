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

        // 初始化默认 Langfuse 密钥（首次启动时）
        initializeDefaultLangfuseKeys()

        // Initialize Langfuse tracing (must be first)
        _ = TracingService.shared

        // Removed: setupStatusBarItem() - now handled by MenuBarExtra

        // 初始化数据库（自动执行迁移）
        _ = DatabaseManager.shared

        // v0.2: 初始化 Prompt Tools（首次启动时创建默认工具）
        Task {
            try? await AppDependencies.shared.promptToolCoordinator.initializeDefaultToolsIfNeeded()
        }

        // v0.5: 启动 Langfuse 同步服务（如果已配置）
        if LangfuseSyncService.shared.isSyncEnabled {
            LangfuseSyncService.shared.startAutoSync()
        }

        // v0.4: 检查社区工具更新（可选）
        // checkToolUpdatesOnLaunch()

        // 启动剪贴板监听
        if FloatingWindowManager.shared.onboarding.isComplete {
            ClipboardMonitor.shared.startMonitoring()
            SystemCaptureService.shared.start()
        }

        // v0.5: 启动文本选择监听（划词即复制）
        if FloatingWindowManager.shared.onboarding.isComplete { TextSelectionMonitor.shared.startMonitoring() }

        // 注册全局快捷键
        setupHotKey()
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
        print("💡 新功能: Smart 推荐 + Gemini Vision 支持\n")
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

    /// 初始化默认 Langfuse 密钥（首次启动时）
    /// 密钥存储在 UserDefaults，不使用 Keychain（避免授权提示）
    private func initializeDefaultLangfuseKeys() {
        let publicKeyKey = "langfusePublicKey"
        let secretKeyKey = "langfuseSecretKey"

        // 检查是否已经设置过
        if UserDefaults.standard.string(forKey: publicKeyKey) != nil {
            print("ℹ️ Langfuse 密钥已存在，跳过初始化")
            return
        }

        // 设置默认密钥（用户需在设置中配置自己的密钥）
        let defaultPublicKey = ""
        let defaultSecretKey = ""

        UserDefaults.standard.set(defaultPublicKey, forKey: publicKeyKey)
        UserDefaults.standard.set(defaultSecretKey, forKey: secretKeyKey)

        print("✅ 已设置默认 Langfuse 密钥")
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

    // MARK: - HotKey Setup

    private func setupHotKey() {
        AppHotKeyCoordinator.shared.configureCallbacks(
            onMainHotKey: { [weak self] in
                self?.openHistory()
            },
            onSmartHotKey: { [weak self] in
                Task { @MainActor in
                    self?.handleSmartRecommendation()
                }
            }
        )

        Task { @MainActor in
            await AppHotKeyCoordinator.shared.registerAllHotKeys()
        }
    }

    /// Handle Smart recommendation workflow
    @MainActor
    private func handleSmartRecommendation() {
        print("✨ Smart hotkey triggered")

        Task {
            do {
                try await AppDependencies.shared.smartToolCoordinator.analyzeAndExecute()
            } catch {
                showSmartError(error)
                print("❌ Smart recommendation failed: \(error.localizedDescription)")
            }
        }
    }

    /// Show error alert
    private func showSmartError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Smart Recommendation Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Accessibility Permission

    private func checkAccessibilityPermission() {
        // 延迟 1 秒检查，避免启动时弹窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !AccessibilityManager.shared.checkAccessibilityPermission() {
                print("💡 提示: 授予辅助功能权限后，可以实现自动粘贴功能")
                // 首次启动时不强制弹窗，等用户点击卡片时再提示
            }
        }
    }

}
