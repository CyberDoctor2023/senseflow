//
//  RegisterToolHotKey.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// 注册工具快捷键用例
/// 职责：管理工具快捷键的注册和注销
final class RegisterToolHotKey: Sendable {
    private let hotKeyRegistry: HotKeyRegistry

    init(hotKeyRegistry: HotKeyRegistry) {
        self.hotKeyRegistry = hotKeyRegistry
    }

    /// 注册快捷键
    /// - Parameters:
    ///   - tool: 工具
    ///   - handler: 触发时的回调
    func register(tool: PromptTool, handler: @escaping @Sendable () -> Void) throws {
        guard let combo = tool.keyCombo else {
            // 工具没有快捷键，跳过
            return
        }

        try hotKeyRegistry.register(
            toolID: tool.toolID,
            combo: combo,
            handler: handler
        )
    }

    /// 注销快捷键
    func unregister(toolID: ToolID) {
        hotKeyRegistry.unregister(toolID: toolID)
    }

    /// 注销所有快捷键
    func unregisterAll() {
        hotKeyRegistry.unregisterAll()
    }
}
