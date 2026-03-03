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
    static let smart = KeyboardShortcuts.Name("smart_recommendation_toggle")
    static let conflictTest = KeyboardShortcuts.Name("hotkey_conflict_test")

    // UI-only recorder name for prompt tool editor.
    static let toolEditorRecorder = KeyboardShortcuts.Name("tool_editor_hotkey_recorder")

    static func tool(_ id: UUID) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name("tool_\(id.uuidString.lowercased())")
    }
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

    // Prompt Tool 快捷键管理
    private var toolShortcuts: [UUID: KeyboardShortcuts.Shortcut] = [:]
    private var toolHotKeyTasks: [UUID: Task<Void, Never>] = [:]

    // Smart 快捷键管理
    private var smartShortcut: KeyboardShortcuts.Shortcut?
    private var smartHotKeyTask: Task<Void, Never>?
    var onSmartHotKeyPressed: (() -> Void)?

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
        return isHotKeyConflicted(shortcut: shortcut, excludingToolID: nil)
    }

    /// 检测 Tool 快捷键是否冲突（会忽略自身已注册快捷键）
    func isToolHotKeyConflicted(toolID: UUID, keyCode: UInt32, modifiers: UInt32) -> Bool {
        let shortcut = HotKeyShortcutCodec.toShortcut(keyCode: keyCode, modifiers: modifiers)
        return isHotKeyConflicted(shortcut: shortcut, excludingToolID: toolID)
    }

    // MARK: - Tool HotKey Management

    /// Register Smart hotkey
    /// - Parameters:
    ///   - keyCode: Virtual key code (default: kVKANSIKeyV = 9)
    ///   - modifiers: Modifier flags (default: Cmd+Ctrl = cmdKey + controlKey)
    /// - Returns: Whether registration succeeded
    func registerSmartHotKey(keyCode: UInt32 = 9, modifiers: UInt32 = UInt32(cmdKey + controlKey)) -> Bool {
        unregisterSmartHotKey()

        let shortcut = HotKeyShortcutCodec.toShortcut(keyCode: keyCode, modifiers: modifiers)
        if isShortcutUsedInternally(shortcut) {
            print("⚠️ Smart 快捷键已被占用（应用内冲突）")
            return false
        }

        KeyboardShortcuts.setShortcut(shortcut, for: HotKeyNames.smart)
        smartHotKeyTask?.cancel()
        smartHotKeyTask = createKeyUpObserver(for: HotKeyNames.smart) { [weak self] in
            self?.onSmartHotKeyPressed?()
        }

        guard KeyboardShortcuts.isEnabled(for: HotKeyNames.smart) else {
            smartHotKeyTask?.cancel()
            smartHotKeyTask = nil
            KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.smart)
            print("❌ Smart 快捷键注册失败")
            return false
        }

        smartShortcut = shortcut
        print("✅ Smart 快捷键已注册")
        return true
    }

    /// Unregister Smart hotkey
    func unregisterSmartHotKey() {
        smartHotKeyTask?.cancel()
        smartHotKeyTask = nil
        smartShortcut = nil
        KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.smart)
        print("🔓 Smart 快捷键已注销")
    }

    // MARK: - Tool HotKey Management

    /// 注册 Tool 快捷键
    /// - Parameters:
    ///   - toolID: Tool 的 UUID
    ///   - keyCode: 虚拟键码
    ///   - modifiers: 修饰键标志
    ///   - callback: 触发时的回调
    /// - Returns: 是否注册成功
    func registerToolHotKey(toolID: UUID, keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) -> Bool {
        unregisterToolHotKey(toolID: toolID)

        let shortcut = HotKeyShortcutCodec.toShortcut(keyCode: keyCode, modifiers: modifiers)
        guard !isShortcutUsedInternally(shortcut, excludingToolID: toolID) else {
            print("⚠️ Tool 快捷键已被占用（应用内冲突）")
            return false
        }

        let shortcutName = HotKeyNames.tool(toolID)
        KeyboardShortcuts.setShortcut(shortcut, for: shortcutName)

        let observerTask = createKeyUpObserver(for: shortcutName) {
            callback()
        }

        guard KeyboardShortcuts.isEnabled(for: shortcutName) else {
            observerTask.cancel()
            KeyboardShortcuts.setShortcut(nil, for: shortcutName)
            print("❌ Tool 快捷键注册失败")
            return false
        }

        toolShortcuts[toolID] = shortcut
        toolHotKeyTasks[toolID] = observerTask
        print("✅ Tool 快捷键已注册: \(toolID)")
        return true
    }

    /// 注销 Tool 快捷键
    /// - Parameter toolID: Tool 的 UUID
    func unregisterToolHotKey(toolID: UUID) {
        toolHotKeyTasks[toolID]?.cancel()
        toolHotKeyTasks.removeValue(forKey: toolID)
        toolShortcuts.removeValue(forKey: toolID)
        KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.tool(toolID))
        print("🔓 Tool 快捷键已注销: \(toolID)")
    }

    /// 注销所有 Tool 快捷键
    func unregisterAllToolHotKeys() {
        for toolID in toolHotKeyTasks.keys {
            toolHotKeyTasks[toolID]?.cancel()
            KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.tool(toolID))
            print("🔓 Tool 快捷键已注销: \(toolID)")
        }
        toolHotKeyTasks.removeAll()
        toolShortcuts.removeAll()
    }

    // MARK: - Helpers

    private func isShortcutUsedInternally(_ shortcut: KeyboardShortcuts.Shortcut, excludingToolID: UUID? = nil) -> Bool {
        if mainShortcut == shortcut {
            return true
        }

        if smartShortcut == shortcut {
            return true
        }

        for (toolID, existingShortcut) in toolShortcuts where toolID != excludingToolID {
            if existingShortcut == shortcut {
                return true
            }
        }

        return false
    }

    private func isHotKeyConflicted(shortcut: KeyboardShortcuts.Shortcut, excludingToolID: UUID?) -> Bool {
        if isShortcutUsedInternally(shortcut, excludingToolID: excludingToolID) {
            return true
        }

        KeyboardShortcuts.setShortcut(shortcut, for: HotKeyNames.conflictTest)
        let isEnabled = KeyboardShortcuts.isEnabled(for: HotKeyNames.conflictTest)
        KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.conflictTest)
        return !isEnabled
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
        unregisterSmartHotKey()
        unregisterAllToolHotKeys()
    }
}

/// 应用级快捷键编排器
/// 统一管理主窗口 / Smart / Tool 三类快捷键注册流程，避免业务入口分散。
final class AppHotKeyCoordinator: @unchecked Sendable {
    static let shared = AppHotKeyCoordinator()

    private let hotKeyManager: HotKeyManager

    private init(hotKeyManager: HotKeyManager = .shared) {
        self.hotKeyManager = hotKeyManager
    }

    func configureCallbacks(
        onMainHotKey: @escaping () -> Void,
        onSmartHotKey: @escaping () -> Void
    ) {
        hotKeyManager.onHotKeyPressed = onMainHotKey
        hotKeyManager.onSmartHotKeyPressed = onSmartHotKey
    }

    /// 应用启动时统一注册所有快捷键
    func registerAllHotKeys() async {
        _ = registerMainHotKey()
        _ = registerSmartHotKey()
        try? await AppDependencies.shared.promptToolCoordinator.registerAllHotKeys()
    }

    /// 应用退出时统一注销所有快捷键
    func unregisterAllHotKeys() {
        hotKeyManager.unregisterHotKey()
        hotKeyManager.unregisterSmartHotKey()
        unregisterAllToolHotKeys()
    }

    @discardableResult
    func reloadMainHotKey() -> Bool {
        hotKeyManager.unregisterHotKey()
        return registerMainHotKey()
    }

    @discardableResult
    func reloadSmartHotKey() -> Bool {
        hotKeyManager.unregisterSmartHotKey()
        return registerSmartHotKey()
    }

    /// 检查主/Smart 快捷键是否与系统或应用内冲突
    func isHotKeyConflicted(keyCode: UInt32, modifiers: UInt32) -> Bool {
        hotKeyManager.isHotKeyConflicted(
            keyCode: keyCode,
            modifiers: modifiers
        )
    }

    /// 检查 Tool 快捷键是否冲突（忽略正在编辑的工具）
    func isToolHotKeyConflicted(toolID: ToolID, keyCode: UInt32, modifiers: UInt32) -> Bool {
        hotKeyManager.isToolHotKeyConflicted(
            toolID: toolID.value,
            keyCode: keyCode,
            modifiers: modifiers
        )
    }

    private func registerMainHotKey() -> Bool {
        let success = hotKeyManager.registerHotKey()
        if !success {
            print("⚠️ 主快捷键注册失败，可能被其他应用占用")
        }
        return success
    }

    private func registerSmartHotKey() -> Bool {
        let smartConfig = HotKeyPreferences.loadSmart()
        let success = hotKeyManager.registerSmartHotKey(
            keyCode: smartConfig.keyCode,
            modifiers: smartConfig.modifierFlags
        )
        if success {
            print("✅ Smart hotkey registered: \(smartConfig.displayString)")
        } else {
            print("⚠️ Smart hotkey registration failed")
        }
        return success
    }
}

protocol PromptToolHotKeyHandling: Sendable {
    func registerToolHotKey(for tool: PromptTool, handler: @escaping @Sendable () -> Void) throws
    func unregisterToolHotKey(for toolID: ToolID)
    func unregisterAllToolHotKeys()
}

extension AppHotKeyCoordinator: PromptToolHotKeyHandling {
    func registerToolHotKey(for tool: PromptTool, handler: @escaping @Sendable () -> Void) throws {
        guard let combo = tool.keyCombo else { return }

        let success = hotKeyManager.registerToolHotKey(
            toolID: tool.id,
            keyCode: UInt32(combo.keyCode.value),
            modifiers: combo.modifiers.rawValue,
            callback: handler
        )

        if !success {
            throw HotKeyError.registrationFailed
        }
    }

    func unregisterToolHotKey(for toolID: ToolID) {
        hotKeyManager.unregisterToolHotKey(toolID: toolID.value)
    }

    func unregisterAllToolHotKeys() {
        hotKeyManager.unregisterAllToolHotKeys()
    }
}
