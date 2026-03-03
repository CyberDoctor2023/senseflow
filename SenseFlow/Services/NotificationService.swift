//
//  NotificationService.swift
//  SenseFlow
//
//  Created on 2026-01-19.
//

import Foundation
import UserNotifications

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
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            if granted {
                print("✅ 通知权限已授予")
            } else {
                print("⚠️ 用户拒绝了通知权限")
            }
        } catch {
            print("❌ 通知权限请求失败: \(error.localizedDescription)")
        }
    }

    /// 检查通知权限状态（async）
    /// - Returns: 是否已授权
    func checkPermission() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
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
        return status == .authorized
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
}
