# Tasks: 修复 AI 服务配置错误

**Change ID**: `fix-ai-service-config`

## Implementation Tasks

### Phase 1: Context7 调研（已完成）
- [x] 1.1 查询 MacPaw OpenAI SDK Configuration 参数
- [x] 1.2 查询 OpenRouter、Gemini、DeepSeek 配置
- [x] 1.3 更新 `docs/refs.md` 记录调研结果

### Phase 2: 重构服务配置模型
- [ ] 2.1 在 `AIServiceType` 添加 `.openrouter` case
- [ ] 2.2 重构 `defaultEndpoint` → `sdkConfiguration` 计算属性
- [ ] 2.3 更新 `defaultModel` 返回正确的模型名称
- [ ] 2.4 添加 `displayName` 支持 OpenRouter

### Phase 3: 重构 AIService 配置逻辑
- [ ] 3.1 移除 `getEndpoint()` 方法
- [ ] 3.2 重构 `getOrCreateClient()` 使用 `sdkConfiguration`
- [ ] 3.3 添加 `parsingOptions: .relaxed` 支持非 OpenAI 服务
- [ ] 3.4 更新 `getVisionModel()` 支持 OpenRouter

### Phase 4: 更新 Keychain 支持
- [ ] 4.1 在 `KeychainManager.Keys` 添加 `openrouterAPIKey`
- [ ] 4.2 更新 `getAPIKey(for:)` 支持 `.openrouter`
- [ ] 4.3 更新 `saveAPIKey(_:for:)` 支持 `.openrouter`

### Phase 5: 更新 UI
- [ ] 5.1 在 `PromptToolsSettingsView` Picker 添加 OpenRouter 选项
- [ ] 5.2 验证 API Key 输入对所有服务正常工作

### Phase 6: 验证和测试
- [ ] 6.1 测试 OpenAI 配置（基准）
- [ ] 6.2 测试 Gemini 配置（新 endpoint）
- [ ] 6.3 测试 DeepSeek 配置
- [ ] 6.4 测试 OpenRouter 配置（Claude 模型）
- [ ] 6.5 测试 Ollama 本地配置

### Phase 7: 文档更新
- [ ] 7.1 更新用户文档说明 OpenRouter 用途
- [ ] 7.2 添加迁移说明（Claude → OpenRouter）

## Validation Criteria

- 所有服务商（OpenAI/Gemini/DeepSeek/OpenRouter/Ollama）均可成功调用
- Vision API 仅在 OpenAI 服务启用
- 配置变更后自动重置客户端
- API Key 安全存储在 Keychain

## Dependencies

- 无外部依赖
- 需要用户提供各服务商的 API Key 进行测试
