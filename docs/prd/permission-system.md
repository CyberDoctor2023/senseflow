# PRD: 权限系统完整方案

**版本**: v1.0
**日期**: 2026-01-22
**状态**: Draft

---

## 核心理念

**所有权限问题在开屏引导页统一解决**

- 应用启动 → 自动弹出引导页 → 完成所有权限请求
- 用户可以"跳过"，但高级设置可以随时恢复默认
- **关键要求**：权限请求必须是真实的系统 API 调用，确保系统设置中出现 "SenseFlow"

---

## 唯一权限入口

### 开屏引导页（权限请求中心）

**触发时机**：
- 默认：每次应用启动都弹出
- 条件：`UserDefaults["skipOnboardingPermissions"] == false`

**页面内容**：
1. 辅助功能权限请求
   - 说明用途："Prompt Tools 自动粘贴需要辅助功能权限"
   - 按钮："授权" → **真实请求**打开系统设置
   - 权限状态指示：
     - ❌ 未授权：红色 `xmark.circle.fill`
     - ✅ 已授权：绿色 `checkmark.circle.fill`

2. 屏幕录制权限请求
   - 说明用途："Smart AI 上下文截图需要屏幕录制权限"
   - 按钮："授权" → **真实请求**触发系统弹窗
   - 权限状态指示：
     - ❌ 未授权：红色 `xmark.circle.fill`
     - ✅ 已授权：绿色 `checkmark.circle.fill`

3. 通知权限请求
   - 说明用途："剪切板操作状态由通知提醒（本版本功能）"
   - 按钮："授权" → **真实请求**触发系统弹窗
   - 权限状态指示：
     - ❌ 未授权：红色 `xmark.circle.fill`
     - ✅ 已授权：绿色 `checkmark.circle.fill`

**页面右下角**：
- 按钮："跳过"
- 点击后：
  - 保存 `UserDefaults["skipOnboardingPermissions"] = true`
  - 关闭引导页
  - 之后启动不再自动弹出

**为什么必须真实请求**：
- 如果只是 UI 展示，用户点击后跳转到系统设置，但设置里找不到 "SenseFlow" 选项 → 用户会困惑，无法完成授权

---

---

## 高级设置：恢复开屏引导

**位置**：
- 设置 → 高级设置 → "权限引导" 卡片

**按钮功能**：
- 按钮文本："恢复开屏引导"
- 点击后：
  - 重置 `UserDefaults["skipOnboardingPermissions"] = false`
  - 下次启动时，开屏引导页重新弹出

**作用**：
- 让被"跳过"的开屏引导页重新生效
- 用于：
  1. 用户之前点了"跳过"，现在想重新授权
  2. 开发测试引导流程

---

## 真实权限请求实现

### 辅助功能权限

**检查 API**：
```swift
func checkAccessibilityPermission() -> Bool {
    return AXIsProcessTrusted()
}
```

**请求方式**（打开系统设置）：
```swift
func requestAccessibilityPermission() {
    let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
    NSWorkspace.shared.open(url!)
}
```

**效果验证**：
- 用户点击"授权" → 系统设置自动打开
- 系统设置 → 隐私与安全性 → 辅助功能 → **列表中出现 "SenseFlow"**
- 用户手动勾选 → 授权完成 → 页面显示 ✅

---

### 屏幕录制权限

**检查 API**：
```swift
func checkScreenRecordingPermission() -> Bool {
    return CGPreflightScreenCaptureAccess()
}
```

**请求方式**（触发系统弹窗）：
```swift
func requestScreenRecordingPermission() {
    // 这个 API 只在首次调用时弹出系统授权窗口
    CGRequestScreenCaptureAccess()
}
```

**效果验证**：
- 用户点击"授权" → **系统弹窗**："SenseFlow 想要录制此屏幕"
- 用户点击"允许" → 授权完成 → 页面显示 ✅
- 系统设置 → 隐私与安全性 → 屏幕录制 → **列表中出现 "SenseFlow"**

**注意**：
- `CGRequestScreenCaptureAccess()` 只在首次调用时弹窗
- 如果用户拒绝，后续调用不会再弹窗
- 需要引导用户手动去系统设置开启

---

### 通知权限

**检查 API**：
```swift
func checkNotificationPermission() async -> Bool {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    return settings.authorizationStatus == .authorized
}
```

**请求方式**（触发系统弹窗）：
```swift
func requestNotificationPermission() async {
    let center = UNUserNotificationCenter.current()
    do {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        // granted == true → 授权成功
    } catch {
        // 处理错误
    }
}
```

**效果验证**：
- 用户点击"授权" → **系统弹窗**："SenseFlow 想要向您发送通知"
- 用户点击"允许" → 授权完成 → 页面显示 ✅
- 系统设置 → 通知 → **列表中出现 "SenseFlow"**

**用途说明**：
- 本版本剪切板操作（复制/粘贴）的状态通过通知反馈给用户
- 例如："已复制到剪切板"、"Prompt Tool 执行完成"

---

## 用户流程

### 场景 1: 首次使用（默认行为）

```
应用启动
  ↓
检查 UserDefaults["skipOnboardingPermissions"]
  ↓
[未设置/false] → 显示开屏引导页
  ↓
用户看到三个权限请求（辅助功能、屏幕录制、通知）
每个权限旁边显示状态符号：❌ 或 ✅
  ↓
选项 A: 逐个点击"授权"
  → 辅助功能：打开系统设置 → 用户手动勾选 → 页面显示 ✅
  → 屏幕录制：系统弹窗 → 用户点击"允许" → 页面显示 ✅
  → 通知：系统弹窗 → 用户点击"允许" → 页面显示 ✅
  → 完成后点击"跳过"关闭引导页
  ↓
选项 B: 直接点击"跳过"
  → 保存 skipOnboardingPermissions = true
  → 下次启动不再弹出
```

### 场景 2: 已跳过，需要重新授权

```
用户想要授权（之前点了"跳过"）
  ↓
打开设置 → 高级设置
  ↓
点击"恢复开屏引导"
  ↓
skipOnboardingPermissions = false
  ↓
关闭应用，重新启动
  ↓
开屏引导页弹出
  ↓
完成权限授权
```

### 场景 3: 开发测试

```
开发需要验证引导页体验
  ↓
高级设置 → "恢复开屏引导"
  ↓
skipOnboardingPermissions = false
  ↓
重启应用
  ↓
引导页弹出
  ↓
测试权限请求流程
  ↓
验证系统设置中是否出现 "SenseFlow"
```

---

## UserDefaults 设计

```swift
// 唯一的控制标志
"aiclipboard.skipOnboardingPermissions": Bool

// false（默认）→ 每次启动弹出引导页
// true → 不再弹出引导页
```

---

## 实现参考（Easydict）

### 屏幕录制真实请求
```swift
let hasPermission = CGPreflightScreenCaptureAccess()
if !hasPermission {
    // 触发系统弹窗（首次会弹窗）
    CGRequestScreenCaptureAccess()
}
```

### 打开系统设置
```swift
let url = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
)
NSWorkspace.shared.open(url!)
```

---

## 验收标准

### 必须满足

1. ✅ **真实请求验证**：
   - 点击辅助功能"授权" → 系统设置中**必须出现** "SenseFlow"
   - 点击屏幕录制"授权" → 系统弹窗**必须弹出**
   - 点击通知"授权" → 系统弹窗**必须弹出**

2. ✅ **权限状态指示**：
   - 每个权限右侧显示状态符号
   - ❌ 红色 `xmark.circle.fill` = 未授权
   - ✅ 绿色 `checkmark.circle.fill` = 已授权
   - 实时更新：用户授权后立即显示 ✅

3. ✅ **默认行为**：
   - 应用首次启动 → 自动弹出引导页
   - 每次启动都弹出（直到用户点击"跳过"）

4. ✅ **跳过功能**：
   - 点击"跳过" → 下次启动不再弹出
   - 保存到 UserDefaults

5. ✅ **恢复开屏引导**：
   - 高级设置 → "恢复开屏引导"
   - 下次启动时，开屏引导页重新弹出

---

**审核**: 待审核
**变更历史**: 2026-01-22 初始版本
