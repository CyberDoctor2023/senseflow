//
//  NotificationService.swift
//  SenseFlow
//
//  Created on 2026-01-19.
//

import Foundation
import Cocoa
import UserNotifications
import ApplicationServices
import CoreGraphics

/// 通知服务管理器（单例）
/// 负责显示系统通知
class NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Properties

    private let center = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private init() {
        // 不在 init 中请求权限，由需要时手动调用
    }

    // MARK: - Public Methods

    /// 请求通知权限
    @MainActor
    func requestAuthorization() async {
        // 菜单栏应用在非激活态下可能导致权限弹窗不出现，先激活应用
        NSApp.activate(ignoringOtherApps: true)

        let settings = await center.notificationSettings()
        print("🔔 通知权限当前状态: \(statusText(settings.authorizationStatus))")

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    print("✅ 通知权限已授予")
                } else {
                    print("⚠️ 用户拒绝了通知权限")
                    await MainActor.run {
                        showPermissionAlert()
                    }
                }
            } catch {
                print("❌ 通知权限请求失败: \(error.localizedDescription)")
            }

        case .denied:
            print("⚠️ 通知权限状态为 denied，系统不会重复弹窗")
            await MainActor.run {
                showPermissionAlert()
            }

        case .authorized, .provisional:
            print("✅ 通知权限已可用（状态: \(settings.authorizationStatus.rawValue)）")

        @unknown default:
            print("⚠️ 未知通知权限状态: \(settings.authorizationStatus.rawValue)")
        }

        PermissionStatusCoordinator.shared.refreshNow()
    }

    /// 检查通知权限状态（async）
    /// - Returns: 是否已授权
    func checkPermission() async -> Bool {
        let settings = await center.notificationSettings()
        return isAuthorized(settings.authorizationStatus)
    }

    /// 检查通知权限状态（同步属性）
    /// - Note: 使用缓存状态，可能不是最新值
    var hasPermission: Bool {
        var status: UNAuthorizationStatus = .notDetermined
        let semaphore = DispatchSemaphore(value: 0)

        center.getNotificationSettings { settings in
            status = settings.authorizationStatus
            semaphore.signal()
        }

        semaphore.wait()
        return isAuthorized(status)
    }

    /// 显示通知
    /// - Parameters:
    ///   - title: 标题
    ///   - body: 内容
    ///   - identifier: 唯一标识符（可选）
    func showNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // 立即显示
        )

        center.add(request) { error in
            if let error = error {
                print("❌ 显示通知失败: \(error.localizedDescription)")
            }
        }
    }

    /// 显示成功通知
    /// - Parameters:
    ///   - title: 标题
    ///   - body: 内容
    func showSuccess(title: String, body: String = "") {
        showNotification(title: "✅ \(title)", body: body)
    }

    /// 显示错误通知
    /// - Parameters:
    ///   - title: 标题
    ///   - body: 错误详情
    func showError(title: String, body: String = "") {
        showNotification(title: "❌ \(title)", body: body)
    }

    /// 显示进行中通知
    /// - Parameters:
    ///   - title: 标题
    ///   - body: 内容
    func showInProgress(title: String, body: String = "") {
        showNotification(title: "⏳ \(title)", body: body)
    }

    /// 移除所有通知
    func removeAllNotifications() {
        center.removeAllDeliveredNotifications()
    }

    /// 移除指定通知
    /// - Parameter identifier: 通知标识符
    func removeNotification(identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Private Helpers

    @MainActor
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "通知权限未授予"
        alert.informativeText = "系统已记录你之前的选择，macOS 不会重复弹出通知授权。请在系统设置中手动开启 SenseFlow 的通知权限。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            openNotificationSettings()
        }
    }

    @MainActor
    private func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]

        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                print("🔓 已打开系统设置 - 通知")
                return
            }
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        print("🔓 已打开系统设置")
    }

    private func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional
    }

    private func statusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .provisional:
            return "provisional"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }
}

// MARK: - Unified Permission Status

/// App 权限状态快照
struct PermissionStatusSnapshot: Equatable {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
    let notificationGranted: Bool

    static let empty = PermissionStatusSnapshot(
        accessibilityGranted: false,
        screenRecordingGranted: false,
        notificationGranted: false
    )
}

/// 权限状态接口（用于统一引导页和设置页读取机制）
protocol PermissionStatusProviding {
    /// 读取当前系统权限状态快照
    func currentStatus() async -> PermissionStatusSnapshot
}

/// 系统权限状态实现
final class SystemPermissionStatusProvider: PermissionStatusProviding {
    func currentStatus() async -> PermissionStatusSnapshot {
        let notificationGranted = await NotificationService.shared.checkPermission()
        return PermissionStatusSnapshot(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess(),
            notificationGranted: notificationGranted
        )
    }
}

/// 权限状态协调器（共享给 Onboarding/Settings）
/// - Onboarding: 高频轮询（交互期）
/// - Settings: 事件驱动刷新（应用重新激活时）
@MainActor
final class PermissionStatusCoordinator: ObservableObject {
    enum Consumer {
        case onboarding
        case settings
    }

    static let shared = PermissionStatusCoordinator(provider: SystemPermissionStatusProvider())

    @Published private(set) var snapshot: PermissionStatusSnapshot = .empty

    private let provider: PermissionStatusProviding
    private var timer: Timer?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    private var onboardingSubscribers = 0
    private var settingsSubscribers = 0
    private var isRefreshing = false

    init(provider: PermissionStatusProviding) {
        self.provider = provider
    }

    /// 订阅权限状态（进入页面时调用）
    func start(consumer: Consumer) {
        switch consumer {
        case .onboarding:
            onboardingSubscribers += 1
        case .settings:
            settingsSubscribers += 1
        }

        configureRefreshStrategy()
        refreshNow()
    }

    /// 取消订阅权限状态（离开页面时调用）
    func stop(consumer: Consumer) {
        switch consumer {
        case .onboarding:
            onboardingSubscribers = max(0, onboardingSubscribers - 1)
        case .settings:
            settingsSubscribers = max(0, settingsSubscribers - 1)
        }

        configureRefreshStrategy()
    }

    /// 手动触发一次权限状态刷新
    func refreshNow() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task { [weak self] in
            guard let self else { return }
            let latest = await provider.currentStatus()
            await MainActor.run {
                self.snapshot = latest
                self.isRefreshing = false
            }
        }
    }

    private var hasSubscribers: Bool {
        onboardingSubscribers > 0 || settingsSubscribers > 0
    }

    private func configureRefreshStrategy() {
        if !hasSubscribers {
            stopTimer()
            removeAppActiveObserver()
            return
        }

        ensureAppActiveObserver()

        if onboardingSubscribers > 0 {
            startTimerIfNeeded(interval: BusinessRules.Permissions.checkInterval)
        } else {
            stopTimer()
        }
    }

    private func startTimerIfNeeded(interval: TimeInterval) {
        guard timer == nil else { return }
        let created = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }
        // 为系统调度留出余量，降低能耗
        created.tolerance = max(0.1, interval * 0.2)
        timer = created
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func ensureAppActiveObserver() {
        guard appDidBecomeActiveObserver == nil else { return }
        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }
    }

    private func removeAppActiveObserver() {
        guard let observer = appDidBecomeActiveObserver else { return }
        NotificationCenter.default.removeObserver(observer)
        appDidBecomeActiveObserver = nil
    }
}
