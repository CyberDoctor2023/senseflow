//
//  HotKeyRegistry.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// 快捷键注册协议（Port）
protocol HotKeyRegistry: Sendable {
    /// 注册快捷键
    /// - Parameters:
    ///   - toolID: 工具 ID
    ///   - combo: 快捷键组合
    ///   - handler: 触发时的回调
    func register(toolID: ToolID, combo: KeyCombo, handler: @escaping @Sendable () -> Void) throws

    /// 注销快捷键
    func unregister(toolID: ToolID)

    /// 注销所有快捷键
    func unregisterAll()
}
