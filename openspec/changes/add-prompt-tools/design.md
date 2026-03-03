# Design: Add Prompt Tools Feature

## Context

SenseFlow v0.1 只提供剪贴板历史管理功能。为了提升用户效率，v0.2 将集成 AI 能力，让用户可以在任意应用中通过快捷键直接处理剪贴板内容。

### Constraints
- 必须保持 macOS 12.0+ 兼容性
- 必须复用现有的 HotKeyManager、DatabaseManager 等组件
- API Key 必须安全存储（Keychain）
- 不能阻塞 UI 线程

### Stakeholders
- 用户：期望快速、稳定的文本处理体验
- 开发者：需要可维护、可扩展的代码结构

## Goals / Non-Goals

### Goals
- 实现 Prompt Tool 的 CRUD 管理
- 支持 Claude、OpenAI、Ollama 三种 AI 服务
- 静默执行 Tool，无 UI 打断
- 安全存储 API Key

### Non-Goals
- 不支持图片输入（Text-only）
- 不支持流式输出
- 不做上下文判断/自动选 Tool
- 不做 OS 操作型工具

## Context7 API 验证结果

### MacPaw/OpenAI SDK (最新版本)
- **初始化**: `OpenAI(configuration: OpenAI.Configuration(token:, host:, basePath:, parsingOptions:))`
- **自定义 Endpoint**: 通过 `host` 和 `basePath` 参数支持非 OpenAI 服务商
- **非 OpenAI 服务商**: 使用 `.relaxed` 解析选项处理响应差异
- **Chat API**: `ChatQuery` + `openAI.chats(query:)` 返回 `ChatResult`
- **消息格式**: `.user(.init(content: .string("...")))` 和 `.system(.init(content: .string("...")))`
- **异步调用**: 支持 Swift Concurrency (`async/await`)

### KeychainAccess SDK (v4.2.2)
- **初始化**: `Keychain(service: "com.example.app")`
- **存储**: `keychain["key"] = "value"` 或 `try keychain.set("value", key: "key")`
- **读取**: `let value = keychain["key"]`
- **删除**: `try keychain.remove("key")`

## Decisions

### 1. 数据模型设计

**Decision**: 使用 SQLite 存储 PromptTool，Keychain 存储 API Key

**理由**:
- SQLite 已在项目中使用（DatabaseManager）
- Keychain 是 macOS 推荐的敏感数据存储方式
- 分离关注点：Tool 配置 vs 敏感凭证

**数据结构**:
```swift
struct PromptTool: Identifiable, Codable {
    var id: UUID
    var name: String
    var prompt: String
    var shortcutKeyCode: UInt16
    var shortcutModifiers: UInt32
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

### 2. AI 服务架构

**Decision**: 使用 MacPaw/OpenAI SDK + 自定义 Endpoint

**理由**:
- MacPaw/OpenAI 是广泛使用的 Swift OpenAI 库
- 支持自定义 Endpoint，可兼容所有 OpenAI API 格式的服务
- 统一接口，无需为每个服务商编写适配器
- 开箱即用，减少开发工作量

**支持的服务商**:
- OpenAI (GPT-4o, GPT-4o-mini)
- Anthropic (Claude 3.5 Sonnet, Claude 3 Haiku) - 通过兼容 Endpoint
- Google (Gemini 1.5 Pro/Flash) - 通过兼容 Endpoint
- DeepSeek、Moonshot、智谱 GLM
- Ollama（本地模型）

**架构**:
```swift
import OpenAI

class AIService {
    private var client: OpenAI
    
    func configure(endpoint: String, apiKey: String, model: String)
    func generate(systemPrompt: String, userInput: String) async throws -> String
}
```

**备选方案** (已否决):
- Protocol + Provider 模式：需要为每个服务商编写适配器，工作量大
- 手动 URLSession：缺少错误处理、重试机制等

### 3. Tool 执行流程

**Decision**: 异步后台执行，结果写回剪贴板

**流程**:
1. 用户按下 Tool 快捷键
2. HotKeyManager 触发事件
3. PromptToolManager.execute(tool)
   - 读取当前剪贴板内容
   - 调用 AIService.generate()
   - 写回剪贴板（暂停监听避免自捕获）
   - 可选：触发自动粘贴
4. 显示成功/失败通知（可选）

**错误处理**:
- 网络错误：显示通知，保留原剪贴板内容
- API 错误：显示具体错误信息
- 超时：30 秒超时，显示通知

### 4. 快捷键管理

**Decision**: 扩展现有 HotKeyManager

**理由**:
- 复用已验证的 Carbon EventHotKey 实现
- 保持代码一致性
- 避免多个快捷键管理器冲突

**实现**:
```swift
extension HotKeyManager {
    func registerToolHotKey(tool: PromptTool)
    func unregisterToolHotKey(toolId: UUID)
    func updateToolHotKey(tool: PromptTool)
}
```

### 5. UI 架构

**Decision**: 新增 SettingsView Tab，复用现有组件

**结构**:
```
SettingsView
├── GeneralSettingsView
├── ShortcutsSettingsView
├── PromptToolsSettingsView  [NEW]
│   ├── Tool 列表
│   ├── AI 服务选择
│   ├── API Key 配置
│   └── 恢复默认按钮
└── AboutSettingsView
```

**Tool 编辑**: 使用 Sheet 弹窗，复用 ShortcutRecorder 组件

## Risks / Trade-offs

### Risk 1: API 响应时间长
- **影响**: 用户等待时间过长
- **缓解**: 
  - 显示通知告知正在处理
  - 支持 Ollama 本地模型（响应快）
  - 设置合理超时（30 秒）

### Risk 2: 外部依赖
- **影响**: 新增 MacPaw/OpenAI 和 KeychainAccess 依赖
- **缓解**: 
  - 两个库都是成熟、广泛使用的开源项目
  - MIT 许可证，无法律风险
  - MacPaw/OpenAI 积极维护，与 OpenAI API 同步更新

### Risk 3: 快捷键数量增加
- **影响**: 可能与其他应用冲突
- **缓解**:
  - 复用现有冲突检测机制
  - 允许用户自定义快捷键
  - 默认使用不常见组合

## Migration Plan

### 数据库迁移
1. 新增 `prompt_tools` 表（非破坏性）
2. 首次启动时初始化默认 Tool
3. 无需迁移现有数据

### 用户迁移
1. 首次打开设置时显示新 Tab
2. 首次使用 AI 功能时提示配置 API Key
3. 提供隐私声明

### Rollback
- 删除 `prompt_tools` 表即可回滚
- API Key 保留在 Keychain（用户可手动删除）

## Open Questions

1. **API 调用超时时间**: 建议 30 秒，待确认
2. **默认 AI 服务**: 建议 Claude API，待确认
3. **Tool 执行通知**: 建议默认关闭，待确认
