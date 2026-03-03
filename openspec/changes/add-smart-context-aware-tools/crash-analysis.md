# Smart 功能崩溃分析报告

## 时间线回顾

从 Git 历史中恢复的崩溃演进过程：

1. **6671ebb** - 添加屏幕录制权限状态显示
2. **bfc9590** - 使用 `CGRequestScreenCaptureAccess` 请求权限
3. **ce84214** - 替换为引导式用户流程（发现第一个问题）
4. **73eb95f** - 完全移除 `CGRequestScreenCaptureAccess`（发现严重问题）
5. **59a171e** - 全量回滚所有 Smart 代码

---

## 根本原因分析

### 1. **CGRequestScreenCaptureAccess 的致命缺陷**

**问题**：
```swift
// ❌ 在 async context 中调用会导致崩溃
@MainActor
func manuallyRequestPermission() {
    let granted = CGRequestScreenCaptureAccess()  // 💥 阻塞式系统对话框
}
```

**为什么崩溃**：
- `CGRequestScreenCaptureAccess()` 是**阻塞式调用**，会弹出系统模态对话框
- 在 `async/await` 上下文中调用时，导致**多个对话框同时出现**
- 应用死锁：主线程被阻塞，async task 无法完成
- 系统无响应，最终崩溃

**触发场景**：
```swift
Task { @MainActor in
    let recommendation = try await SmartToolManager.shared.analyzeCurrentContext()
    // ↓ analyzeCurrentContext 内部调用了截图
    // ↓ 截图失败后尝试请求权限
    // ↓ CGRequestScreenCaptureAccess() 在 Task 内部被调用
    // 💥 崩溃：模态对话框 + async context = 死锁
}
```

---

### 2. **@available 版本检查与异步上下文冲突**

**问题**：
```swift
// AppDelegate.swift
func setupSmartHotKey() {
    if #available(macOS 14.0, *) {
        let success = HotKeyManager.shared.registerSmartHotKey { [weak self] in
            self?.triggerSmartRecommendation()  // 回调闭包
        }
    }
}

@available(macOS 14.0, *)
private func triggerSmartRecommendation() {
    Task { @MainActor in
        // ScreenCaptureManager.shared 需要 macOS 14.0+
        let recommendation = try await SmartToolManager.shared.analyzeCurrentContext()
    }
}
```

**为什么崩溃**：
- 热键回调是 **非 async 闭包**
- 在回调中启动 `Task { @MainActor }` 创建了新的 async 上下文
- `@available` 标记在**闭包边界**处被编译器错误处理
- 运行时检查失败 → 启动时崩溃

**编译器警告被忽略**：
```
warning: @available condition on asynchronous context may not be enforced at runtime
```

---

### 3. **ScreenCaptureKit 权限检查的陷阱**

**问题**：
```swift
// ❌ 错误的权限检查流程
func checkPermission() -> Bool {
    return CGPreflightScreenCaptureAccess()  // 仅检查，不请求
}

func captureCurrentWindow() async throws -> CGImage {
    let content = try await SCShareableContent.excludingDesktopWindows(...)
    // ↑ 如果权限未授予，这里会静默失败或崩溃
}
```

**正确行为**：
- `CGPreflightScreenCaptureAccess()` 只检查权限状态，不触发系统对话框
- `SCShareableContent` 在**首次调用时**会自动请求权限
- 但如果在 async context 中，系统对话框会导致崩溃

**提交 73eb95f 的修复尝试**：
```swift
// ✅ 改进：直接尝试截图，失败后再检查权限
do {
    let image = try await captureCurrentWindow()
} catch {
    if !checkPermission() {
        await requestPermissionWithGuidance()  // 引导用户去设置
    }
}
```

但这仍然不够，因为 `requestPermissionWithGuidance()` 内部仍然可能调用 `CGRequestScreenCaptureAccess()`。

---

### 4. **多窗口管理的线程安全问题**

**问题**：
```swift
// AppDelegate.swift
private var smartLoadingWindow: NSWindow?

@available(macOS 26.0, *)
private func showSmartLoadingWindow() {
    // 创建加载窗口
}

private func closeSmartLoadingWindow() {
    smartLoadingWindow?.close()
}

// 在 Task 中调用
Task { @MainActor in
    showSmartLoadingWindow()  // ✓ 主线程
    let result = try await analyzeCurrentContext()  // ❌ 暂停，切换上下文
    closeSmartLoadingWindow()  // ⚠️ 可能在不同上下文
}
```

**崩溃场景**：
- 用户快速连按快捷键 → 创建多个 `Task`
- 多个 loading window 实例被创建
- `@MainActor` 保证主线程，但**不保证执行顺序**
- Window close 顺序混乱 → 崩溃

**提交 ce84214 的部分修复**：
添加了多实例保护，但不完整。

---

## 崩溃模式总结

| 崩溃类型 | 触发条件 | 错误位置 |
|---------|---------|---------|
| **死锁崩溃** | 在 `Task` 中调用 `CGRequestScreenCaptureAccess()` | `SmartToolManager.collectContext()` |
| **版本检查崩溃** | `@available` 在异步回调中失效 | `AppDelegate.triggerSmartRecommendation()` |
| **权限静默失败** | `SCShareableContent` 在未授权时抛出异常 | `ScreenCaptureManager.captureCurrentWindow()` |
| **窗口管理崩溃** | 快速触发导致多窗口竞争 | `AppDelegate.smartLoadingWindow` |
| **内存问题** | TIFF 中间格式占用 8MB+ | `ScreenCaptureManager.imageToBase64()` (已修复) |

---

## 为什么最终回滚

从提交 `59a171e` 的消息可以看出：

> **REASON:**
> The Smart feature caused application startup crashes due to complex interactions between:
> - `@available` macOS version checks
> - `@MainActor` threading requirements
> - `CGRequestScreenCaptureAccess` modal dialogs
> - Async/await context conflicts

**关键点**：
1. **应用启动时崩溃** - 不是功能崩溃，是启动就挂
2. **复杂交互** - 多个问题叠加，修一个出一个
3. **无法快速定位** - 涉及系统 API、编译器行为、运行时异步调度

**决策**：
- 优先保证应用可用性
- Smart 功能是增强功能，非核心
- 全量回滚 → 应用恢复正常启动

---

## 技术债务

回滚后留下的问题：

1. **OpenSpec 提案完整** - 设计和任务都已完成，但代码全部删除
2. **部分修复有效** - 如内存优化、窗口管理改进
3. **根本问题未解决** - 权限请求流程仍然是雷区

---

## 下一步：新实现方案规划

需要解决的核心问题：
1. 如何在 async context 中安全请求屏幕录制权限？
2. 如何避免 `@available` 和 `@MainActor` 的组合陷阱？
3. 如何优雅降级（轻量模式）当权限未授予时？

**关键约束**：
- ✅ 必须支持 macOS 14.0+ (ScreenCaptureKit 最低要求)
- ✅ 当前项目目标是 macOS 26.0+ only
- ✅ 可以假设系统 API 稳定性更好
- ⚠️ 必须避免启动时崩溃
- ⚠️ 必须处理快速重复触发

---

**报告生成时间**: 2026-01-22
**分析基于**: Git commits 6671ebb → 59a171e
