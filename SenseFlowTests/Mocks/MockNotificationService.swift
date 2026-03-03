//
//  MockNotificationService.swift
//  SenseFlowTests
//
//  Created on 2026-02-02.
//

import Foundation
@testable import SenseFlow

final class MockNotificationService: NotificationServiceProtocol {
    // 记录调用
    var showInProgressCallCount = 0
    var showSuccessCallCount = 0
    var showErrorCallCount = 0

    var lastInProgressTitle: String?
    var lastInProgressBody: String?

    var lastSuccessTitle: String?
    var lastSuccessBody: String?

    var lastErrorTitle: String?
    var lastErrorBody: String?

    func showInProgress(title: String, body: String) {
        showInProgressCallCount += 1
        lastInProgressTitle = title
        lastInProgressBody = body
    }

    func showSuccess(title: String, body: String) {
        showSuccessCallCount += 1
        lastSuccessTitle = title
        lastSuccessBody = body
    }

    func showError(title: String, body: String) {
        showErrorCallCount += 1
        lastErrorTitle = title
        lastErrorBody = body
    }

    // 便捷属性
    var didShowSuccess: Bool {
        return showSuccessCallCount > 0
    }

    var didShowError: Bool {
        return showErrorCallCount > 0
    }
}
