//
//  KeyCombo.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// 快捷键组合值对象
struct KeyCombo: Equatable, Codable, Sendable {
    let keyCode: KeyCode
    let modifiers: KeyModifiers

    init(keyCode: KeyCode, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// 从原始值创建
    init?(keyCode: UInt16, modifiers: UInt32) {
        guard keyCode > 0 else { return nil }
        self.keyCode = KeyCode(keyCode)
        self.modifiers = KeyModifiers(rawValue: modifiers)
    }

    /// 显示字符串（如 "⌘⇧T"）
    var displayString: String {
        var result = ""

        if modifiers.contains(.command) { result += "⌘" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.control) { result += "⌃" }

        // 简化：这里只显示修饰键，实际应该映射 keyCode 到字符
        result += "[\(keyCode.value)]"

        return result
    }
}

/// 键码值对象
struct KeyCode: Equatable, Codable, Sendable {
    let value: UInt16

    init(_ value: UInt16) {
        precondition(value > 0, "KeyCode must be positive")
        self.value = value
    }
}

/// 修饰键
struct KeyModifiers: OptionSet, Codable, Sendable {
    let rawValue: UInt32

    static let command = KeyModifiers(rawValue: 1 << 0)
    static let shift = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let control = KeyModifiers(rawValue: 1 << 3)
}
