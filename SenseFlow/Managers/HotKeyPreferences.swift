//
//  HotKeyPreferences.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-16.
//

import Foundation
import Carbon
import KeyboardShortcuts

/// 快捷键配置结构
struct HotKeyConfig: Codable, Equatable {
    var keyCode: UInt32       // 虚拟键码
    var modifierFlags: UInt32 // Carbon 修饰键标志

    /// 默认快捷键：Cmd+Shift+V
    static var `default`: HotKeyConfig {
        HotKeyConfig(
            keyCode: 9,  // V key
            modifierFlags: UInt32(cmdKey) | UInt32(shiftKey)
        )
    }

    /// Smart 默认快捷键：Cmd+Ctrl+V
    static var smartDefault: HotKeyConfig {
        HotKeyConfig(
            keyCode: 9,  // V key
            modifierFlags: UInt32(cmdKey) | UInt32(controlKey)
        )
    }

    /// 获取快捷键显示文本
    var displayString: String {
        var parts: [String] = []

        // 修饰键符号
        if modifierFlags & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifierFlags & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifierFlags & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifierFlags & UInt32(cmdKey) != 0 { parts.append("⌘") }

        // 键名
        parts.append(keyCodeToString(keyCode))

        return parts.joined()
    }

    /// 将键码转换为可读字符串
    private func keyCodeToString(_ keyCode: UInt32) -> String {
        let keyCodeMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K",
            45: "N", 46: "M",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            25: "9", 26: "7", 28: "8", 29: "0",
            36: "⏎",
            48: "⇥",
            49: "Space",
            51: "⌫",
            53: "⎋",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return keyCodeMap[keyCode] ?? "?"
    }
}

/// 快捷键配置管理
class HotKeyPreferences {
    enum Kind {
        case main
        case smart

        fileprivate var storageKey: String {
            switch self {
            case .main:
                return UserDefaultsKeys.hotKeyConfig
            case .smart:
                return UserDefaultsKeys.smartHotKeyConfig
            }
        }

        fileprivate var defaultConfig: HotKeyConfig {
            switch self {
            case .main:
                return .default
            case .smart:
                return .smartDefault
            }
        }

        fileprivate var displayName: String {
            switch self {
            case .main:
                return "主快捷键"
            case .smart:
                return "Smart 快捷键"
            }
        }
    }

    /// 加载快捷键配置（默认主快捷键）
    static func load(kind: Kind = .main) -> HotKeyConfig {
        guard let data = UserDefaults.standard.data(forKey: kind.storageKey),
              let config = try? JSONDecoder().decode(HotKeyConfig.self, from: data) else {
            return kind.defaultConfig
        }
        return config
    }

    /// 保存快捷键配置（默认主快捷键）
    static func save(keyCode: UInt32, modifiers: UInt32, kind: Kind = .main) {
        let config = HotKeyConfig(keyCode: keyCode, modifierFlags: modifiers)
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: kind.storageKey)
            print("✅ \(kind.displayName)配置已保存: \(config.displayString)")
        }
    }

    /// 恢复默认快捷键（默认主快捷键）
    static func reset(kind: Kind = .main) {
        if let data = try? JSONEncoder().encode(kind.defaultConfig) {
            UserDefaults.standard.set(data, forKey: kind.storageKey)
            print("✅ \(kind.displayName)配置已恢复默认")
        }
    }

    /// 兼容旧调用：加载 Smart 快捷键
    static func loadSmart() -> HotKeyConfig {
        load(kind: .smart)
    }

    /// 兼容旧调用：保存 Smart 快捷键
    static func saveSmart(keyCode: UInt32, modifiers: UInt32) {
        save(keyCode: keyCode, modifiers: modifiers, kind: .smart)
    }

    /// 兼容旧调用：重置 Smart 快捷键
    static func resetSmart() {
        reset(kind: .smart)
    }
}

/// 快捷键设置事务：统一处理「保存 -> 重载注册 -> 失败回滚」
enum HotKeySettingsTransaction {
    struct Result {
        let success: Bool
        let config: HotKeyConfig
    }

    static func apply(kind: HotKeyPreferences.Kind, keyCode: UInt32, modifiers: UInt32) -> Result {
        let previousConfig = HotKeyPreferences.load(kind: kind)
        let newConfig = HotKeyConfig(keyCode: keyCode, modifierFlags: modifiers)
        guard newConfig != previousConfig else {
            return Result(success: true, config: previousConfig)
        }

        HotKeyPreferences.save(keyCode: keyCode, modifiers: modifiers, kind: kind)
        let savedConfig = HotKeyPreferences.load(kind: kind)
        guard reload(kind: kind) else {
            HotKeyPreferences.save(
                keyCode: previousConfig.keyCode,
                modifiers: previousConfig.modifierFlags,
                kind: kind
            )
            let rolledBack = HotKeyPreferences.load(kind: kind)
            _ = reload(kind: kind)
            return Result(success: false, config: rolledBack)
        }

        return Result(success: true, config: savedConfig)
    }

    static func resetToDefault(kind: HotKeyPreferences.Kind) -> Result {
        let defaultConfig = kind.defaultConfig
        return apply(
            kind: kind,
            keyCode: defaultConfig.keyCode,
            modifiers: defaultConfig.modifierFlags
        )
    }

    static func currentShortcut(kind: HotKeyPreferences.Kind) -> KeyboardShortcuts.Shortcut {
        let config = HotKeyPreferences.load(kind: kind)
        return HotKeyShortcutCodec.toShortcut(
            keyCode: config.keyCode,
            modifiers: config.modifierFlags
        )
    }

    private static func reload(kind: HotKeyPreferences.Kind) -> Bool {
        switch kind {
        case .main:
            return AppHotKeyCoordinator.shared.reloadMainHotKey()
        case .smart:
            return AppHotKeyCoordinator.shared.reloadSmartHotKey()
        }
    }
}
