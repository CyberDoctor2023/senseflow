# 修复去重机制和 Smart AI 提示词

## 问题描述

### 问题 1: 去重机制不会将重复内容移到最前面
当用户复制同一段文字时,剪贴板历史中该内容仍然保持在原来的位置,而不是移到最前面。

**当前行为**:
- 用户第一次复制 "Hello" → 出现在位置 1
- 用户复制其他内容 → "Hello" 移到位置 2
- 用户再次复制 "Hello" → "Hello" 仍在位置 2（被去重跳过）

**期望行为**:
- 用户再次复制 "Hello" → "Hello" 应该移到位置 1（最前面）

### 问题 2: Smart AI 提示词不够明确
Smart AI 的推荐提示词没有强调剪贴板第一条数据是绝对真实唯一来源,导致 AI 偶尔会被屏幕上的文字误导。

**当前问题**:
- AI 可能会分析屏幕截图中的文字
- 没有明确指出剪贴板第一条是用户真正想要操作的内容

## 解决方案

### 1. 修改去重逻辑（DatabaseManager）

**当前逻辑**:
```swift
guard !itemExists(uniqueId: uniqueIdValue) else {
    print("⚠️ 内容已存在，跳过插入")
    return false
}
```

**新逻辑**:
```swift
if itemExists(uniqueId: uniqueIdValue) {
    // 删除旧记录
    deleteItemByUniqueId(uniqueId: uniqueIdValue)
    print("🔄 内容已存在，移到最前面")
}
// 继续插入新记录（会自动排在最前面）
```

### 2. 增强 Smart AI 提示词

**修改位置**: `AIToolRecommendationService.buildRecommendationSystemPrompt()`

**新增规则**:
```
CRITICAL: The clipboard content is the ABSOLUTE SOURCE OF TRUTH.
- The user wants to operate on the clipboard content, NOT the text visible in the screenshot
- The screenshot is ONLY for understanding the context (what app, what task)
- NEVER recommend tools based on text you see in the screenshot
- ALWAYS base your recommendation on the clipboard content
```

## 影响范围

### 文件修改
1. `SenseFlow/Managers/DatabaseManager.swift`
   - 修改 `insertItem()` 方法
   - 新增 `deleteItemByUniqueId()` 方法

2. `SenseFlow/Services/AIToolRecommendationService.swift`
   - 修改 `buildRecommendationSystemPrompt()` 方法

### 测试场景
1. 去重测试:
   - 复制 "Hello" → 复制 "World" → 再次复制 "Hello"
   - 验证 "Hello" 是否在最前面

2. Smart AI 测试:
   - 剪贴板有代码,屏幕显示文档
   - 验证 AI 是否推荐代码相关工具（而非文档工具）

## 风险评估

- **低风险**: 去重逻辑修改简单,不影响其他功能
- **低风险**: 提示词修改不影响代码逻辑

## 参考

- 类似产品（Maccy/Deck）的去重行为: 重复内容会移到最前面
- AI 提示词最佳实践: 明确指定数据优先级
