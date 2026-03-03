//
//  UserNotificationAdapter.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// UserNotification 适配器
/// 职责：将 Domain 的 NotificationService 协议适配到现有的 NotificationService.shared
final class UserNotificationAdapter: NotificationServiceProtocol {
    private let notificationService: SenseFlow.NotificationService

    init(notificationService: SenseFlow.NotificationService) {
        self.notificationService = notificationService
    }

    func showInProgress(title: String, body: String) {
        notificationService.showInProgress(title: title, body: body)
    }

    func showSuccess(title: String, body: String) {
        notificationService.showSuccess(title: title, body: body)
    }

    func showError(title: String, body: String) {
        notificationService.showError(title: title, body: body)
    }
}
