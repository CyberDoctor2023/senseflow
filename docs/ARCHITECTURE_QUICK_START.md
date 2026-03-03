# Clean Architecture 快速开始指南

**5 分钟上手新架构**

---

## 🎯 核心概念

### 之前（单例 Manager）
```swift
// ❌ 紧耦合，难以测试
PromptToolManager.shared.executeTool(tool) { result in
    // ...
}
```

### 现在（Clean Architecture）
```swift
// ✅ 松耦合，易于测试
let coordinator = container.promptToolCoordinator
try await coordinator.executeTool(id: tool.toolID)
```

---

## 📦 架构层级

```
┌─────────────────────────────────────┐
│  Presentation (SwiftUI Views)       │
├─────────────────────────────────────┤
│  Coordinators                       │  ← 协调多个用例
│  - PromptToolCoordinator            │
│  - SmartToolCoordinator             │
├─────────────────────────────────────┤
│  UseCases                           │  ← 业务逻辑
│  - ExecutePromptTool                │
│  - AnalyzeAndRecommend              │
├─────────────────────────────────────┤
│  Adapters                           │  ← 实现协议
│  - SQLitePromptToolRepository       │
│  - OpenAIServiceAdapter             │
├─────────────────────────────────────┤
│  Domain (Protocols + ValueObjects)  │  ← 核心抽象
│  - PromptToolRepository (协议)      │
│  - ToolID (值对象)                  │
└─────────────────────────────────────┘
```

---

## 🚀 使用示例

### 1. 在 App 中初始化

```swift
// SenseFlow/SenseFlowApp.swift
@main
struct SenseFlowApp: App {
    private let container = DependencyContainer()

    var body: some Scene {
        Settings {
            SettingsView(
                coordinator: container.promptToolCoordinator
            )
        }
    }
}
```

### 2. 在 View 中使用

```swift
// SenseFlow/Views/PromptToolListView.swift
struct PromptToolListView: View {
    private let coordinator: PromptToolCoordinator
    @State private var tools: [PromptTool] = []

    init(coordinator: PromptToolCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        List(tools) { tool in
            Button(tool.name) {
                Task {
                    try? await coordinator.executeTool(id: tool.toolID)
                }
            }
        }
        .task {
            tools = try? await coordinator.loadTools() ?? []
        }
    }
}
```

### 3. 执行工具

```swift
// 新方式
Task {
    do {
        try await coordinator.executeTool(id: tool.toolID)
        print("✅ 执行成功")
    } catch {
        print("❌ 执行失败: \(error)")
    }
}
```

### 4. Smart AI 推荐

```swift
// 新方式
Task {
    do {
        try await smartCoordinator.analyzeAndExecute()
        print("✅ Smart AI 完成")
    } catch {
        print("❌ Smart AI 失败: \(error)")
    }
}
```

---

## 🧪 测试示例

```swift
// SenseFlowTests/ExecutePromptToolTests.swift
final class ExecutePromptToolTests: XCTestCase {
    func testExecute_withValidInput_returnsResult() async throws {
        // Arrange
        let mockAI = MockAIService()
        mockAI.generateResult = "翻译结果"

        let mockReader = MockClipboardReader()
        mockReader.textToReturn = "Hello"

        let mockWriter = MockClipboardWriter()
        let mockNotification = MockNotificationService()

        let useCase = ExecutePromptTool(
            aiService: mockAI,
            clipboardReader: mockReader,
            clipboardWriter: mockWriter,
            notificationService: mockNotification
        )

        let tool = PromptTool(name: "翻译", prompt: "Translate: {{input}}")

        // Act
        let result = try await useCase.execute(tool: tool)

        // Assert
        XCTAssertEqual(result, "翻译结果")
        XCTAssertEqual(mockAI.lastPrompt, "Translate: {{input}}")
        XCTAssertTrue(mockWriter.didWrite)
        XCTAssertTrue(mockNotification.didShowSuccess)
    }
}
```

---

## 📋 常用操作

### 加载所有工具
```swift
let tools = try await coordinator.loadTools()
```

### 创建工具
```swift
let tool = PromptTool(name: "翻译", prompt: "Translate: {{input}}")
try await coordinator.createTool(tool)
```

### 更新工具
```swift
var tool = existingTool
tool.name = "新名称"
try await coordinator.updateTool(tool)
```

### 删除工具
```swift
try await coordinator.deleteTool(id: tool.toolID)
```

### 注册所有快捷键
```swift
try await coordinator.registerAllHotKeys()
```

---

## 🔧 故障排查

### 编译错误："Cannot find type 'ToolID'"

**原因**: 文件未添加到 Xcode 项目

**解决**: 
```bash
# 使用 Ruby 脚本添加文件（见 IMPLEMENTATION_COMPLETE.md）
ruby add_architecture_files.rb
```

### 运行时错误："DI 容器初始化失败"

**原因**: 依赖注入失败

**解决**: 检查 DependencyContainer.swift 中的依赖关系

### 功能不工作

**原因**: 还在使用旧的单例

**解决**: 使用新的 Coordinator 替代旧的 Manager.shared

---

## 📚 更多资源

- `REFACTORING_PLAN.md` - 完整重构计划
- `CLEAN_ARCHITECTURE_MIGRATION.md` - 详细迁移指南
- `CLEAN_ARCHITECTURE_SUMMARY.md` - 架构总结
- `IMPLEMENTATION_COMPLETE.md` - 实现完成报告

---

**记住**: 新架构的核心是**依赖注入**和**面向协议编程**。所有依赖都通过构造函数注入，所有实现都基于协议。
