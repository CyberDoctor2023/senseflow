//
//  KeyboardAcceptingPanel.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//

import Cocoa

/// 自定义 NSPanel，允许接受键盘输入
class KeyboardAcceptingPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    // 允许 TextField 响应标准编辑命令（Cmd+A, Cmd+C, Cmd+V, Cmd+X）
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 允许所有标准编辑快捷键通过
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "a":
                // Cmd+A 全选
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) {
                    return true
                }
            case "c":
                // Cmd+C 复制
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) {
                    return true
                }
            case "v":
                // Cmd+V 粘贴
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                    return true
                }
            case "x":
                // Cmd+X 剪切
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) {
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
