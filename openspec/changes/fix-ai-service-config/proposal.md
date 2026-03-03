# Proposal: 修复 AI 服务配置错误

**Change ID**: `fix-ai-service-config`
**Created**: 2026-01-22
**Status**: Draft

## Problem Statement

当前 AIService 的配置存在多个严重错误，导致除 OpenAI 外的所有服务商（Claude、Gemini、DeepSeek、OpenRouter）无法正常工作：

1. **错误的 Endpoint 解析逻辑** - 代码从完整 URL 提取 host/port，而 MacPaw SDK 需要直接传递这些参数
2. **Claude Endpoint 错误** - 使用 `api.anthropic.com`，但 MacPaw SDK 不支持 Claude 原生格式（需 OpenAI 兼容层）
3. **缺少 OpenRouter 支持** - 用户提到需要支持 OpenRouter
4. **配置参数混乱** - 当前代码在 `defaultEndpoint` 返回完整 URL，但 MacPaw SDK 不接受完整 URL

### Current Issues

```swift
// AIService.swift:111-120 (错误的实现)
if let endpointURL = URL(string: endpoint) {
    let port = endpointURL.port ?? (endpointURL.scheme == "https" ? 443 : 80)
    let configuration = OpenAI.Configuration(
        token: apiKey,
        host: endpointURL.host ?? "api.openai.com",
        port: port,
        scheme: endpointURL.scheme ?? "https",
        timeoutInterval: 30.0
    )
}
```

**问题**:
- `defaultEndpoint` 返回完整 URL（如 `https://api.anthropic.com/v1`）
- URL 解析会提取出错误的 host（包含 `/v1` 路径）
- MacPaw SDK 期望 `host` 为纯域名，不包含路径

## Proposed Solution

### 方案：重构服务配置为结构化参数

使用 MacPaw SDK 的标准配置方式，为每个服务商定义 `host`、`scheme`、`port`、`model` 参数：

```swift
enum AIServiceType {
    var sdkConfiguration: (host: String, scheme: String, port: Int, model: String) {
        switch self {
        case .openai:
            return ("api.openai.com", "https", 443, "gpt-4o-mini")
        case .claude:
            // 使用 OpenRouter 转发（MacPaw SDK 不支持 Claude 原生）
            return ("openrouter.ai", "https", 443, "anthropic/claude-3.5-sonnet")
        case .gemini:
            return ("generativelanguage.googleapis.com", "https", 443, "gemini-2.5-flash")
        case .deepseek:
            return ("api.deepseek.com", "https", 443, "deepseek-chat")
        case .openrouter:
            return ("openrouter.ai", "https", 443, "openai/gpt-4o-mini")
        case .ollama:
            return ("localhost", "http", 11434, "llama2")
        }
    }
}
```

### 配置流程

1. **移除 URL 解析** - 删除 `getEndpoint()` 和 URL 解析逻辑
2. **添加 OpenRouter 支持** - 新增 `.openrouter` 服务类型
3. **Claude 通过 OpenRouter** - Claude 原生 API 不兼容 MacPaw SDK，使用 OpenRouter 转发
4. **更新 Gemini 端点** - 使用正确的 OpenAI 兼容端点（不含 `/v1beta/openai/` 路径）
5. **添加 parsingOptions** - 非 OpenAI 服务使用 `.relaxed` 模式

## Capabilities Affected

- **AI Service Configuration** (MODIFIED)
  - 重构服务商配置结构
  - 移除 URL 解析逻辑
  - 添加 OpenRouter 支持

## Files to Modify

1. `SenseFlow/Models/PromptTool.swift`
   - 重构 `AIServiceType.defaultEndpoint` → `sdkConfiguration`
   - 添加 `.openrouter` case

2. `SenseFlow/Services/AIService.swift`
   - 重构 `getOrCreateClient()` 使用新配置
   - 移除 `getEndpoint()` 方法
   - 添加 `parsingOptions: .relaxed`

3. `SenseFlow/Managers/KeychainManager.swift`
   - 添加 `openrouterAPIKey` 支持

4. `SenseFlow/Views/Settings/PromptToolsSettingsView.swift`
   - 更新 UI 显示 OpenRouter 选项

## Migration Strategy

- 保持向后兼容：已配置的 API Keys 继续有效
- Claude 用户需要：
  1. 注册 OpenRouter 账号（https://openrouter.ai）
  2. 在设置中将服务切换为 "OpenRouter"，选择 Claude 模型

## Questions / Clarifications

1. **Claude 迁移策略** - 是否需要自动迁移现有 Claude 用户到 OpenRouter？
2. **OpenRouter API Key** - 是否需要在 UI 中说明 OpenRouter 可统一管理多个服务商？
3. **Gemini basePath** - 是否需要配置 `basePath: "/v1beta/openai/"`（待验证）

## References

- MacPaw OpenAI SDK: https://github.com/MacPaw/OpenAI
- Context7 调研结果: `docs/refs.md:238-265`
- OpenRouter 文档: https://openrouter.ai/docs
