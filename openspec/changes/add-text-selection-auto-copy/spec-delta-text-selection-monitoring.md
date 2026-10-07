# Spec Delta: text-selection-monitoring

## Metadata
- **Capability ID**: text-selection-monitoring
- **Type**: new
- **Change ID**: add-text-selection-auto-copy
- **Version**: 0.5.0

## Summary
文本选择监听器，监听用户的文本选择操作，自动复制选中的文本到剪贴板历史。使用主动查询模式（NSEvent.leftMouseUp + Accessibility API）实现 70-80% 的应用覆盖率。

## Requirements

### REQ-TSM-001: 单例模式
- **Priority**: MUST
- **Description**: TextSelectionMonitor 必须使用单例模式（shared instance）
- **Rationale**: 全局只需一个文本选择监听器实例

### REQ-TSM-002: 启动和停止监听
- **Priority**: MUST
- **Description**: 提供 `startMonitoring()` 和 `stopMonitoring()` 方法
- **Rationale**: 应用启动时开始监听，退出时停止监听
- **Behavior**:
  - `startMonitoring()` 注册全局鼠标事件监听器
  - `stopMonitoring()` 移除事件监听器并释放资源
  - 重复调用 `startMonitoring()` 应该是安全的（幂等性）

### REQ-TSM-003: 鼠标事件监听
- **Priority**: MUST
- **Description**: 使用 `NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp)` 监听鼠标释放事件
- **Rationale**: 用户选中文本后释放鼠标，此时触发查询
- **Implementation**: 保存 event monitor 引用用于停止监听

### REQ-TSM-004: 延迟查询
- **Priority**: MUST
- **Description**: 鼠标释放后延迟 100ms 再查询选中文本
- **Rationale**: 确保文本选择操作完全完成
- **Value**: 100ms（固定值，不可配置）

### REQ-TSM-005: Accessibility API 查询
- **Priority**: MUST
- **Description**: 使用 Accessibility API 主动查询选中文本
- **Implementation**:
  - 获取 frontmost application（`NSWorkspace.shared.frontmostApplication`）
  - 创建 AXUIElement（`AXUIElementCreateApplication`）
  - 查询 focused element（`kAXFocusedUIElementAttribute`）
  - 查询 selected text（`kAXSelectedTextAttribute`）
- **Return**: 选中的文本字符串，如果失败返回 nil

### REQ-TSM-006: 功能开关检查
- **Priority**: MUST
- **Description**: 检查 UserDefaults `text_selection_auto_copy_enabled` 开关
- **Rationale**: 用户可以在设置中关闭此功能
- **Behavior**: 如果开关关闭，直接返回，不执行后续操作
- **Default**: true（默认开启）

### REQ-TSM-007: 应用过滤
- **Priority**: MUST
- **Description**: 调用 ClipboardFilterManager 检查应用是否应该被过滤
- **Rationale**: 尊重用户的应用黑名单设置
- **Implementation**: 调用 `ClipboardFilterManager.shared.shouldFilter(pasteboardTypes: nil, appBundleID: app.bundleIdentifier, appName: app.localizedName)`
- **Behavior**: 如果 `shouldFilter` 返回 true，停止处理

### REQ-TSM-008: 最小文本长度过滤
- **Priority**: MUST
- **Description**: 检查选中文本长度是否达到最小要求
- **Rationale**: 避免误触发（如单个字符、空格等）
- **Implementation**: 读取 UserDefaults `text_selection_min_length`
- **Default**: 3 字符
- **Behavior**: 如果文本长度 < 最小长度，不复制

### REQ-TSM-009: 写入剪贴板
- **Priority**: MUST
- **Description**: 将选中文本写入系统剪贴板
- **Implementation**: 使用 `NSPasteboard.general.clearContents()` 和 `setString(_:forType:)`
- **Rationale**: 写入剪贴板后，ClipboardMonitor 会自动捕获并保存

### REQ-TSM-010: 暂停 ClipboardMonitor
- **Priority**: MUST
- **Description**: 写入剪贴板前调用 `ClipboardMonitor.shared.pauseMonitoring(duration: 1.0)`
- **Rationale**: 避免循环捕获（TextSelectionMonitor 写入 → ClipboardMonitor 捕获 → 重复记录）
- **Duration**: 1.0 秒（固定值）

### REQ-TSM-011: 错误处理
- **Priority**: MUST
- **Description**: Accessibility API 查询失败时静默失败
- **Rationale**: 某些应用不支持 Accessibility API，这是预期行为
- **Behavior**: 不显示错误提示，不影响用户体验

### REQ-TSM-012: 日志记录
- **Priority**: SHOULD
- **Description**: 记录关键操作的日志
- **Content**:
  - 监听器启动/停止
  - 文本选择触发（应用名称）
  - 过滤原因（如果被过滤）
  - Accessibility API 查询失败（如果失败）
- **Rationale**: 便于调试和问题排查

### REQ-TSM-013: 性能要求
- **Priority**: MUST
- **Description**: CPU 占用 < 0.1%，响应延迟 < 200ms
- **Rationale**: 不影响系统性能和用户体验
- **Measurement**: 使用 Activity Monitor 和性能测试验证

## Scenarios

### SCENARIO-TSM-001: 成功复制选中文本
**Given**:
- 功能开关开启
- 用户在 TextEdit 中选中 "Hello World"（11 字符）
- TextEdit 不在黑名单中
**When**: 用户释放鼠标
**Then**:
1. 延迟 100ms
2. 检查功能开关（开启）
3. 检查应用过滤（通过）
4. 查询 Accessibility API（返回 "Hello World"）
5. 检查最小长度（11 >= 3，通过）
6. 暂停 ClipboardMonitor 1 秒
7. 写入剪贴板
8. ClipboardMonitor 自动捕获并保存

### SCENARIO-TSM-002: 文本过短不复制
**Given**:
- 功能开关开启
- 用户在 TextEdit 中选中 "Hi"（2 字符）
- 最小长度设置为 3
**When**: 用户释放鼠标
**Then**:
1. 延迟 100ms
2. 检查功能开关（开启）
3. 检查应用过滤（通过）
4. 查询 Accessibility API（返回 "Hi"）
5. 检查最小长度（2 < 3，不通过）
6. 停止处理，不写入剪贴板

### SCENARIO-TSM-003: 应用在黑名单中
**Given**:
- 功能开关开启
- 用户在 Terminal 中选中文本
- Terminal 在黑名单中
**When**: 用户释放鼠标
**Then**:
1. 延迟 100ms
2. 检查功能开关（开启）
3. 检查应用过滤（不通过，原因：blacklistedApp）
4. 停止处理，不查询 Accessibility API

### SCENARIO-TSM-004: 功能开关关闭
**Given**:
- 功能开关关闭（`text_selection_auto_copy_enabled` = false）
- 用户在 TextEdit 中选中文本
**When**: 用户释放鼠标
**Then**:
1. 延迟 100ms
2. 检查功能开关（关闭）
3. 停止处理，不执行后续操作

### SCENARIO-TSM-005: Accessibility API 查询失败
**Given**:
- 功能开关开启
- 用户在不支持 Accessibility API 的应用中选中文本
**When**: 用户释放鼠标
**Then**:
1. 延迟 100ms
2. 检查功能开关（开启）
3. 检查应用过滤（通过）
4. 查询 Accessibility API（返回 nil）
5. 停止处理，静默失败

### SCENARIO-TSM-006: 快速连续划词
**Given**:
- 功能开关开启
- 用户快速连续选中多段文本
**When**: 用户连续释放鼠标 3 次
**Then**:
- 每次都触发独立的处理流程
- 每次都延迟 100ms
- 不会相互干扰
- 性能保持稳定

### SCENARIO-TSM-007: 密码管理器应用
**Given**:
- 功能开关开启
- 用户在 1Password 中选中密码
- 密码管理器过滤开关开启
**When**: 用户释放鼠标
**Then**:
1. 延迟 100ms
2. 检查功能开关（开启）
3. 检查应用过滤（不通过，原因：passwordManager）
4. 停止处理，不查询 Accessibility API

## Dependencies

### Internal Dependencies
- ClipboardFilterManager（过滤检查）
- ClipboardMonitor（暂停监听）
- UserDefaults（读取配置）

### External Dependencies
- NSEvent（鼠标事件监听）
- NSWorkspace（获取 frontmost application）
- Accessibility Framework（AXUIElement, AXUIElementCopyAttributeValue）
- NSPasteboard（写入剪贴板）

### Permission Requirements
- Accessibility 权限（项目已有）

## Notes

### Implementation Notes
- 使用 DispatchQueue.main.asyncAfter 实现 100ms 延迟
- event monitor 引用应该是 weak 或 unowned，避免循环引用
- Accessibility API 查询应该在后台线程执行，避免阻塞主线程
- 写入剪贴板应该在主线程执行

### Testing Notes
- 测试不同应用的兼容性（TextEdit, Safari, Chrome, Terminal, VSCode）
- 测试快速连续划词的稳定性
- 测试性能指标（CPU 占用、响应延迟）
- 测试边缘情况（空文本、超长文本、特殊字符）

### Known Limitations
- 覆盖率 70-80%（某些应用不支持 Accessibility API）
- Terminal、iTerm 等终端应用可能不支持
- 某些 Electron 应用可能不支持
- PDF 阅读器可能不支持

### Future Enhancements (v2.0)
- 强制取词功能（菜单栏动作复制、模拟 Cmd+C）
- 覆盖率提升到 95%+
- 应用白名单智能学习
- 浮动图标显示（类似 PopClip）
