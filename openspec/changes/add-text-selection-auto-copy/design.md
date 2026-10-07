# Design: Add Text Selection Auto-Copy with Unified Filtering

## Metadata
- **Change ID**: add-text-selection-auto-copy
- **Version**: 0.5.0
- **Date**: 2026-02-06

## Architecture Overview

### Core Design Principles

1. **单一职责原则（Single Responsibility Principle）**
   - ClipboardFilterManager：只负责过滤逻辑
   - ClipboardMonitor：只负责剪贴板监听
   - TextSelectionMonitor：只负责文本选择监听

2. **依赖注入（Dependency Injection）**
   - 两个监听器都依赖 ClipboardFilterManager
   - 通过公开接口调用，不直接访问内部实现

3. **DRY 原则（Don't Repeat Yourself）**
   - 过滤逻辑只在一个地方实现
   - 避免在两个监听器中重复代码

## Component Design

### 1. ClipboardFilterManager

**设计目标**：统一管理所有过滤规则

**公开接口**：
```
shouldFilter(
    pasteboardTypes: [NSPasteboard.PasteboardType]?,
    appBundleID: String?,
    appName: String?
) -> FilterResult
```

**FilterResult 结构**：
```
struct FilterResult {
    let shouldFilter: Bool
    let reason: FilterReason?
}

enum FilterReason {
    case sensitiveData
    case passwordManager
    case blacklistedApp
}
```

**内部实现**：
- `containsSensitiveData()` - 检查敏感数据类型
- `isPasswordManager()` - 检查密码管理器
- `isInUserBlacklist()` - 检查用户黑名单

**过滤优先级**：
1. 敏感数据类型（最高优先级）
2. 密码管理器（中优先级）
3. 用户黑名单（最低优先级）

**设计决策**：
- ✅ 使用单例模式（shared instance）- 全局只需一个实例
- ✅ 返回 FilterResult 而非 Bool - 便于调试和日志记录
- ✅ 接受可选参数 - 某些场景可能缺少应用信息

### 2. TextSelectionMonitor

**设计目标**：监听文本选择并自动复制

**技术选型**：主动查询模式（Active Query Pattern）

**为什么不用 AXObserver 通知机制？**
- ❌ 系统重启后可能失效
- ❌ 应用兼容性差（很多应用不发送通知）
- ❌ 实现复杂度高（需要为每个应用创建 observer）

**为什么用 NSEvent.leftMouseUp + Accessibility API？**
- ✅ 可靠性高（Easydict 验证过的方案）
- ✅ 实现简单（全局事件监听 + 主动查询）
- ✅ 覆盖率 70-80%（足够 MVP）

**事件流程**：
```
1. 用户选中文本并释放鼠标
2. NSEvent.leftMouseUp 触发
3. 延迟 100ms（确保选择完成）
4. 调用 ClipboardFilterManager.shouldFilter()
5. 如果通过过滤，调用 Accessibility API 获取文本
6. 检查最小文本长度
7. 写入剪贴板
8. 暂停 ClipboardMonitor 1 秒（避免循环）
```

**设计决策**：
- ✅ 100ms 延迟 - 确保选择操作完成
- ✅ 最小文本长度过滤 - 避免误触发（默认 3 字符）
- ✅ 暂停 ClipboardMonitor - 复用现有机制避免循环捕获
- ⏸️ 强制取词功能 - 留待 v2.0（覆盖率提升到 95%+）

### 3. ClipboardMonitor 重构

**变更内容**：
- 移除内部过滤逻辑（`containsSensitiveData()` 方法）
- 调用 ClipboardFilterManager 统一过滤
- 实现应用级别过滤（之前缺失的功能）

**重构前**：
```
shouldProcessPasteboard() {
    if containsSensitiveData() { return false }
    // 缺少应用过滤
    return true
}
```

**重构后**：
```
shouldProcessPasteboard() {
    let result = ClipboardFilterManager.shared.shouldFilter(
        pasteboardTypes: pasteboard.types,
        appBundleID: app.bundleIdentifier,
        appName: app.localizedName
    )
    if result.shouldFilter {
        print("Filtered: \(result.reason)")
        return false
    }
    return true
}
```

**设计决策**：
- ✅ 完全移除内部过滤逻辑 - 避免重复
- ✅ 打印过滤原因 - 便于调试
- ✅ 保持现有接口不变 - 最小化影响

## Data Flow

### 剪贴板监听流程（现有功能）

```
用户按 Cmd+C
    ↓
NSPasteboard 变化
    ↓
ClipboardMonitor.pasteboardDidChange()
    ↓
shouldProcessPasteboard()
    ↓
ClipboardFilterManager.shouldFilter()
    ├─ 敏感数据？→ 过滤
    ├─ 密码管理器？→ 过滤
    ├─ 黑名单应用？→ 过滤
    └─ 通过 → 保存到数据库
```

### 文本选择监听流程（新功能）

```
用户选中文本并释放鼠标
    ↓
NSEvent.leftMouseUp 触发
    ↓
延迟 100ms
    ↓
检查功能开关（text_selection_auto_copy_enabled）
    ↓
ClipboardFilterManager.shouldFilter()
    ├─ 敏感数据？→ 停止
    ├─ 密码管理器？→ 停止
    ├─ 黑名单应用？→ 停止
    └─ 通过 ↓
Accessibility API 获取选中文本
    ↓
检查最小文本长度
    ↓
写入剪贴板
    ↓
暂停 ClipboardMonitor 1 秒
    ↓
ClipboardMonitor 自动捕获并保存
```

## Integration Points

### 1. ClipboardFilterManager ↔ ClipboardMonitor
- ClipboardMonitor 调用 `shouldFilter()` 判断是否处理
- 传入 pasteboard.types, app.bundleIdentifier, app.localizedName
- 根据返回的 FilterResult 决定是否保存

### 2. ClipboardFilterManager ↔ TextSelectionMonitor
- TextSelectionMonitor 调用 `shouldFilter()` 判断是否复制
- 传入 nil（pasteboardTypes），app.bundleIdentifier, app.localizedName
- 只检查应用级别过滤（敏感数据类型在复制后由 ClipboardMonitor 检查）

### 3. TextSelectionMonitor ↔ ClipboardMonitor
- TextSelectionMonitor 写入剪贴板前调用 `ClipboardMonitor.shared.pauseMonitoring(duration: 1.0)`
- 避免循环捕获（TextSelectionMonitor 写入 → ClipboardMonitor 捕获 → 重复记录）
- 复用现有的暂停机制

### 4. TextSelectionMonitor ↔ UserDefaults
- 读取 `text_selection_auto_copy_enabled` 开关
- 读取 `text_selection_min_length` 最小长度
- 实时响应设置变化

## Trade-offs and Alternatives

### Trade-off 1: 主动查询 vs 被动通知

**主动查询（采用）**：
- ✅ 可靠性高
- ✅ 实现简单
- ❌ 覆盖率 70-80%

**被动通知（不采用）**：
- ✅ 理论上更精确
- ❌ 可靠性差
- ❌ 实现复杂

**决策**：采用主动查询，基于 Easydict 的实践经验

### Trade-off 2: MVP vs 完整功能

**MVP（采用）**：
- ✅ 快速上线
- ✅ 验证用户需求
- ❌ 覆盖率 70-80%

**完整功能（不采用）**：
- ✅ 覆盖率 95%+
- ❌ 实现复杂度高
- ❌ 可能触发系统提示音
- ❌ 可能被安全软件拦截

**决策**：先实现 MVP，根据用户反馈决定是否实现强制取词

### Trade-off 3: 统一过滤器 vs 分散过滤

**统一过滤器（采用）**：
- ✅ 代码复用
- ✅ 易于维护
- ✅ 单一职责
- ❌ 需要重构现有代码

**分散过滤（不采用）**：
- ✅ 实现简单
- ❌ 代码重复
- ❌ 难以维护
- ❌ 违反 DRY 原则

**决策**：采用统一过滤器，符合架构原则

## Performance Considerations

### CPU 占用
- **目标**：< 0.1%
- **策略**：
  - 100ms 防抖避免频繁触发
  - 最小文本长度过滤减少无效操作
  - 只在鼠标释放时查询，不持续监听

### 响应延迟
- **目标**：< 200ms
- **策略**：
  - Accessibility API 查询通常 < 50ms
  - 100ms 延迟确保选择完成
  - 总延迟约 150ms

### 内存占用
- **目标**：无明显增长
- **策略**：
  - 单例模式避免重复实例
  - 不缓存选中文本
  - 及时释放 event monitor

## Security Considerations

### 敏感数据保护
- 敏感数据类型过滤（TransientType、ConcealedType 等）
- 密码管理器过滤（1Password、LastPass、Bitwarden 等）
- 用户自定义黑名单

### 权限要求
- Accessibility 权限（项目已有）
- 不需要额外权限

### 隐私保护
- 在引导页说明会记录文本选择
- 提供开关让用户控制
- 提供黑名单让用户排除应用

## Testing Strategy

### 单元测试（可选）
- ClipboardFilterManager.shouldFilter() 各种场景
- 敏感数据类型检测
- 密码管理器检测
- 黑名单检测

### 集成测试
- 划词复制 + 剪贴板监听协同工作
- 过滤规则在两个监听器中一致生效
- 设置修改后立即生效

### 性能测试
- CPU 占用 < 0.1%
- 响应延迟 < 200ms
- 快速连续划词的稳定性

### 兼容性测试
- TextEdit（标准 Cocoa 应用）
- Safari（浏览器）
- Chrome（浏览器）
- Terminal（可能失败，预期行为）
- VSCode（Electron 应用）

## Migration Strategy

### Phase 1: 创建 ClipboardFilterManager
- 不影响现有功能
- 独立开发和测试

### Phase 2: 重构 ClipboardMonitor
- 替换内部过滤逻辑
- 验证现有功能不受影响
- 实现应用过滤（之前缺失的功能）

### Phase 3: 创建 TextSelectionMonitor
- 独立开发和测试
- 不影响现有功能

### Phase 4: 集成测试
- 验证两个监听器协同工作
- 验证过滤规则一致生效

### Phase 5: 用户测试
- 收集用户反馈
- 根据反馈调整参数（最小文本长度、延迟时间等）

## Future Enhancements (v2.0)

### 强制取词功能
- 菜单栏动作复制（Menu Bar Action Copy）
- 模拟快捷键复制（Simulated Cmd+C）
- 覆盖率提升到 95%+

### 应用白名单智能学习
- 记录用户在哪些应用中使用划词复制
- 自动优化过滤规则

### 性能优化
- 缓存 Accessibility API 查询结果
- 优化防抖策略

### 用户体验优化
- 浮动图标显示（类似 PopClip）
- 划词后的视觉反馈
- 更细粒度的过滤规则

## Open Questions

1. **最小文本长度默认值**：3 字符是否合适？
   - 建议：先用 3，根据用户反馈调整

2. **是否需要最大文本长度限制**？
   - 建议：暂不限制，依赖现有的数据库限制

3. **是否需要在引导页说明此功能**？
   - 建议：本次不修改引导页，留待后续统一更新

4. **是否需要添加"强制取词"高级选项**？
   - 建议：v1.0 不添加，v2.0 根据用户反馈决定

## References

- Easydict SelectionWorkflow.swift - 主动查询模式实现
- Apple Accessibility API 文档
- SelectedTextKit 库
- KeySender 库
