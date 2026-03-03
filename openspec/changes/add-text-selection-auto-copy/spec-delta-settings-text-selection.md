# Spec Delta: settings-text-selection

## Metadata
- **Capability ID**: settings-text-selection
- **Type**: enhancement
- **Change ID**: add-text-selection-auto-copy
- **Version**: 0.5.0

## Summary
在高级设置界面添加文本选择自动复制功能的配置选项，包括功能开关和最小文本长度设置。

## Requirements

### REQ-STS-001: 功能开关
- **Priority**: MUST
- **Description**: 添加 Toggle 控件控制文本选择自动复制功能
- **Implementation**:
  - 使用 `@AppStorage("text_selection_auto_copy_enabled")` 绑定
  - 默认值：true（默认开启）
  - 标签文本：使用 `Strings.AdvancedSettings.textSelectionToggle`
- **Location**: AdvancedSettingsView，新增 Section

### REQ-STS-002: 最小文本长度设置
- **Priority**: MUST
- **Description**: 添加控件设置最小文本长度（字符数）
- **Implementation**:
  - 使用 `@AppStorage("text_selection_min_length")` 绑定
  - 默认值：3 字符
  - 控件类型：Stepper 或 TextField
  - 标签文本：使用 `Strings.AdvancedSettings.minLengthLabel`
  - 帮助文本：使用 `Strings.AdvancedSettings.minLengthHelp`
- **Constraints**:
  - 最小值：1 字符
  - 最大值：100 字符
  - 步进值：1 字符

### REQ-STS-003: 说明文字
- **Priority**: MUST
- **Description**: 添加功能说明文字
- **Content**: "选中文本后自动复制到剪贴板历史"
- **Implementation**: 使用 `Strings.AdvancedSettings.textSelectionDescription`
- **Style**: `.font(.caption)`, `.foregroundStyle(.secondary)`

### REQ-STS-004: 布局规范
- **Priority**: MUST
- **Description**: 遵循 macOS 设置界面标准布局
- **Implementation**:
  - 使用 Form + Section 布局
  - 使用 `.formStyle(.grouped)`
  - 使用 `.compatibleControlSize()`
  - 与现有设置项保持一致的间距和对齐

### REQ-STS-005: 重置逻辑更新
- **Priority**: MUST
- **Description**: 更新 `resetToDefaults()` 方法，重置新增的设置项
- **Implementation**:
  - `defaults.removeObject(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled)`
  - `defaults.removeObject(forKey: UserDefaultsKeys.textSelectionMinLength)`
- **Behavior**: 点击"重置为默认值"按钮后，新设置项恢复默认值

### REQ-STS-006: 实时生效
- **Priority**: MUST
- **Description**: 设置修改后立即生效，无需重启应用
- **Rationale**: 提供良好的用户体验
- **Implementation**: 使用 `@AppStorage` 自动同步到 UserDefaults

### REQ-STS-007: UserDefaults 常量
- **Priority**: MUST
- **Description**: 在 UserDefaultsKeys.swift 添加新的常量
- **Constants**:
  - `textSelectionAutoCopyEnabled = "text_selection_auto_copy_enabled"`
  - `textSelectionMinLength = "text_selection_min_length"`
- **Rationale**: 避免硬编码字符串，便于维护

### REQ-STS-008: Strings 常量
- **Priority**: MUST
- **Description**: 在 Strings.swift 添加新的文本常量
- **Constants**:
  - `AdvancedSettings.textSelectionToggle` - Toggle 标签
  - `AdvancedSettings.textSelectionDescription` - 功能说明
  - `AdvancedSettings.minLengthLabel` - 最小长度标签
  - `AdvancedSettings.minLengthHelp` - 最小长度帮助文本
- **Rationale**: 集中管理文本，便于国际化

### REQ-STS-009: 帮助文本
- **Priority**: SHOULD
- **Description**: 为控件添加 `.help()` 修饰符提供悬停提示
- **Content**:
  - Toggle: "启用后，选中文本会自动复制到剪贴板历史"
  - Stepper: "设置触发自动复制的最小文本长度，避免误触发"
- **Rationale**: 帮助用户理解功能

### REQ-STS-010: 视觉层次
- **Priority**: SHOULD
- **Description**: 使用视觉层次区分主要控件和说明文字
- **Implementation**:
  - Toggle 使用默认字体和颜色
  - 说明文字使用 `.caption` 字体和 `.secondary` 颜色
  - 帮助文本使用 `.help()` 修饰符（悬停显示）

## Scenarios

### SCENARIO-STS-001: 打开设置界面
**Given**: 用户打开应用设置
**When**: 切换到"高级设置" Tab
**Then**:
- 显示"划词即复制"功能开关（默认开启）
- 显示"最小文本长度"设置（默认 3）
- 显示功能说明文字

### SCENARIO-STS-002: 关闭功能
**Given**: 用户在高级设置界面
**When**: 关闭"划词即复制"开关
**Then**:
- 开关状态变为关闭
- UserDefaults `text_selection_auto_copy_enabled` 设置为 false
- TextSelectionMonitor 立即停止自动复制（无需重启）

### SCENARIO-STS-003: 修改最小长度
**Given**: 用户在高级设置界面
**When**: 将最小长度从 3 修改为 5
**Then**:
- 显示值更新为 5
- UserDefaults `text_selection_min_length` 设置为 5
- TextSelectionMonitor 立即使用新的最小长度（无需重启）

### SCENARIO-STS-004: 重置为默认值
**Given**: 用户修改了设置（关闭开关，最小长度改为 10）
**When**: 点击"重置为默认值"按钮并确认
**Then**:
- "划词即复制"开关恢复为开启
- 最小长度恢复为 3
- 显示成功提示
- 所有设置立即生效

### SCENARIO-STS-005: 悬停查看帮助
**Given**: 用户在高级设置界面
**When**: 鼠标悬停在"划词即复制"开关上
**Then**: 显示帮助文本："启用后，选中文本会自动复制到剪贴板历史"

### SCENARIO-STS-006: 最小长度边界值
**Given**: 用户在高级设置界面
**When**: 尝试将最小长度设置为 0 或 101
**Then**:
- 如果使用 Stepper，自动限制在 1-100 范围内
- 如果使用 TextField，显示验证错误

## Dependencies

### Internal Dependencies
- UserDefaultsKeys.swift（常量定义）
- Strings.swift（文本常量）
- AdvancedSettingsView.swift（UI 实现）

### External Dependencies
- SwiftUI（UI 框架）
- AppStorage（数据绑定）

## Notes

### Implementation Notes
- 推荐使用 Stepper 而非 TextField，因为：
  - 自动处理边界值
  - 更符合 macOS 设置界面规范
  - 用户体验更好
- Section 标题可以使用 "文本选择" 或直接放在现有 Section 中
- 考虑将此功能放在"高级设置"而非"隐私设置"，因为它是功能性设置而非隐私设置

### UI Mockup (Text Description)
```
高级设置
┌─────────────────────────────────────┐
│ 文本选择                             │
│                                     │
│ ☑ 划词即复制                         │
│   选中文本后自动复制到剪贴板历史       │
│                                     │
│ 最小文本长度：[3] 字符               │
│   (使用 Stepper，范围 1-100)         │
│                                     │
└─────────────────────────────────────┘
```

### Testing Notes
- 测试开关切换后立即生效
- 测试最小长度修改后立即生效
- 测试重置功能正确恢复默认值
- 测试边界值（1, 100）
- 测试帮助文本显示

### Accessibility Notes
- 所有控件应该有正确的 accessibility label
- 帮助文本应该通过 VoiceOver 可读
- 键盘导航应该正常工作

### Future Enhancements
- 添加"强制取词"高级选项（v2.0）
- 添加应用白名单管理界面（v2.0）
- 添加预览功能（显示当前设置下会触发的文本长度）
