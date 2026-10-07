# macOS Integration

macOS 系统集成常用模式。

## 剪贴板监听

```swift
// ✅ 轮询模式（推荐）
class ClipboardMonitor {
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func checkForChanges() {
        let currentCount = NSPasteboard.general.changeCount
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            handleClipboardChange()
        }
    }
}
```

## 全局快捷键

```swift
// ✅ Carbon EventHotKey API
import Carbon

var hotKeyRef: EventHotKeyRef?

func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                   eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)

    var hotKeyID = EventHotKeyID(signature: OSType(0x4B4D), id: 1)
    RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
}
```

## 窗口管理 (NSPanel)

```swift
// ✅ 浮动窗口
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 600, height: 300),
    styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.isMovableByWindowBackground = true
```

## OCR (Vision Framework)

```swift
// ✅ 文字识别
import Vision

func recognizeText(in image: NSImage) async throws -> String {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw OCRError.invalidImage
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])

    let observations = request.results ?? []
    return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
}
```

## 自动粘贴 (CGEvent)

```swift
// ✅ 模拟 Cmd+V
func autoPaste() {
    let source = CGEventSource(stateID: .hidSystemState)

    // Cmd Down
    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
    cmdDown?.flags = .maskCommand

    // V Down
    let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
    vDown?.flags = .maskCommand

    // V Up
    let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

    // Cmd Up
    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

    cmdDown?.post(tap: .cghidEventTap)
    vDown?.post(tap: .cghidEventTap)
    vUp?.post(tap: .cghidEventTap)
    cmdUp?.post(tap: .cghidEventTap)
}
```

## Accessibility 权限检查

```swift
// ✅ 检查和请求权限
import ApplicationServices

func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
}
```
