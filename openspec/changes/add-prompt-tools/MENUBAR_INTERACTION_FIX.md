# 菜单栏交互优化

## 📝 修改说明

### 修改内容
将菜单栏图标的交互方式改为：
- **左键单击** → 打开剪贴板历史窗口
- **右键单击** → 显示菜单（设置、清空历史、退出等）

### 修改文件
- `SenseFlow/AppDelegate.swift`

### 实现方式

#### 1. 设置按钮响应左右键
```swift
if let button = statusItem?.button {
    button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "SenseFlow")
    button.image?.isTemplate = true

    // 设置按钮行为：左键打开历史，右键显示菜单
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.target = self
    button.action = #selector(statusBarButtonClicked(_:))
}
```

#### 2. 不直接设置菜单
```swift
// 不直接设置 menu，而是在右键时手动显示
statusItem?.menu = nil
self.contextMenu = menu
```

#### 3. 根据点击类型分发
```swift
@objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else { return }

    if event.type == .rightMouseUp {
        // 右键：显示菜单
        if let menu = contextMenu, let button = statusItem?.button {
            statusItem?.menu = menu
            button.performClick(nil)
            // 显示菜单后立即清除，避免左键也显示菜单
            DispatchQueue.main.async { [weak self] in
                self?.statusItem?.menu = nil
            }
        }
    } else {
        // 左键：打开历史窗口
        openHistory()
    }
}
```

### 用户体验

**修改前**:
- 点击菜单栏图标 → 显示菜单 → 点击"打开历史" → 打开窗口（2 步）

**修改后**:
- **左键点击** → 直接打开历史窗口（1 步）✨
- **右键点击** → 显示菜单（设置、清空、退出）

### 编译验证
```bash
xcodebuild -scheme SenseFlow -configuration Debug build
```
**结果**: ✅ **BUILD SUCCEEDED**

### 测试清单
- [ ] 左键点击菜单栏图标 → 打开剪贴板历史窗口
- [ ] 再次左键点击 → 关闭窗口
- [ ] 右键点击菜单栏图标 → 显示菜单
- [ ] 菜单中点击"打开历史" → 打开窗口
- [ ] 菜单中点击"设置..." → 打开设置窗口
- [ ] 菜单中点击"清空历史记录" → 显示确认对话框
- [ ] 菜单中点击"退出" → 退出应用

---

**修改日期**: 2026-01-19
**版本**: v0.2.0
