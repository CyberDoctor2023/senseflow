# Tasks: Add Prompt Tools Feature

## 1. 基础架构
- [x] 1.1 创建 `PromptTool` 数据模型 (`Models/PromptTool.swift`)
- [x] 1.2 创建 `prompt_tools` 数据库表 (`DatabaseManager` 扩展)
- [x] 1.3 实现 `PromptToolManager` 基础 CRUD 操作
- [x] 1.4 创建 `AIProvider` 协议定义

## 2. AI 服务集成
- [ ] 2.1 添加 MacPaw/OpenAI SPM 依赖
- [x] 2.2 添加 KeychainAccess SPM 依赖 (使用原生 Security.framework)
- [x] 2.3 实现 `AIService.swift`（基于 OpenAI 兼容 API）
- [x] 2.4 实现 `KeychainManager.swift`（API Key 存储）
- [x] 2.5 实现服务商配置（Endpoint + Model 选择）

## 3. UI 实现
- [x] 3.1 创建 `PromptToolsSettingsView.swift`（Tool 列表 + AI 服务配置）
- [x] 3.2 创建 `PromptToolEditorView.swift`（Tool 编辑）
- [x] 3.3 集成到 SettingsView Tab
- [ ] 3.4 添加快捷键录制器组件复用

## 4. 快捷键集成
- [ ] 4.1 扩展 `HotKeyManager` 支持 Tool 快捷键
- [ ] 4.2 实现 Tool 执行流程（剪贴板读取 → AI 调用 → 写回）
- [ ] 4.3 实现快捷键冲突检测
- [ ] 4.4 Tool 执行错误处理与通知

## 5. 预置 Tool 与初始化
- [ ] 5.1 创建 5 个默认 Tool 定义
- [ ] 5.2 实现首次启动默认 Tool 初始化
- [ ] 5.3 实现恢复默认 Tool 集合功能

## 6. 测试与优化
- [ ] 6.1 功能测试（创建/编辑/删除 Tool）
- [ ] 6.2 AI 服务调用测试（Claude/OpenAI/Ollama）
- [ ] 6.3 快捷键触发测试
- [ ] 6.4 错误处理测试（API 失败、网络错误）
- [ ] 6.5 性能优化与内存测试
