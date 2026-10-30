//
//  HotKeyManager.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Cocoa
import Carbon
import KeyboardShortcuts

enum HotKeyNames {
    static let main = KeyboardShortcuts.Name("main_history_window_toggle")
    static let conflictTest = KeyboardShortcuts.Name("hotkey_conflict_test")

}

enum HotKeyShortcutCodec {
    static func toShortcut(keyCode: UInt32, modifiers: UInt32) -> KeyboardShortcuts.Shortcut {
        KeyboardShortcuts.Shortcut(
            carbonKeyCode: Int(keyCode),
            carbonModifiers: Int(modifiers)
        )
    }

    static func toShortcut(keyCode: UInt16, modifiers: UInt32) -> KeyboardShortcuts.Shortcut {
        toShortcut(keyCode: UInt32(keyCode), modifiers: modifiers)
    }

    static func toCarbon(_ shortcut: KeyboardShortcuts.Shortcut) -> (keyCode: UInt32, modifiers: UInt32) {
        (
            keyCode: UInt32(shortcut.carbonKeyCode),
            modifiers: UInt32(shortcut.carbonModifiers)
        )
    }
}

/// 全局快捷键管理器（单例）
class HotKeyManager {

    // MARK: - Singleton

    static let shared = HotKeyManager()

    // MARK: - Properties

    // 主窗口快捷键
    private var mainShortcut: KeyboardShortcuts.Shortcut?
    private var mainHotKeyTask: Task<Void, Never>?

    // 回调闭包
    var onHotKeyPressed: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 注册全局快捷键
    func registerHotKey() -> Bool {
        unregisterHotKey()

        let config = HotKeyPreferences.load()
        return registerMainHotKey(config: config)
    }

    /// 注册主窗口快捷键
    private func registerMainHotKey(config: HotKeyConfig) -> Bool {
        let shortcut = HotKeyShortcutCodec.toShortcut(keyCode: config.keyCode, modifiers: config.modifierFlags)

        if isShortcutUsedInternally(shortcut) {
            showConflictAlert(hotKeyDisplay: config.displayString)
            return false
        }

        KeyboardShortcuts.setShortcut(shortcut, for: HotKeyNames.main)
        mainHotKeyTask?.cancel()
        mainHotKeyTask = createKeyUpObserver(for: HotKeyNames.main) { [weak self] in
            self?.onHotKeyPressed?()
        }

        guard KeyboardShortcuts.isEnabled(for: HotKeyNames.main) else {
            mainHotKeyTask?.cancel()
            mainHotKeyTask = nil
            KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.main)
            print("❌ 注册主快捷键失败")
            showConflictAlert(hotKeyDisplay: config.displayString)
            return false
        }

        mainShortcut = shortcut
        print("✅ 全局快捷键已注册: \(config.displayString)")
        return true
    }

    /// 注销全局快捷键
    func unregisterHotKey() {
        mainHotKeyTask?.cancel()
        mainHotKeyTask = nil
        mainShortcut = nil
        KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.main)
        print("🔓 全局快捷键已注销")
    }

    /// 显示快捷键冲突警告对话框
    private func showConflictAlert(hotKeyDisplay: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = Strings.HotKeyConflict.title
            alert.informativeText = Strings.HotKeyConflict.message(hotKeyDisplay)
            alert.alertStyle = .warning
            alert.addButton(withTitle: Strings.Buttons.confirm)
            alert.runModal()
        }
    }

    /// 检测快捷键是否已被占用
    /// - Parameters:
    ///   - keyCode: 虚拟键码
    ///   - modifiers: 修饰键标志
    /// - Returns: 如果冲突返回 true
    func isHotKeyConflicted(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let shortcut = HotKeyShortcutCodec.toShortcut(keyCode: keyCode, modifiers: modifiers)
        return isHotKeyConflicted(shortcut: shortcut)
    }

    private func isShortcutUsedInternally(_ shortcut: KeyboardShortcuts.Shortcut) -> Bool {
        mainShortcut == shortcut
    }

    private func isHotKeyConflicted(shortcut: KeyboardShortcuts.Shortcut) -> Bool {
        if isShortcutUsedInternally(shortcut) { return true }
        KeyboardShortcuts.setShortcut(shortcut, for: HotKeyNames.conflictTest)
        let enabled = KeyboardShortcuts.isEnabled(for: HotKeyNames.conflictTest)
        KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.conflictTest)
        return !enabled
    }

    private func createKeyUpObserver(
        for name: KeyboardShortcuts.Name,
        action: @escaping () -> Void
    ) -> Task<Void, Never> {
        Task {
            for await _ in KeyboardShortcuts.events(.keyUp, for: name) {
                await MainActor.run {
                    action()
                }
            }
        }
    }

    // MARK: - Deinit

    deinit {
        unregisterHotKey()
    }
}

/// Owns the application's history shortcut registration.
final class AppHotKeyCoordinator: @unchecked Sendable {
    static let shared = AppHotKeyCoordinator()
    private init() {}
    func configureCallbacks(onMainHotKey: @escaping () -> Void) {
        HotKeyManager.shared.onHotKeyPressed = onMainHotKey
    }
    func registerAllHotKeys() async { _ = HotKeyManager.shared.registerHotKey() }
    func unregisterAllHotKeys() { HotKeyManager.shared.unregisterHotKey() }
    @discardableResult func reloadMainHotKey() -> Bool { HotKeyManager.shared.registerHotKey() }
    func isHotKeyConflicted(keyCode: UInt32, modifiers: UInt32) -> Bool {
        HotKeyManager.shared.isHotKeyConflicted(keyCode: keyCode, modifiers: modifiers)
    }
}
