//
//  AppDelegate.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 不再设置 .accessory 策略，使用默认的 .regular
        // MenuBarExtra 会自动管理菜单栏图标

        // 注册 UserDefaults 默认值（必须在最开始）
        registerUserDefaultsDefaults()

        // 初始化默认 Langfuse 密钥（首次启动时）
        initializeDefaultLangfuseKeys()

        // Initialize Langfuse tracing (must be first)
        _ = TracingService.shared

        // 迁移旧的 UserDefaults 标志
        migrateOnboardingUserDefaults()

        // 首次启动：显示向导请求权限
        if !UserDefaults.standard.bool(forKey: "skipOnboardingPermissions") {
            showOnboardingWindow()
        }

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
        ClipboardMonitor.shared.startMonitoring()

        // v0.5: 启动文本选择监听（划词即复制）
        TextSelectionMonitor.shared.startMonitoring()

        // 注册全局快捷键
        setupHotKey()

        // 监听设置窗口打开通知（供浮动窗口齿轮按钮使用）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettingsWindow,
            object: nil
        )

        print("✅ \(AppConstants.productName) \(appVersion) 启动成功")
        print("\n💡 提示: 现在可以复制任意文本或图片，系统会自动保存到数据库")
        print("💡 按 Cmd+Option+V 打开历史窗口")
        print("💡 新功能: Smart 推荐 + Gemini Vision 支持\n")
    }

    func applicationWillTerminate(_ notification: Notification) {
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
        FloatingWindowManager.shared.toggleWindow()
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

    /// 迁移旧的 onboardingCompleted 标志到新的 skipOnboardingPermissions
    private func migrateOnboardingUserDefaults() {
        let defaults = UserDefaults.standard
        let oldKey = "onboardingCompleted"
        let newKey = "skipOnboardingPermissions"

        guard defaults.object(forKey: oldKey) != nil else { return }

        if defaults.bool(forKey: oldKey) {
            defaults.set(true, forKey: newKey)
            print("✅ UserDefaults 迁移: onboardingCompleted → skipOnboardingPermissions")
        }

        defaults.removeObject(forKey: oldKey)
    }

    private func checkAccessibilityPermission() {
        // 延迟 1 秒检查，避免启动时弹窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !AccessibilityManager.shared.checkAccessibilityPermission() {
                print("💡 提示: 授予辅助功能权限后，可以实现自动粘贴功能")
                // 首次启动时不强制弹窗，等用户点击卡片时再提示
            }
        }
    }

    // MARK: - Onboarding

    /// 显示 SwiftUI Onboarding 窗口
    func showOnboardingWindow() {
        print("🔧 [Debug] showOnboardingWindow() called")
        OnboardingWindowManager.shared.showWindow()
    }

    // MARK: - Database Test

    private func testDatabase() {
        print("\n🧪 开始测试数据库...")

        // 测试插入文本
        let success1 = DatabaseManager.shared.insertItem(
            type: .text,
            textContent: "测试文本 1",
            appName: "Xcode",
            appPath: "/Applications/Xcode.app"
        )
        print(success1 ? "✅ 插入文本成功" : "❌ 插入文本失败")

        // 测试插入重复文本（应该被去重）
        let success2 = DatabaseManager.shared.insertItem(
            type: .text,
            textContent: "测试文本 1",
            appName: "Xcode",
            appPath: "/Applications/Xcode.app"
        )
        print(success2 ? "❌ 去重失败" : "✅ 去重成功")

        // 测试插入另一条文本
        let success3 = DatabaseManager.shared.insertItem(
            type: .text,
            textContent: "测试文本 2",
            appName: "Safari",
            appPath: "/Applications/Safari.app"
        )
        print(success3 ? "✅ 插入文本成功" : "❌ 插入文本失败")

        // 查询所有记录
        let items = DatabaseManager.shared.fetchRecentItems()
        print("\n📊 当前记录数: \(items.count)")
        for item in items {
            print("  - [\(item.type.rawValue)] \(item.previewText) | \(item.appName) | \(item.relativeTimeString)")
        }

        print("\n✅ 数据库测试完成\n")
    }
}
