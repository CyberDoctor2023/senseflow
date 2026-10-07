//
//  AppStateManager.swift
//  SenseFlow
//
//  Created on 2026-02-11.
//

import Cocoa

/// 应用状态管理器：负责管理前一个活跃应用的状态
/// 职责：保存和恢复前一个应用的焦点
final class AppStateManager {

    private var previousApp: NSRunningApplication?  // 记录显示窗口前的活跃应用

    /// 保存前一个活跃应用
    func savePreviousApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    /// 激活前一个应用
    func activatePreviousApp() {
        guard let app = previousApp, !app.isTerminated else { return }
        app.activate()
    }

    /// 清除前一个应用的引用
    func clearPreviousApp() {
        previousApp = nil
    }
}
