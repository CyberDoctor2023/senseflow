//
//  AutoPasteManager.swift
//  SenseFlow
//
//  Created on 2026-01-15.
//

import Cocoa
import Carbon

/// 自动粘贴管理器（单例）
class AutoPasteManager {

    // MARK: - Singleton

    static let shared = AutoPasteManager()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 执行自动粘贴（模拟 Cmd+V）
    /// - Parameter delay: 延迟时间（秒），默认 0.15s
    func performAutoPaste(delay: TimeInterval = 0.15) {
        print("🔄 开始自动粘贴流程...")

        // 检查权限
        guard AccessibilityManager.shared.checkAccessibilityPermission() else {
            print("❌ 自动粘贴失败: 缺少 Accessibility 权限")
            showManualPasteHint()
            return
        }

        print("✅ 权限检查通过，延迟 \(delay) 秒后执行粘贴")

        // 延迟执行，避免窗口截获事件
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            print("⏰ 延迟结束，开始模拟 Cmd+V")
            self?.simulateCmdV()
        }
    }

    // MARK: - Private Methods

    /// 模拟 Cmd+V 按键（参考 Maccy 实现）
    private func simulateCmdV() {
        print("🎹 开始创建键盘事件...")

        // 创建事件源（使用 combinedSessionState）
        let source = CGEventSource(stateID: .combinedSessionState)

        // 禁用本地键盘事件，只允许鼠标和系统事件
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        print("✅ 事件源创建成功")

        // 添加左右修饰键标志
        let cmdFlag = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)

        // 创建 V Down 和 V Up 事件
        guard let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            print("❌ 无法创建键盘事件")
            return
        }

        // 设置 Cmd 修饰键
        keyVDown.flags = cmdFlag
        keyVUp.flags = cmdFlag
        print("✅ 键盘事件创建成功")

        // 发送事件（使用 cgSessionEventTap）
        print("📤 发送粘贴事件...")
        keyVDown.post(tap: .cgSessionEventTap)
        keyVUp.post(tap: .cgSessionEventTap)

        print("✅ 自动粘贴完成 (Cmd+V)")
    }

    /// 显示手动粘贴提示
    private func showManualPasteHint() {
        // 创建临时通知窗口
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = Strings.AutoPaste.manualPasteMessage
            alert.informativeText = Strings.AutoPaste.permissionRequired
            alert.alertStyle = .informational
            alert.addButton(withTitle: Strings.AutoPaste.understood)
            alert.addButton(withTitle: Strings.AccessibilityPermission.openSettings)

            let response = alert.runModal()

            if response == .alertSecondButtonReturn {
                AccessibilityManager.shared.openAccessibilitySettings()
            }
        }
    }
}
