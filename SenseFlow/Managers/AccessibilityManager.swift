//
//  AccessibilityManager.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Cocoa
import ApplicationServices

/// Accessibility 权限管理器（单例）
class AccessibilityManager {

    // MARK: - Singleton

    static let shared = AccessibilityManager()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 检查是否已授予 Accessibility 权限
    func checkAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted {
            print("✅ Accessibility 权限已授予")
        } else {
            print("⚠️ Accessibility 权限未授予")
        }
        return trusted
    }

    /// 请求 Accessibility 权限（会弹出系统提示）
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            print("✅ Accessibility 权限已授予")
        } else {
            print("⚠️ 请在系统设置中授予 Accessibility 权限")
        }
    }

    /// 打开系统设置的 Accessibility 页面
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        print("🔓 已打开系统设置 - Accessibility")
    }

    /// 显示权限提示对话框
    func showPermissionAlert(completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = Strings.AccessibilityPermission.title
        alert.informativeText = Strings.AccessibilityPermission.message
        alert.alertStyle = .informational
        alert.addButton(withTitle: Strings.AccessibilityPermission.openSettings)
        alert.addButton(withTitle: Strings.AccessibilityPermission.later)

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // 用户点击"打开设置"
            openAccessibilitySettings()
            completion(false)
        } else {
            // 用户点击"稍后"
            completion(false)
        }
    }
}
