# Proposal: Add API Request Inspector

## Why

开发者需要查看每次发送给 AI API 的完整请求内容，以便：
1. **调试 Prompt** - 查看实际发送的 system prompt 和 user input
2. **验证配置** - 确认 model、endpoint、参数是否正确
3. **优化性能** - 分析 token 使用情况
4. **排查问题** - 快速定位 API 调用失败的原因

当前开发者选项只显示 system prompt，缺少完整的请求/响应信息。

## Problem Statement

**当前状态：**
- 开发者选项只显示 system prompt 文本框
- 无法查看实际发送给 API 的完整请求
- 无法查看 API 返回的原始响应
- 调试 Prompt Tools 时缺少关键信息

**用户痛点：**
- 不知道 system prompt 是否正确传递
- 不知道 user input 的实际内容
- 不知道使用了哪个 model 和 endpoint
- API 失败时无法查看错误详情

## Proposed Solution

在开发者选项中添加 **API Request Inspector** 功能，实时展示最近的 API 请求和响应。

### 功能设计

**1. 请求记录器（Request Logger）**
- 拦截所有 AI API 调用
- 记录最近 10 次请求/响应
- 包含时间戳、服务类型、model、状态

**2. 展示界面（Inspector UI）**
- 请求列表（时间倒序）
- 请求详情（可展开/折叠）
- 响应详情（成功/失败）
- 复制按钮（方便分享调试）

**3. 展示内容**

每个请求包含：
```
📤 Request
├── Timestamp: 2026-02-26 14:30:45
├── Service: OpenAI (gpt-4o-mini)
├── Endpoint: https://api.openai.com/v1/chat/completions
├── Messages:
│   ├── System: "你是一个翻译助手..."
│   └── User: "Hello world"
└── Status: ✅ Success (1.2s)

📥 Response
├── Content: "你好世界"
├── Tokens: 15 (prompt) + 8 (completion) = 23 total
└── Model: gpt-4o-mini-2024-07-18
```

### UI 结构优化

```
开发者选项
├── Langfuse 集成（现有）
│   ├── 启用开关
│   ├── Public/Secret Key
│   ├── 同步间隔
│   └── 立即同步按钮
│
└── API Request Inspector（新增）
    ├── 启用调试模式开关
    ├── 请求历史列表（最近 10 条）
    │   ├── 时间 | 服务 | 状态
    │   └── 点击展开详情
    └── 清空历史按钮
```

## Scope

**In Scope:**
- 添加 `APIRequestLogger` 单例记录请求
- 在 `AIService.generate()` 中记录请求/响应
- 在开发者选项添加 Inspector UI
- 支持展开/折叠详情
- 支持复制请求内容

**Out of Scope:**
- 持久化存储（仅内存，重启清空）
- 导出到文件
- 过滤/搜索功能
- 实时流式显示

## Success Criteria

1. 每次 AI API 调用都被记录
2. 开发者选项可查看最近 10 次请求
3. 请求详情包含完整的 messages 和 response
4. UI 清晰易读，支持展开/折叠
5. 性能无影响（异步记录）

## Risks & Mitigation

**Risk:** 记录敏感信息（API Key）
**Mitigation:** 只记录请求内容，不记录 API Key

**Risk:** 内存占用过大
**Mitigation:** 只保留最近 10 条，自动清理旧记录

**Risk:** UI 过于复杂
**Mitigation:** 默认折叠，点击展开详情
