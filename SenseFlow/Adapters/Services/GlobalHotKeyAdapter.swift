//
//  GlobalHotKeyAdapter.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// 全局快捷键适配器
/// 职责：将 Domain 的 HotKeyRegistry 协议适配到 HotKeyManager
final class GlobalHotKeyAdapter: HotKeyRegistry {
    private let hotKeyManager: HotKeyManager

    init(hotKeyManager: HotKeyManager) {
        self.hotKeyManager = hotKeyManager
    }

    func register(toolID: ToolID, combo: KeyCombo, handler: @escaping @Sendable () -> Void) throws {
        let success = hotKeyManager.registerToolHotKey(
            toolID: toolID.value,
            keyCode: UInt32(combo.keyCode.value),
            modifiers: combo.modifiers.rawValue,
            callback: handler
        )

        if !success {
            throw HotKeyError.registrationFailed
        }
    }

    func unregister(toolID: ToolID) {
        hotKeyManager.unregisterToolHotKey(toolID: toolID.value)
    }

    func unregisterAll() {
        hotKeyManager.unregisterAllToolHotKeys()
    }
}

// MARK: - Errors

enum HotKeyError: LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "快捷键注册失败"
        }
    }
}
