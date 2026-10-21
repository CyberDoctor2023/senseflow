import Foundation
import AppKit
import Carbon
@testable import SenseFlow

/// Receives real global key events through production registration. No model or clipboard access.
@main struct GlobalShortcutVerification {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: .init(x: 300, y: 300, width: 640, height: 240),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "senseflow 快捷键验证"
        let label = NSTextField(wrappingLabelWithString: "等待 ⌘⌃1、⌘⌃2、⌘⌃A")
        label.frame = .init(x: 24, y: 30, width: 590, height: 160)
        label.font = NSFont.systemFont(ofSize: 24)
        window.contentView?.addSubview(label)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        var counts: [String: Int] = [:]
        let bindings: [(String, UInt16)] = [("1", 18), ("2", 19), ("A", 0)]
        for (key, code) in bindings {
            let tool = PromptTool(name: "shortcut \(key)", prompt: "unused", shortcutKeyCode: code,
                                  shortcutModifiers: UInt32(cmdKey | controlKey))
            guard tool.hasShortcut, let combo = tool.keyCombo,
                  combo.modifiers.contains(.command), combo.modifiers.contains(.control) else {
                throw NSError(domain: "ShortcutValue", code: 1)
            }
            try AppHotKeyCoordinator.shared.registerToolHotKey(for: tool) {
                Task { @MainActor in
                    counts[key, default: 0] += 1
                    let status = bindings.map { "⌘⌃\($0.0): \(counts[$0.0, default: 0])" }.joined(separator: "\n")
                    label.stringValue = status
                    do { try status.write(to: output, atomically: true, encoding: .utf8) }
                    catch { label.stringValue = "无法保存验证证据：\(error.localizedDescription)" }
                }
            }
        }
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
        AppHotKeyCoordinator.shared.unregisterAllToolHotKeys()
    }
}
