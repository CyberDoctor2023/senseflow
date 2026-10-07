# Clean Architecture 教学指南

**目标读者**: 想要深入理解 Clean Architecture、SOLID 原则和依赖注入的开发者

**学习路径**: 按照依赖方向从外到内学习

---

## 📚 学习路径

### 第一步：理解核心概念

1. **依赖倒置原则（DIP）**
   - 高层模块不依赖低层模块，都依赖抽象
   - 业务逻辑依赖接口，不依赖具体实现

2. **六边形架构（Hexagonal Architecture）**
   - 业务逻辑在中心
   - 外部世界通过"端口和适配器"连接
   - Port（端口）= 接口定义
   - Adapter（适配器）= 接口实现

3. **依赖注入（Dependency Injection）**
   - 对象不主动获取依赖，而是被动接收依赖
   - 通过构造器注入（推荐）、属性注入、方法注入

---

## 🏗️ 架构层次（从外到内）

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (表现层)                             │
│  - SwiftUI Views                                        │
│  - @EnvironmentObject DependencyEnvironment            │
└─────────────────────────────────────────────────────────┘
                        ↓ 调用
┌─────────────────────────────────────────────────────────┐
│  Coordinator Layer (协调器层)                            │
│  - PromptToolCoordinator                                │
│  - SmartToolCoordinator                                 │
│  职责：协调多个 Use Case，处理 UI 请求                    │
└─────────────────────────────────────────────────────────┘
                        ↓ 调用
┌─────────────────────────────────────────────────────────┐
│  Use Case Layer (用例层)                                 │
│  - ExecutePromptTool                                    │
│  - RegisterToolHotKey                                   │
│  - AnalyzeAndRecommend                                  │
│  职责：实现业务场景，编排服务                              │
└─────────────────────────────────────────────────────────┘
                        ↓ 依赖
┌─────────────────────────────────────────────────────────┐
│  Port Layer (端口层 - 接口定义)                           │
│  - AIServiceProtocol                                    │
│  - ClipboardReader / ClipboardWriter                    │
│  - NotificationServiceProtocol                          │
│  - PromptToolRepository                                 │
│  职责：定义业务逻辑需要的能力                              │
└─────────────────────────────────────────────────────────┘
                        ↑ 实现
┌─────────────────────────────────────────────────────────┐
│  Adapter Layer (适配器层 - 接口实现)                      │
│  - OpenAIServiceAdapter                                 │
│  - NSPasteboardAdapter                                  │
│  - UserNotificationAdapter                              │
│  - SQLitePromptToolRepository                           │
│  职责：将外部框架适配到接口                                │
└─────────────────────────────────────────────────────────┘
                        ↓ 调用
┌─────────────────────────────────────────────────────────┐
│  Infrastructure Layer (基础设施层)                        │
│  - NSPasteboard (macOS API)                             │
│  - UserNotification (macOS API)                         │
│  - DatabaseManager (SQLite)                             │
│  - AIService (OpenAI SDK)                               │
│  职责：外部框架和系统 API                                  │
└─────────────────────────────────────────────────────────┘
```

---

## 📖 按文件学习

### 1. 接口层（Port Layer）- 理解抽象

**为什么先学接口？** 因为接口定义了"做什么"，是理解架构的关键。

#### 📄 `ClipboardReader.swift`
- **核心概念**: 接口隔离原则（ISP）
- **学习要点**:
  - 为什么分离 Reader 和 Writer？
  - 如何设计最小接口？
  - Sendable 协议的作用
- **关键代码**:
  ```swift
  protocol ClipboardReader: Sendable {
      func readText() -> String?
      func readContent() -> ClipboardContent
  }
  ```

#### 📄 `AIServiceProtocol.swift`
- **核心概念**: 策略模式（Strategy Pattern）
- **学习要点**:
  - 如何支持多个 AI 提供商？
  - 接口如何保持平台无关？
  - 如何设计可扩展的接口？
- **关键代码**:
  ```swift
  protocol AIServiceProtocol: Sendable {
      func generate(systemPrompt: String, userInput: String) async throws -> String
      func recommendTool(context: SmartContext, availableTools: [PromptTool]) async throws -> SmartRecommendation
  }
  ```

#### 📄 `NotificationServiceProtocol.swift`
- **核心概念**: 语义化接口设计
- **学习要点**:
  - 为什么用独立方法而不是参数？
  - 如何设计用户友好的接口？
  - Tell, Don't Ask 原则
- **关键代码**:
  ```swift
  protocol NotificationServiceProtocol: Sendable {
      func showInProgress(title: String, body: String)
      func showSuccess(title: String, body: String)
      func showError(title: String, body: String)
  }
  ```

---

### 2. 适配器层（Adapter Layer）- 理解实现

**为什么学适配器？** 因为适配器展示了如何将外部框架适配到接口。

#### 📄 `NSPasteboardAdapter.swift`
- **核心概念**: 适配器模式（Adapter Pattern）
- **学习要点**:
  - 如何适配 macOS 系统 API？
  - 为什么需要 MainActor？
  - 如何避免自捕获问题？
- **关键代码**:
  ```swift
  final class NSPasteboardAdapter: ClipboardReader, ClipboardWriter {
      func readText() -> String? {
          return NSPasteboard.general.string(forType: .string)
      }

      func write(_ text: String) async {
          await MainActor.run {
              monitor.pauseMonitoring(duration: 1.5)
              let pasteboard = NSPasteboard.general
              pasteboard.clearContents()
              pasteboard.setString(text, forType: .string)
          }
      }
  }
  ```

#### 📄 `OpenAIServiceAdapter.swift`
- **核心概念**: 适配遗留代码（Legacy Code）
- **学习要点**:
  - 如何渐进式重构？
  - Strangler Fig Pattern（绞杀者模式）
  - 如何平滑过渡到新架构？
- **关键代码**:
  ```swift
  final class OpenAIServiceAdapter: AIServiceProtocol {
      private let aiService: SenseFlow.AIService  // 遗留代码

      func generate(systemPrompt: String, userInput: String) async throws -> String {
          return try await aiService.generate(systemPrompt: systemPrompt, userInput: userInput)
      }
  }
  ```

#### 📄 `SQLitePromptToolRepository.swift`
- **核心概念**: 仓库模式（Repository Pattern）
- **学习要点**:
  - Repository vs DAO 的区别
  - 如何隔离数据源？
  - Upsert 语义的实现
- **关键代码**:
  ```swift
  final class SQLitePromptToolRepository: PromptToolRepository {
      func findAll() async throws -> [PromptTool] {
          return databaseManager.fetchAllPromptTools()
      }

      func save(_ tool: PromptTool) async throws {
          if let _ = try await find(by: tool.toolID) {
              guard databaseManager.updatePromptTool(tool) else {
                  throw RepositoryError.updateFailed
              }
          } else {
              guard databaseManager.insertPromptTool(tool) else {
                  throw RepositoryError.insertFailed
              }
          }
      }
  }
  ```

---

### 3. 用例层（Use Case Layer）- 理解业务逻辑

**为什么学用例？** 因为用例展示了如何编排服务完成业务场景。

#### 📄 `ExecutePromptTool.swift`
- **核心概念**: 业务流程编排（Orchestration）
- **学习要点**:
  - 如何协调多个服务？
  - 单一职责原则（SRP）
  - Tell, Don't Ask 原则
- **关键代码**:
  ```swift
  final class ExecutePromptTool: Sendable {
      private let aiService: AIServiceProtocol
      private let clipboardReader: ClipboardReader
      private let clipboardWriter: ClipboardWriter
      private let notificationService: NotificationServiceProtocol

      func execute(tool: PromptTool) async throws -> String {
          notificationService.showInProgress(title: tool.name, body: "正在处理...")

          guard let input = clipboardReader.readText() else {
              throw ExecuteToolError.emptyClipboard
          }

          let result = try await aiService.generate(
              systemPrompt: tool.prompt,
              userInput: input
          )

          await clipboardWriter.write(result)
          notificationService.showSuccess(title: tool.name, body: "已完成")

          return result
      }
  }
  ```

---

### 4. 协调器层（Coordinator Layer）- 理解协调

**为什么学协调器？** 因为协调器展示了如何组合多个用例。

#### 📄 `PromptToolCoordinator.swift`
- **核心概念**: 外观模式（Facade Pattern）+ 中介者模式（Mediator Pattern）
- **学习要点**:
  - 如何协调多个 Use Case？
  - 事务性操作的实现
  - 错误处理策略
- **关键代码**:
  ```swift
  final class PromptToolCoordinator {
      private let repository: PromptToolRepository
      private let executeToolUseCase: ExecutePromptTool
      private let registerHotKeyUseCase: RegisterToolHotKey

      func createTool(_ tool: PromptTool) async throws {
          // 步骤 1: 保存到数据库
          try await repository.save(tool)

          // 步骤 2: 注册快捷键
          try registerHotKeyUseCase.register(tool: tool) { [weak self] in
              Task { @MainActor in
                  try? await self?.executeTool(id: tool.toolID)
              }
          }
      }
  }
  ```

---

### 5. 依赖注入容器（DI Container）- 理解组装

**为什么学容器？** 因为容器展示了如何组装整个应用。

#### 📄 `DependencyContainer.swift`
- **核心概念**: 控制反转（IoC）+ 工厂模式（Factory Pattern）
- **学习要点**:
  - 如何解决依赖关系？
  - Lazy 初始化的作用
  - 依赖层次的管理
- **关键代码**:
  ```swift
  final class DependencyContainer {
      // Infrastructure
      private lazy var databaseManager = DatabaseManager.shared

      // Repositories
      lazy var promptToolRepository: PromptToolRepository = {
          SQLitePromptToolRepository(databaseManager: databaseManager)
      }()

      // Services (Adapters)
      lazy var aiService: AIServiceProtocol = {
          OpenAIServiceAdapter(aiService: SenseFlow.AIService.shared)
      }()

      // Use Cases
      lazy var executePromptToolUseCase: ExecutePromptTool = {
          ExecutePromptTool(
              aiService: aiService,
              clipboardReader: clipboardReader,
              clipboardWriter: clipboardWriter,
              notificationService: notificationService
          )
      }()

      // Coordinators
      lazy var promptToolCoordinator: PromptToolCoordinator = {
          PromptToolCoordinator(
              repository: promptToolRepository,
              executeToolUseCase: executePromptToolUseCase,
              registerHotKeyUseCase: registerHotKeyUseCase
          )
      }()
  }
  ```

---

## 🎯 核心设计原则

### SOLID 原则在项目中的体现

#### 1. 单一职责原则（SRP）
- **Use Case**: 每个 Use Case 只负责一个业务场景
- **Adapter**: 每个 Adapter 只适配一个外部框架
- **Repository**: 每个 Repository 只管理一种实体

#### 2. 开闭原则（OCP）
- **接口**: 对扩展开放（新增 AI 提供商）
- **实现**: 对修改关闭（不修改 Use Case 代码）

#### 3. 里氏替换原则（LSP）
- **Adapter**: 任何 Adapter 都可以替换接口
- **测试**: Mock 对象可以替换真实对象

#### 4. 接口隔离原则（ISP）
- **ClipboardReader/Writer**: 分离读写接口
- **最小接口**: 只暴露必要的方法

#### 5. 依赖倒置原则（DIP）
- **Use Case**: 依赖接口，不依赖实现
- **依赖方向**: 所有依赖指向内层（业务逻辑）

---

## 🔄 数据流示例

### 用户触发工具执行的完整流程

```
1. 用户按下快捷键 (⌘⌥V)
   ↓
2. HotKeyManager 触发回调
   ↓
3. Coordinator.executeTool(id: toolID)
   ↓
4. Repository.find(by: toolID) → 查询工具
   ↓
5. ExecutePromptTool.execute(tool: tool)
   ↓
6. NotificationService.showInProgress(...) → 显示通知
   ↓
7. ClipboardReader.readText() → 读取剪贴板
   ↓
8. AIService.generate(...) → 调用 AI
   ↓
9. ClipboardWriter.write(result) → 写入剪贴板
   ↓
10. NotificationService.showSuccess(...) → 显示成功
```

### 依赖关系图

```
SwiftUI View
    ↓ @EnvironmentObject
DependencyEnvironment
    ↓ 包装
DependencyContainer
    ↓ 创建
PromptToolCoordinator
    ↓ 依赖
ExecutePromptTool (Use Case)
    ↓ 依赖
AIServiceProtocol (Port)
    ↑ 实现
OpenAIServiceAdapter (Adapter)
    ↓ 调用
AIService.shared (Legacy Code)
    ↓ 调用
OpenAI SDK (External)
```

---

## 🧪 测试策略

### 1. 单元测试（Unit Tests）
- **测试对象**: Use Cases
- **Mock 对象**: Adapters
- **示例**:
  ```swift
  func test_executePromptTool_withValidInput_success() async throws {
      let mockAI = MockAIService()
      let mockReader = MockClipboardReader()
      let mockWriter = MockClipboardWriter()
      let mockNotification = MockNotificationService()

      let sut = ExecutePromptTool(
          aiService: mockAI,
          clipboardReader: mockReader,
          clipboardWriter: mockWriter,
          notificationService: mockNotification
      )

      mockReader.textToReturn = "Hello"
      mockAI.generateResult = "你好"

      let result = try await sut.execute(tool: testTool)

      XCTAssertEqual(result, "你好")
      XCTAssertEqual(mockWriter.writtenText, "你好")
  }
  ```

### 2. 集成测试（Integration Tests）
- **测试对象**: Coordinators
- **真实对象**: Use Cases
- **Mock 对象**: Repositories, Services

### 3. 性能测试（Performance Tests）
- **测试指标**: 执行时间、内存使用
- **基准**: 单操作 < 0.01s，批量操作 < 0.1s

---

## 📝 最佳实践总结

### ✅ 应该做

1. **依赖接口，不依赖实现**
   ```swift
   // ✅ 好
   private let aiService: AIServiceProtocol

   // ❌ 坏
   private let aiService = OpenAI(apiKey: "...")
   ```

2. **使用构造器注入**
   ```swift
   // ✅ 好
   init(aiService: AIServiceProtocol) {
       self.aiService = aiService
   }

   // ❌ 坏
   let aiService = AIService.shared
   ```

3. **保持接口简单**
   ```swift
   // ✅ 好
   protocol ClipboardReader {
       func readText() -> String?
   }

   // ❌ 坏
   protocol ClipboardReader {
       func readText(encoding: String.Encoding, options: [String: Any]) -> String?
   }
   ```

4. **使用领域类型**
   ```swift
   // ✅ 好
   func find(by id: ToolID) -> PromptTool?

   // ❌ 坏
   func find(by id: UUID) -> PromptTool?
   ```

### ❌ 不应该做

1. **在 Use Case 中直接调用外部框架**
2. **在 Adapter 中包含业务逻辑**
3. **使用全局单例（除非必要）**
4. **让内层依赖外层**

---

## 🚀 下一步学习

1. **深入学习设计模式**
   - Strategy Pattern（策略模式）
   - Adapter Pattern（适配器模式）
   - Repository Pattern（仓库模式）
   - Facade Pattern（外观模式）

2. **阅读经典书籍**
   - 《Clean Architecture》by Robert C. Martin
   - 《Domain-Driven Design》by Eric Evans
   - 《Patterns of Enterprise Application Architecture》by Martin Fowler

3. **实践项目**
   - 尝试将现有项目重构为 Clean Architecture
   - 从零开始用 Clean Architecture 构建新项目

---

**最后更新**: 2026-02-03
**作者**: Claude Sonnet 4.5
**项目**: SenseFlow - Clean Architecture 教学示例
