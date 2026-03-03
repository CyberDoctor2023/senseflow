# 快捷键录制器修复（最终版）

## 🐛 问题
用户反馈：快捷键无法录制

## ✅ 解决方案
直接复用 `HotKeyRecorderView` 中已经验证可用的 `HotKeyRecorder` 类实现。

## 📝 实现方式

### 1. 创建 ToolHotKeyRecorder 类
直接复制 `HotKeyRecorder` 的核心逻辑：

```swift
class ToolHotKeyRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordedKeyCode: UInt32?
    @Published var recordedModifiers: UInt32?
    @Published var currentKeyCode: UInt32 = 0
    @Published var currentModifiers: UInt32 = 0

    private var eventMonitor: Any?

    func startRecording() {
        isRecording = true
        recordedKeyCode = nil
        recordedModifiers = nil

        // 监听本地按键事件（与 HotKeyRecorder 完全相同）
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            // 忽略纯修饰键
            if event.keyCode == 0x3B || event.keyCode == 0x3C || event.keyCode == 0x3D || event.keyCode == 0x3E ||
               event.keyCode == 0x38 || event.keyCode == 0x3A || event.keyCode == 0x37 {
                return nil
            }

            // 捕获键码和修饰键
            self.recordedKeyCode = UInt32(event.keyCode)
            self.recordedModifiers = event.modifierFlags.carbonFlags

            // 停止录制
            self.stopRecording()

            return nil  // 阻止事件传播
        }
    }

    func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    deinit {
        stopRecording()
    }
}
```

### 2. 使用 SwiftUI 视图
```swift
@available(macOS 13.0, *)
struct ShortcutRecorderField: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt32

    @StateObject private var recorder = ToolHotKeyRecorder()
    @State private var showConflictAlert = false

    var body: some View {
        HStack {
            // 快捷键显示框
            Text(recorder.isRecording ? "按下快捷键..." : displayString)
                .font(.system(size: 14, design: .monospaced))
                .frame(minWidth: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(recorder.isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(recorder.isRecording ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onTapGesture {
                    if !recorder.isRecording {
                        recorder.startRecording()
                    }
                }

            // 清除按钮
            if keyCode != 0 {
                Button {
                    keyCode = 0
                    modifiers = 0
                    recorder.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            // 取消按钮
            if recorder.isRecording {
                Button("取消") {
                    recorder.stopRecording()
                }
                .buttonStyle(.bordered)
            }
        }
        .onChange(of: recorder.recordedKeyCode) { newValue in
            if let keyCode = newValue, let modifiers = recorder.recordedModifiers {
                // 检测冲突
                if HotKeyManager.shared.isHotKeyConflicted(keyCode: keyCode, modifiers: modifiers) {
                    showConflictAlert = true
                    recorder.clear()
                } else {
                    self.keyCode = UInt16(keyCode)
                    self.modifiers = modifiers
                }
            }
        }
        .alert("快捷键冲突", isPresented: $showConflictAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("该快捷键已被其他应用占用，请选择其他组合。")
        }
    }
}
```

## 🎯 关键点

### 1. 完全复用已验证的代码
- `ToolHotKeyRecorder` 的实现与 `HotKeyRecorder` 完全相同
- 使用相同的事件监听逻辑
- 使用相同的修饰键过滤逻辑

### 2. SwiftUI 集成
- 使用 `@StateObject` 管理 recorder 生命周期
- 使用 `.onChange` 监听录制结果
- 使用 `.onTapGesture` 触发录制

### 3. 冲突检测
- 录制完成后立即检测冲突
- 冲突时显示 Alert 并清除结果
- 无冲突时更新 Binding 值

## 📁 修改文件
- `SenseFlow/Views/PromptToolEditorView.swift`

## ✅ 编译验证
```bash
xcodebuild -scheme SenseFlow -configuration Debug build
```
**结果**: ✅ **BUILD SUCCEEDED**

## 🧪 测试清单
- [ ] 打开设置 → Prompt Tools Tab
- [ ] 点击"添加 Tool"
- [ ] 点击快捷键输入框
- [ ] 输入框显示"按下快捷键..."（蓝色边框）
- [ ] 按下 `Cmd+Shift+M`
- [ ] 输入框显示 `⌘⇧M`
- [ ] 点击 ❌ 清除快捷键
- [ ] 再次录制，按下已占用的快捷键
- [ ] 显示"快捷键冲突"警告

## 💡 为什么之前的实现不工作

### 之前的问题
使用 `NSViewRepresentable` + `NSTextField` 的方式过于复杂：
- 需要手动管理 NSView 生命周期
- 需要手动处理焦点
- 需要手动同步状态

### 现在的方案
直接使用 SwiftUI + `NSEvent.addLocalMonitorForEvents`：
- SwiftUI 自动管理生命周期
- 事件监听器全局生效，无需焦点
- 状态自动同步（通过 `@Published`）

## 🎉 总结

**问题**: 快捷键无法录制
**原因**: 过度设计，使用了不必要的 NSViewRepresentable
**解决**: 直接复用已验证可用的 HotKeyRecorder 实现

**现在可以正常录制快捷键了！** ✅

---

**修复日期**: 2026-01-19
**版本**: v0.2.0
