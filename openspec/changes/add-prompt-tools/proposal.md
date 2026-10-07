# Proposal: Add Prompt Tools Feature

## Metadata
- **Change ID**: add-prompt-tools
- **Version**: 0.2.0
- **Date**: 2026-01-19
- **Owner**: @聂宇杰
- **Status**: Draft

## Why (Motivation)

### Problem Statement
当前 SenseFlow v0.1 只提供剪贴板历史管理功能，用户需要手动将剪贴板内容复制到 AI 工具（如 ChatGPT、Claude）进行处理，然后再复制回来。这个流程繁琐且打断工作流。

### User Pain Points
1. **工作流中断**：需要切换到浏览器/AI 应用，打断当前工作
2. **重复操作**：复制 → 切换应用 → 粘贴 → 等待 → 复制结果 → 切回应用 → 粘贴
3. **无法自动化**：常用的文本处理任务（如格式化、改写）无法快速执行
4. **效率低下**：简单的文本转换需要多次操作

### Opportunity
通过集成 AI 能力，让用户可以：
- 在任意应用中按快捷键直接处理剪贴板内容
- 预设常用的文本处理工具（Markdown 格式化、邮件改写等）
- 结果自动写回剪贴板，无缝衔接工作流
- 支持多个 AI 服务（Claude、OpenAI、Ollama），灵活选择

## What (Changes)

### Core Capabilities
1. **Prompt Tool 管理**
   - 创建/编辑/删除 Tool（名称 + Prompt）
   - 为每个 Tool 绑定独立的全局快捷键
   - 支持快捷键冲突检测

2. **AI 服务集成**
   - 支持 Claude API（Anthropic）
   - 支持 OpenAI API（GPT-4/GPT-3.5）
   - 支持 Ollama（本地模型）
   - 用户可在设置中选择服务并配置 API Key

3. **Tool 执行流程**
   - 用户在任意应用按下 Tool 快捷键
   - 读取当前剪贴板内容作为输入
   - 后台调用 AI API 生成结果
   - 结果写回剪贴板（可选自动粘贴）
   - 静默执行，无 UI 打断

4. **预置默认 Tool 集合**
   - Markdown 规范化
   - 表格生成/修复
   - 小红书成稿
   - 邮件规范化
   - 提取标题输出
   - 用户可删除/修改/恢复默认集合

### User Interface Changes
- **设置面板新增 "Prompt Tools" Tab**
  - Tool 列表（名称、快捷键、编辑/删除按钮）
  - 新建 Tool 按钮
  - AI 服务选择（Claude/OpenAI/Ollama）
  - API Key 配置（安全存储到 Keychain）
  - 恢复默认 Tool 集合按钮

- **Tool 编辑界面**
  - Tool 名称输入框
  - Prompt 多行文本框
  - 快捷键录制器（复用现有组件）
  - 保存/取消按钮

### Data Model Changes
- 新增 `PromptTool` 模型
  - `id: UUID`
  - `name: String`
  - `prompt: String`
  - `shortcutKeyCode: UInt16`
  - `shortcutModifiers: UInt32`
  - `isDefault: Bool`（标记是否为预置 Tool）
  - `createdAt: Date`
  - `updatedAt: Date`

- 新增数据库表 `prompt_tools`
  - 存储用户创建的 Tool
  - 支持 CRUD 操作

- 新增 UserDefaults 配置
  - `selectedAIService: String`（"claude" | "openai" | "ollama"）
  - `ollamaEndpoint: String`（默认 "http://localhost:11434"）
  - `ollamaModel: String`（默认 "llama2"）

- Keychain 存储
  - `claudeAPIKey: String`
  - `openaiAPIKey: String`

### Architecture Changes
- 新增 `Managers/PromptToolManager.swift`
  - 管理 Tool 的 CRUD
  - 注册/注销 Tool 快捷键
  - 执行 Tool（读取剪贴板 → 调用 AI → 写回剪贴板）

- 新增 `Services/AIService.swift`
  - 基于 MacPaw/OpenAI SDK 的统一服务接口
  - 支持自定义 Endpoint（兼容所有 OpenAI API 格式服务）
  - 支持服务商：OpenAI、Claude（通过兼容接口）、DeepSeek、Ollama 等

- 新增 `Views/Settings/PromptToolsSettingsView.swift`
  - Tool 管理 UI
  - AI 服务配置 UI

- 新增 `Views/PromptToolEditorView.swift`
  - Tool 编辑界面

## Impact

### User Impact
- **正面影响**
  - 大幅提升文本处理效率
  - 无缝集成到现有工作流
  - 支持自定义 Tool，满足个性化需求
  - 支持多个 AI 服务，灵活选择

- **学习成本**
  - 需要理解 Prompt Tool 概念
  - 需要配置 API Key（首次使用）
  - 需要学习快捷键

- **潜在问题**
  - API 调用可能失败（网络、配额、API Key 错误）
  - AI 生成结果可能不符合预期
  - 快捷键可能与其他应用冲突

### Technical Impact
- **新增依赖**
  - MacPaw/OpenAI SDK（统一 AI API 调用，支持自定义 Endpoint）
  - KeychainAccess（安全存储 API Key）

- **性能影响**
  - AI API 调用是异步的，不会阻塞 UI
  - 网络请求可能需要 1-10 秒（取决于 AI 服务）
  - 本地 Ollama 响应更快，但需要用户自行安装

- **安全影响**
  - API Key 存储在 Keychain（系统级加密）
  - 剪贴板内容会发送到 AI 服务（需要用户知情同意）
  - 敏感数据过滤机制仍然生效

- **兼容性**
  - 需要 macOS 12.0+（与现有要求一致）
  - 需要网络连接（Ollama 除外）

### Maintenance Impact
- **代码复杂度**：中等（新增约 1500 行代码）
- **测试需求**：需要测试多个 AI 服务的集成
- **文档需求**：需要更新用户文档，说明如何配置和使用 Prompt Tools

## Scope

### In Scope (v0.2)
- ✅ 创建/编辑/删除 Prompt Tool
- ✅ 为 Tool 绑定独立快捷键
- ✅ 支持 Claude API、OpenAI API、Ollama
- ✅ 静默执行 Tool（后台处理）
- ✅ 预置 5 个默认 Tool
- ✅ 恢复默认 Tool 集合
- ✅ API Key 安全存储（Keychain）
- ✅ 错误处理（API 失败、网络错误）

### Out of Scope (明确不做)
- ❌ Tool 仅为文本类 Prompt 工具（Text-in → Text-out）
- ❌ 不做 Smart（不做上下文判断/自动选 Tool）
- ❌ 不做系统数据库级调用链（串联多工具、自动查表等）
- ❌ 不提供 OS 操作型工具（点击、窗口控制、读写文件、自动化流程等）
- ❌ 不支持图片输入（v0.2 仅支持文本）
- ❌ 不支持流式输出（v0.2 一次性返回结果）
- ❌ 不支持 Tool 执行历史记录
- ❌ 不支持 Tool 分享/导入导出

### Future Considerations (v0.3+)
- 支持图片输入（Vision API）
- 支持流式输出（实时显示生成过程）
- Tool 执行历史记录
- Tool 分享/导入导出
- 更多 AI 服务（Gemini、本地模型等）
- Tool 执行统计（使用次数、成功率等）

## Acceptance Criteria

### P0 (Must Have)
1. ✅ 能新建 Tool（名称 + Prompt）并绑定快捷键
2. ✅ 在任意应用触发快捷键能执行对应 Tool
3. ✅ Tool 执行结果写回剪贴板
4. ✅ 默认 5 个 Tool 存在且可删可改
5. ✅ 可在设置中恢复预置默认工具集
6. ✅ 支持 Claude API、OpenAI API、Ollama 三种服务
7. ✅ API Key 安全存储到 Keychain
8. ✅ API 调用失败时有错误提示

### P1 (Should Have)
- Tool 执行时显示通知（可选）
- 快捷键冲突检测和提示
- API 调用超时处理（30 秒）
- 剪贴板内容为空时的提示

### P2 (Nice to Have)
- Tool 执行进度指示器（菜单栏图标动画）
- 支持自定义 Ollama 模型
- 支持自定义 API Endpoint（代理）

## Risks & Mitigations

### Risk 1: API 调用失败
- **风险**：网络错误、API Key 错误、配额用尽
- **缓解**：
  - 提供清晰的错误提示
  - 支持重试机制
  - 提供 Ollama 本地方案（无需网络）

### Risk 2: AI 生成结果不符合预期
- **风险**：用户对结果不满意
- **缓解**：
  - 提供默认高质量 Prompt 模板
  - 允许用户自定义 Prompt
  - 结果写回剪贴板后可以撤销（Cmd+Z）

### Risk 3: 快捷键冲突
- **风险**：Tool 快捷键与其他应用冲突
- **缓解**：
  - 复用现有快捷键冲突检测机制
  - 允许用户重新录制快捷键
  - 提供快捷键建议（避免常见冲突）

### Risk 4: 隐私问题
- **风险**：剪贴板内容发送到 AI 服务
- **缓解**：
  - 首次使用时显示隐私声明
  - 提供 Ollama 本地方案（数据不离开设备）
  - 敏感数据过滤机制仍然生效

## Dependencies

### External Dependencies
- **MacPaw/OpenAI**：统一 AI API 调用
  - GitHub: https://github.com/MacPaw/OpenAI
  - License: MIT
  - 支持自定义 Endpoint，兼容 OpenAI API 格式的所有服务
  - 可选服务商：OpenAI、Anthropic Claude、Google Gemini、DeepSeek、Moonshot、智谱 GLM、Ollama 等

- **KeychainAccess**：安全存储 API Key
  - GitHub: https://github.com/kishikawakatsumi/KeychainAccess
  - License: MIT

### Internal Dependencies
- 依赖现有的 `HotKeyManager`（快捷键管理）
- 依赖现有的 `DatabaseManager`（数据存储）
- 依赖现有的 `ClipboardMonitor`（剪贴板监听）
- 依赖现有的 `AutoPasteManager`（自动粘贴）

### API Dependencies
- **OpenAI API 格式**：所有支持 OpenAI 兼容格式的服务
- **Ollama API**：本地模型（兼容 OpenAI 格式）

## Timeline

### Phase 1: 基础架构（2-3 天）
- 数据模型设计
- 数据库表创建
- PromptToolManager 基础实现
- AIService 接口设计

### Phase 2: AI 服务集成（3-4 天）
- ClaudeProvider 实现
- OpenAIProvider 实现
- OllamaProvider 实现
- API Key 管理（Keychain）
- 错误处理

### Phase 3: UI 实现（2-3 天）
- PromptToolsSettingsView
- PromptToolEditorView
- 集成到设置面板

### Phase 4: 快捷键集成（1-2 天）
- Tool 快捷键注册
- Tool 执行流程
- 结果写回剪贴板

### Phase 5: 测试与优化（2-3 天）
- 功能测试
- 性能优化
- 错误处理完善
- 文档更新

**总计**：10-15 天

## Open Questions

1. **API 调用超时时间**：设置为多少秒合适？（建议 30 秒）
2. **Tool 数量上限**：是否需要限制用户创建的 Tool 数量？（建议不限制）
3. **默认 AI 服务**：首次使用时默认选择哪个服务？（建议 Claude API）
4. **Ollama 模型选择**：是否需要自动检测本地可用模型？（v0.2 暂不做，使用默认模型）
5. **Tool 执行通知**：是否需要显示通知？（建议可选，默认关闭）

## References

- [PRD v0.2](../../spec/PRD_v0.2.md)（待创建）
- [Claude API Documentation](https://docs.anthropic.com/claude/reference)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [Ollama API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)
