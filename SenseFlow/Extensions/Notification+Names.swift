//
//  Notification+Names.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//

import Foundation

/// 应用通知名称定义
extension Notification.Name {
    /// 剪贴板内容更新通知
    static let clipboardDidUpdate = Notification.Name("clipboardDidUpdate")

    /// 窗口即将显示通知
    static let windowWillShow = Notification.Name("windowWillShow")

    /// 窗口即将隐藏通知
    static let windowWillHide = Notification.Name("windowWillHide")

    /// 打开设置窗口通知
    static let openSettingsWindow = Notification.Name("openSettingsWindow")
}
