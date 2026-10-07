# Clean Architecture 迁移指南

**日期**: 2026-02-02

## 概述

SenseFlow 已完成从单例 Manager 架构到 Clean Architecture 的重构。本文档说明如何使用新架构。

---

## 架构分层

```
Domain (核心领域)
  ├── Entities: ClipboardItem, PromptTool, SmartRecommendation
  ├── ValueObjects: ToolID, KeyCombo, ClipboardContent
  └── Protocols: PromptToolRepository, AIService, HotKeyRegistry, etc.

UseCases (应用业务规则)
  ├── ExecutePromptTool: 执行工具
  ├── AnalyzeAndRecommend: Smart AI 分析推荐
  └── RegisterToolHotKey: 注册快捷键

Adapters (适配器)
  ├── Repositories: SQLitePromptToolRepository
  └── Services: OpenAIServiceAdapter, NSPasteboardAdapter, etc.

Infrastructure (基础设施)
  └── DI: DependencyContainer

Coordinators (协调器)
  ├── PromptToolCoordinator: 协调工具 CRUD 和执行
  └── SmartToolCoordinator: 协调 Smart AI 流程
```

---

## 使用新架构

### 1. 在 SwiftUI 中注入依赖

```swift
@main
struct SenseFlowApp: App {
    private let container = DependencyContainer()

    var body: some Scene {
        MenuBarExtra("SenseFlow", systemImage: "doc.on.clipboard") {
            ClipboardListView()
        }

        Settings {
            SettingsView(
                coordinator: container.promptToolCoordinator
            )
        }
    }
}
```

### 2. 在 View 中使用 Coordinator

```swift
struct PromptToolListView: View {
    private let coordinator: PromptToolCoordinator
    @State private var tools: [PromptTool] = []

    init(coordinator: PromptToolCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        List(tools) { tool in
            ToolRow(tool: tool)
        }
        .task {
            tools = try? await coordinator.loadTools() ?? []
        }
    }
}
```

### 3. 执行工具

```swift
// 旧方式（已废弃）
PromptToolManager.shared.executeTool(tool) { result in
    // ...
}

// 新方式
Task {
    do {
        try await coordinator.executeTool(id: tool.toolID)
    } catch {
        print("执行失败: \(error)")
    }
}
```

### 4. Smart AI 推荐

```swift
// 旧方式（已废弃）
Task {
    try await SmartToolManager.shared.analyzeAndExecute()
}

// 新方式
Task {
    do {
        try await smartCoordinator.analyzeAndExecute()
    } catch {
        print("Smart AI 失败: \(error)")
    }
}
```

---

## 值对象使用

### ToolID

```swift
// 创建
let toolID = ToolID(UUID())

// 从 PromptTool 获取
let toolID = tool.toolID

// 转换为 UUID
let uuid = toolID.value
```

### KeyCombo

```swift
// 创建
let combo = KeyCombo(
    keyCode: KeyCode(0x09),  // V 键
    modifiers: [.command, .control]
)

// 从 PromptTool 获取
if let combo = tool.keyCombo {
    print(combo.displayString)  // "⌘⌃V"
}
```

---

## 测试

### 单元测试示例

```swift
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
        XCTAssertTrue(mockWriter.didWrite)
        XCTAssertTrue(mockNotification.didShowSuccess)
    }
}
```

---

## 迁移清单

### 已完成 ✅

- [x] Domain 层协议定义
- [x] 值对象创建（ToolID, KeyCombo, ClipboardContent）
- [x] UseCases 实现
- [x] Adapters 实现
- [x] DI 容器创建
- [x] Coordinators 创建
- [x] PromptTool 桥接属性

### 待完成 ⏳

- [ ] 更新 PromptToolManager 使用新 Coordinator
- [ ] 更新 SmartToolManager 使用新 Coordinator
- [ ] 更新 SwiftUI Views 注入依赖
- [ ] 添加单元测试
- [ ] 删除旧的 Manager 类

---

## 常见问题

### Q: 为什么要用值对象包装 UUID？

A: 类型安全。`ToolID` 和 `ClipboardItemID` 不会混淆，编译器会检查类型。

### Q: 旧代码还能用吗？

A: 可以。PromptTool 有桥接属性（`toolID`, `keyCombo`），新旧代码可以共存。

### Q: 如何测试？

A: 所有依赖都是协议，可以轻松 Mock。参考上面的测试示例。

---

**下一步**: 逐步迁移现有代码到新架构，保持功能正常运行。
