# Proposal: Add Text Selection Auto-Copy with Unified Filtering

## Metadata
- **Change ID**: add-text-selection-auto-copy
- **Version**: 0.5.0
- **Date**: 2026-02-06
- **Owner**: @聂宇杰
- **Status**: Draft

## Why (Motivation)

### Problem Statement
当前 SenseFlow 只能捕获用户主动复制（Cmd+C）的内容。用户在阅读文档、浏览网页时，经常需要先选中文本，然后按 Cmd+C 复制，这增加了操作步骤。同时，现有的应用过滤功能（filter_app_list）虽然在设置界面中存在，但实际上并未在 ClipboardMonitor 中实现，导致用户配置无效。

### User Pain Points
1. **额外操作步骤**：每次都需要手动按 Cmd+C 才能保存到历史
2. **工作流中断**：需要记住按快捷键，打断思维流程
3. **应用过滤失效**：用户在设置中配置的应用黑名单不生效
4. **过滤逻辑分散**：敏感数据过滤直接写在 ClipboardMonitor 中，难以复用

### Opportunity
通过实现划词即复制功能和统一的过滤管理器，让用户可以：
- 选中文本后自动复制到剪贴板历史（可选功能）
- 在一个地方配置所有过滤规则（敏感数据、密码管理器、应用黑名单）
- 两个监听器（剪贴板监听、文本选择监听）共享相同的过滤逻辑
- 提高代码可维护性和可测试性

### Reference Research
基于对 Easydict 项目的深入调研（详见 `docs/refs.md`），我们采用以下技术方案：
- **主动查询模式**：监听鼠标 mouseUp 事件 + Accessibility API 主动查询选中文本
- **不使用通知机制**：避免 AXObserver + kAXSelectedTextChangedNotification 的可靠性问题
- **统一过滤管理**：参考 Easydict 的 SelectionWorkflow，创建独立的过滤管理器

## What (Changes)

### Core Capabilities

#### 1. 统一过滤管理器（ClipboardFilterManager）
**职责**：集中管理所有过滤规则
- 敏感数据类型过滤（从 ClipboardMonitor 迁移）
- 密码管理器过滤（内置列表 + 用户开关）
- 应用黑名单过滤（实现现有的 filter_app_list 功能）
- 提供统一的公开接口供两个监听器调用

**过滤规则优先级**：
1. 敏感数据类型（TransientType、ConcealedType 等）
2. 密码管理器（1Password、LastPass、Bitwarden 等）
3. 用户自定义黑名单（Bundle ID 或应用名称）

#### 2. 文本选择监听器（TextSelectionMonitor）
**职责**：监听用户文本选择并自动复制
- 监听全局鼠标 leftMouseUp 事件
- 延迟 100ms 后主动查询 Accessibility API 获取选中文本
- 调用 ClipboardFilterManager 判断是否应该过滤
- 如果通过过滤，自动写入剪贴板
- 触发 ClipboardMonitor 的暂停机制避免循环捕获

**技术实现**：
- 使用 NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp)
- 使用 AXUIElementCopyAttributeValue 读取 kAXSelectedTextAttribute
- 最小文本长度过滤（默认 3 字符）

#### 3. 修改现有 ClipboardMonitor
**变更**：使用 ClipboardFilterManager 替代内部过滤逻辑
- 移除 `containsSensitiveData()` 方法
- 在 `shouldProcessPasteboard()` 中调用 ClipboardFilterManager
- 实现应用级别过滤（之前缺失的功能）

#### 4. 设置界面增强
**新增设置项**（高级设置 Tab）：
- ☑️ 划词即复制（默认开启）
- 最小文本长度：[3] 字符
- 说明文字："选中文本后自动复制到剪贴板历史"

**现有设置项**（隐私设置 Tab）：
- 保持现有的"应用过滤列表"文本编辑器
- 现在会真正生效（通过 ClipboardFilterManager）

### Architecture Changes

**新增文件**：
- `SenseFlow/Managers/ClipboardFilterManager.swift` - 统一过滤管理器
- `SenseFlow/Services/TextSelectionMonitor.swift` - 文本选择监听器

**修改文件**：
- `SenseFlow/Services/ClipboardMonitor.swift` - 使用 ClipboardFilterManager
- `SenseFlow/Views/Settings/AdvancedSettingsView.swift` - 添加划词复制设置
- `SenseFlow/Constants/UserDefaultsKeys.swift` - 添加新的配置键
- `SenseFlow/Constants/Strings.swift` - 添加新的文本常量
- `SenseFlow/AppDelegate.swift` - 启动 TextSelectionMonitor

### Non-Goals (Out of Scope)
- ❌ 强制取词功能（模拟 Cmd+C 或菜单栏操作）- 留待 v2.0
- ❌ 应用白名单智能学习 - 留待 v2.0
- ❌ 浮动图标显示（类似 PopClip）- 不在产品规划中
- ❌ 修改引导页说明 - 本次只实现功能，引导页更新留待后续

## How (Implementation)

### Phase 1: 创建 ClipboardFilterManager（优先）
1. 创建 `ClipboardFilterManager.swift`
2. 定义公开接口 `shouldFilter(pasteboardTypes:appBundleID:appName:) -> FilterResult`
3. 实现敏感数据过滤（从 ClipboardMonitor 迁移）
4. 实现密码管理器过滤（内置列表）
5. 实现应用黑名单过滤（读取 filter_app_list）
6. 添加单元测试（可选）

### Phase 2: 修改 ClipboardMonitor 使用过滤器
1. 修改 `shouldProcessPasteboard()` 调用 ClipboardFilterManager
2. 移除内部的 `containsSensitiveData()` 方法
3. 移除 `sensitiveTypes` 属性
4. 验证现有功能不受影响

### Phase 3: 创建 TextSelectionMonitor
1. 创建 `TextSelectionMonitor.swift`
2. 实现鼠标事件监听
3. 实现 Accessibility API 查询
4. 调用 ClipboardFilterManager 过滤
5. 实现自动复制逻辑
6. 在 AppDelegate 中启动监听器

### Phase 4: 添加设置界面
1. 在 AdvancedSettingsView 添加划词复制开关
2. 添加最小文本长度设置
3. 添加 UserDefaultsKeys 常量
4. 添加 Strings 常量
5. 更新 AdvancedSettingsView 的重置逻辑

### Phase 5: 集成测试
1. 测试划词复制在不同应用中的表现
2. 测试应用过滤是否生效
3. 测试敏感数据过滤是否正常
4. 测试性能（CPU 占用、响应速度）
5. 测试边缘情况（快速划词、空文本等）

## Success Criteria

### Functional Requirements
- ✅ 用户选中文本后自动复制到剪贴板历史
- ✅ 用户可以在高级设置中开关此功能
- ✅ 应用黑名单过滤真正生效
- ✅ 敏感数据过滤继续正常工作
- ✅ 两个监听器共享相同的过滤逻辑

### Performance Requirements
- ✅ CPU 占用保持 < 0.1%
- ✅ 文本选择响应延迟 < 200ms
- ✅ 不影响现有剪贴板监听性能

### Quality Requirements
- ✅ 代码符合单一职责原则
- ✅ 过滤逻辑集中管理，易于维护
- ✅ 公开接口清晰，易于测试

## Risks and Mitigations

### Risk 1: Accessibility API 兼容性
**风险**：某些应用不支持 Accessibility API 读取选中文本
**影响**：划词复制在这些应用中失效
**缓解**：
- 静默失败，不影响用户体验
- 在设置中说明可能的兼容性问题
- 提供应用黑名单让用户自行排除

### Risk 2: 性能影响
**风险**：全局鼠标事件监听可能影响性能
**影响**：系统响应变慢
**缓解**：
- 使用 100ms 防抖避免频繁触发
- 最小文本长度过滤减少无效操作
- 性能测试验证 CPU 占用

### Risk 3: 循环捕获
**风险**：划词复制写入剪贴板后被 ClipboardMonitor 再次捕获
**影响**：重复记录
**缓解**：
- 复用 ClipboardMonitor 的 pauseMonitoring() 机制
- 写入剪贴板前暂停监听 1 秒

### Risk 4: 用户体验
**风险**：用户可能不喜欢自动复制行为
**影响**：用户投诉
**缓解**：
- 默认开启，但在设置中可关闭
- 提供最小文本长度设置避免误触发
- 在引导页说明此功能（后续更新）

## Dependencies

### Internal Dependencies
- ClipboardMonitor（需要修改）
- DatabaseManager（无需修改，通过 ClipboardMonitor 间接使用）
- UserDefaults（读取配置）
- BusinessRules（常量定义）

### External Dependencies
- macOS Accessibility Framework（系统 API）
- NSEvent（系统 API）
- NSWorkspace（系统 API）

### Permission Requirements
- Accessibility 权限（项目已有）

## Alternatives Considered

### Alternative 1: 使用 AXObserver 通知机制
**方案**：监听 kAXSelectedTextChangedNotification
**优势**：理论上更精确
**劣势**：
- 系统重启后可能失效
- 应用兼容性差
- 实现复杂度高
**决策**：❌ 不采用，基于 Easydict 的经验，主动查询更可靠

### Alternative 2: 不创建独立的 FilterManager
**方案**：在两个 Monitor 中分别实现过滤逻辑
**优势**：实现简单
**劣势**：
- 代码重复
- 难以维护
- 违反 DRY 原则
**决策**：❌ 不采用，统一管理更符合架构原则

### Alternative 3: 强制取词功能（模拟 Cmd+C）
**方案**：当 Accessibility API 失败时，模拟键盘事件
**优势**：覆盖率更高（95%+）
**劣势**：
- 实现复杂度高
- 可能触发系统提示音
- 可能被安全软件拦截
**决策**：⏸️ 暂不实现，留待 v2.0 根据用户反馈决定

## Open Questions

1. **最小文本长度默认值**：3 字符是否合适？
   - 建议：先用 3，根据用户反馈调整

2. **是否需要最大文本长度限制**？
   - 建议：暂不限制，依赖现有的数据库限制

3. **是否需要在引导页说明此功能**？
   - 建议：本次不修改引导页，留待后续统一更新

4. **是否需要添加"强制取词"高级选项**？
   - 建议：v1.0 不添加，v2.0 根据用户反馈决定

## Timeline Estimate

- **Phase 1**: 4 hours（创建 ClipboardFilterManager）
- **Phase 2**: 2 hours（修改 ClipboardMonitor）
- **Phase 3**: 4 hours（创建 TextSelectionMonitor）
- **Phase 4**: 2 hours（添加设置界面）
- **Phase 5**: 2 hours（集成测试）
- **Total**: ~14 hours

## References

- Easydict 项目调研：`docs/refs.md` (2026-02-06)
- Apple Accessibility API 文档：https://developer.apple.com/documentation/accessibility
- SelectedTextKit 库：https://github.com/tisfeng/SelectedTextKit
- KeySender 库：https://github.com/jordanbaird/KeySender
