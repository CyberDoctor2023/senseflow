# SenseFlow 架构分析 (进行中)

**日期**: 2026-02-02
**目标**: 使用 SOLID 原则和架构模式对整个项目进行架构级重构分析

---

## 用户需求

用户想要**整体架构级别**的重构建议,重点关注:
1. 降低耦合
2. 面向接口设计
3. 应用 SOLID 原则
4. 改善架构模式

---

## 已安装的技能

1. ✅ `solid` - SOLID 原则技能 (ramziddin/solid-skills@solid)
2. ✅ `architecture-patterns` - 架构模式技能 (wshobson/agents@architecture-patterns)
3. ✅ `refactor7` - 通用重构技能 (已有)

**注意**: 技能已安装但需要重启才能使用

---

## 当前架构分析 (来自 Explore Agent)

### 1. 模块结构

#### Managers (9 个单例)
- **DatabaseManager** - SQLite 数据库操作
- **HotKeyManager** - 全局快捷键注册和事件处理
- **FloatingWindowManager** - 悬浮窗生命周期管理
- **PromptToolManager** - Prompt Tools CRUD + 快捷键 + 执行
- **SmartToolManager** - 上下文分析 + AI 推荐
- **AutoPasteManager** - Cmd+V 模拟
- **AccessibilityManager** - 权限检查
- **KeychainManager** - 加密密钥存储
- **BlobFileManager** - 大文件存储

#### Services (10 个)
- **AIService** - AI 文本生成 (MacPaw OpenAI SDK)
- **GeminiService** - Gemini 专用实现
- **ClipboardMonitor** - 剪贴板轮询监听 (0.75s)
- **TracingService** - OpenTelemetry + Langfuse
- **LangfuseSyncService** - 自动同步 Prompt Tools (5 分钟)
- **LangfusePromptService** - Langfuse API 客户端
- **ToolUpdateService** - 社区工具更新
- **OCRService** - 图片文字识别
- **NotificationService** - macOS 通知
- **AppIconCache** - 应用图标缓存

#### Models (5 个)
- ClipboardItem, ClipboardItemType, PromptTool, SmartContext, SmartRecommendation

#### Views (15+ 个)
- ClipboardListView, ClipboardCardView, PromptToolEditorView, SmartRecommendationView
- SettingsView + 5 个子设置页面
- CommunityToolsBrowserView, OnboardingView, HotKeyRecorderView

---

### 2. 识别的耦合问题

#### 高耦合点

1. **PromptToolManager** 依赖 4+ 个其他组件:
   - DatabaseManager (数据持久化)
   - HotKeyManager (快捷键注册)
   - AIService (AI 调用)
   - NotificationService (通知)

2. **SmartToolManager** 依赖:
   - PromptToolManager
   - AIService
   - ClipboardMonitor

3. **Views 直接依赖具体实现**:
   - 使用 `@StateObject` 或 `.shared` 直接访问 Manager
   - 没有协议/接口层
   - 难以测试和替换实现

4. **单例模式泛滥**:
   - 9 个 Manager 都是单例
   - 全局状态难以控制
   - 测试困难

---

### 3. SOLID 原则违反

#### 单一职责原则 (SRP) 违反
- **PromptToolManager**: 同时负责 CRUD、快捷键、执行、AI 调用
- **SmartToolManager**: 上下文分析 + AI 推荐 + 自动执行

#### 依赖倒置原则 (DIP) 违反
- Views 依赖具体的 Manager 类,而非抽象接口
- Manager 之间直接依赖具体实现

#### 接口隔离原则 (ISP) 问题
- 没有定义清晰的接口
- 客户端被迫依赖不需要的方法

---

### 4. 架构模式问题

当前: **MVVM + 单例**
- SwiftUI Views 作为 ViewModel
- Manager 作为 Model 层
- 缺少清晰的 Service 层抽象

问题:
- 没有依赖注入
- 难以测试
- 模块边界不清晰
- 跨模块通信混乱

---

## 下一步计划

### 使用 SOLID 技能分析

```
/solid analyze the SenseFlow project:
- 识别所有 SOLID 原则违反
- 针对每个 Manager 提供接口设计建议
- 提供依赖注入重构方案
```

### 使用 Architecture Patterns 技能

```
/architecture-patterns suggest patterns for:
- 替代单例模式的架构
- Service 层设计
- 依赖注入容器
- 模块间通信机制
- 保持 SwiftUI 兼容性
```

### 预期输出

1. **接口设计方案**:
   - 为每个 Manager 定义 Protocol
   - 依赖注入策略

2. **架构重构路线图**:
   - 分层架构设计
   - 模块解耦步骤
   - 迁移计划

3. **具体重构示例**:
   - PromptToolManager 拆分和接口化
   - Views 改用协议依赖

---

## 参考文档

- `docs/SPEC.md` - 项目规范
- `docs/DECISIONS.md` - 架构决策记录
- `docs/TODO.md` - 当前任务

---

**状态**: 等待重启后使用 SOLID 和 architecture-patterns 技能继续分析
