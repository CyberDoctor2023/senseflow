//
//  TextExtractor.swift
//  SenseFlow
//
//  Created on 2026-02-06 for v0.5.0
//  Text extraction protocol and implementations
//

import Foundation
import AppKit
import ApplicationServices

/// 文本提取结果
struct TextExtractionResult {
    let text: String?
    let error: AXError
}

/// 文本提取器协议
protocol TextExtractor {
    /// 提取当前选中的文本
    /// - Returns: 提取结果（包含文本和错误信息）
    func extractSelectedText() -> TextExtractionResult
}

/// Accessibility API 文本提取器（快速、无副作用）
class AccessibilityTextExtractor: TextExtractor {
    func extractSelectedText() -> TextExtractionResult {
        // 获取当前应用
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return TextExtractionResult(text: nil, error: .failure)
        }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // 获取焦点元素
        var focusedElement: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusedResult == .success, let element = focusedElement else {
            return TextExtractionResult(text: nil, error: focusedResult)
        }

        // 获取选中文本
        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        // 返回结果和错误信息
        if textResult == .success, let text = selectedText as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return TextExtractionResult(text: trimmed.isEmpty ? nil : trimmed, error: .success)
        }

        return TextExtractionResult(text: nil, error: textResult)
    }
}

/// 模拟复制文本提取器（适用于 Electron 应用）
class SimulatedCopyTextExtractor: TextExtractor {
    func extractSelectedText() -> TextExtractionResult {
        // 1. 保存当前剪贴板状态
        let pasteboard = NSPasteboard.general
        let oldChangeCount = pasteboard.changeCount
        let oldContent = pasteboard.string(forType: .string)

        // 2. 模拟 Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand

        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        cDown?.flags = .maskCommand

        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand

        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.post(tap: .cghidEventTap)
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)

        // 3. 等待剪贴板更新（最多 200ms）
        var newContent: String?
        for _ in 0..<BusinessRules.Performance.maxRetryAttempts {
            usleep(10_000) // 10ms
            if pasteboard.changeCount != oldChangeCount {
                newContent = pasteboard.string(forType: .string)
                break
            }
        }

        // 4. 检查是否获取到新内容
        guard let text = newContent, text != oldContent, !text.isEmpty else {
            return TextExtractionResult(text: nil, error: .failure)
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return TextExtractionResult(text: trimmed.isEmpty ? nil : trimmed, error: .success)
    }
}
