# SenseFlow 架构重构计划

**目标**: 降低耦合、面向接口设计、应用 SOLID 原则

---

## 阶段 0: 准备工作 (1-2 天)

### 0.1 建立测试基础设施
```swift
// 创建测试目标和基础 mock 框架
SenseFlowTests/
├── Mocks/
│   ├── MockClipboardRepository.swift
│   ├── MockPromptToolRepository.swift
│   └── MockAIService.swift
└── UnitTests/
    └── (待添加)
```

### 0.2 冻结当前功能
- ✅ 记录所有现有功能的行为
- ✅ 创建集成测试覆盖关键路径
- ✅ 确保当前代码可构建运行

---

## 阶段 1: 定义协议层 (2-3 天)

### 1.1 创建 Domain 协议

```swift
// SenseFlow/Domain/Protocols/ClipboardProtocols.swift

/// 剪贴板数据仓库协议
protocol ClipboardRepository {
    func save(_ item: ClipboardItem) async throws
    func findAll(limit: Int) async throws -> [ClipboardItem]
    func search(query: String) async throws -> [ClipboardItem]
    func delete(id: String) async throws
}

/// 剪贴板监听协议
protocol ClipboardMonitoring {
    func startMonitoring()
    func stopMonitoring()
    var onClipboardChange: ((ClipboardItem) -> Void)? { get set }
}

// SenseFlow/Domain/Protocols/PromptToolProtocols.swift

/// Prompt Tool 数据仓库协议
protocol PromptToolRepository {
    func save(_ tool: PromptTool) async throws
    func findAll() async throws -> [PromptTool]
    func find(by id: String) async throws -> PromptTool?
    func delete(id: String) async throws
}

/// Prompt Tool 执行服务协议
protocol PromptToolExecutor {
    func execute(tool: PromptTool, input: String) async throws -> String
}

/// 快捷键注册协议
protocol HotKeyRegistration {
    func register(key: KeyCombo, handler: @escaping () -> Void) throws
    func unregister(key: KeyCombo)
}

// SenseFlow/Domain/Protocols/AIProtocols.swift

/// AI 服务协议
protocol AIService {
    func generate(prompt: String, model: String) async throws -> String
}

/// 通知服务协议
protocol NotificationService {
    func show(title: String, message: String)
}
```

**验收标准**:
- ✅ 所有协议编译通过
- ✅ 协议方法签名清晰、职责单一
- ✅ 无具体实现依赖

---

## 阶段 2: 拆分 PromptToolManager (3-4 天)

### 2.1 创建独立服务

**当前问题**: PromptToolManager 有 4 个职责

**拆分方案**:

```swift
// SenseFlow/Services/PromptTool/PromptToolRepositoryImpl.swift
final class PromptToolRepositoryImpl: PromptToolRepository {
    private let database: DatabaseManager  // 暂时保留,后续替换

    func save(_ tool: PromptTool) async throws {
        // 只负责数据持久化
    }

    func findAll() async throws -> [PromptTool] {
        // 只负责数据查询
    }
}

// SenseFlow/Services/PromptTool/PromptToolExecutorImpl.swift
final class PromptToolExecutorImpl: PromptToolExecutor {
    private let aiService: AIService
    private let notificationService: NotificationService

    init(aiService: AIService, notificationService: NotificationService) {
        self.aiService = aiService
        self.notificationService = notificationService
    }

    func execute(tool: PromptTool, input: String) async throws -> String {
        // 只负责工具执行逻辑
        let prompt = tool.template.replacingOccurrences(of: "{{input}}", with: input)
        let result = try await aiService.generate(prompt: prompt, model: tool.model)
        notificationService.show(title: "完成", message: "工具执行成功")
        return result
    }
}

// SenseFlow/Services/HotKey/HotKeyRegistrationImpl.swift
final class HotKeyRegistrationImpl: HotKeyRegistration {
    private let hotKeyManager: HotKeyManager  // 暂时保留

    func register(key: KeyCombo, handler: @escaping () -> Void) throws {
        // 只负责快捷键注册
    }
}
```

### 2.2 创建协调器 (Coordinator)

```swift
// SenseFlow/Services/PromptTool/PromptToolCoordinator.swift
final class PromptToolCoordinator {
    private let repository: PromptToolRepository
    private let executor: PromptToolExecutor
    private let hotKeyRegistration: HotKeyRegistration

    init(
        repository: PromptToolRepository,
        executor: PromptToolExecutor,
        hotKeyRegistration: HotKeyRegistration
    ) {
        self.repository = repository
        self.executor = executor
        self.hotKeyRegistration = hotKeyRegistration
    }

    func createTool(_ tool: PromptTool) async throws {
        try await repository.save(tool)
        if let shortcut = tool.shortcut {
            try hotKeyRegistration.register(key: shortcut) { [weak self] in
                Task {
                    try? await self?.executeTool(tool.id)
                }
            }
        }
    }

    func executeTool(_ toolId: String) async throws {
        guard let tool = try await repository.find(by: toolId) else {
            throw PromptToolError.notFound
        }
        // 获取剪贴板内容作为输入
        let input = NSPasteboard.general.string(forType: .string) ?? ""
        _ = try await executor.execute(tool: tool, input: input)
    }
}
```

**验收标准**:
- ✅ PromptToolManager 拆分为 3 个独立服务
- ✅ 每个服务只有 1 个职责
- ✅ 通过协议依赖,不依赖具体实现

---

## 阶段 3: 拆分 SmartToolManager (2-3 天)

### 3.1 创建独立服务

```swift
// SenseFlow/Services/SmartTool/ContextAnalyzer.swift
final class ContextAnalyzer {
    func analyze() async -> SmartContext {
        // 只负责收集上下文信息
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName
        return SmartContext(
            clipboardContent: clipboardContent,
            activeApp: activeApp,
            timestamp: Date()
        )
    }
}

// SenseFlow/Services/SmartTool/ToolRecommender.swift
final class ToolRecommender {
    private let aiService: AIService
    private let toolRepository: PromptToolRepository

    init(aiService: AIService, toolRepository: PromptToolRepository) {
        self.aiService = aiService
        self.toolRepository = toolRepository
    }

    func recommend(context: SmartContext) async throws -> [SmartRecommendation] {
        // 只负责 AI 推荐逻辑
        let tools = try await toolRepository.findAll()
        let prompt = buildRecommendationPrompt(context: context, tools: tools)
        let response = try await aiService.generate(prompt: prompt, model: "gpt-4")
        return parseRecommendations(response)
    }
}

// SenseFlow/Services/SmartTool/SmartToolCoordinator.swift
final class SmartToolCoordinator {
    private let contextAnalyzer: ContextAnalyzer
    private let recommender: ToolRecommender
    private let executor: PromptToolExecutor

    init(
        contextAnalyzer: ContextAnalyzer,
        recommender: ToolRecommender,
        executor: PromptToolExecutor
    ) {
        self.contextAnalyzer = contextAnalyzer
        self.recommender = recommender
        self.executor = executor
    }

    func analyzeAndRecommend() async throws -> [SmartRecommendation] {
        let context = await contextAnalyzer.analyze()
        return try await recommender.recommend(context: context)
    }

    func executeRecommendation(_ recommendation: SmartRecommendation) async throws {
        let tool = recommendation.tool
        let input = recommendation.suggestedInput
        _ = try await executor.execute(tool: tool, input: input)
    }
}
```

**验收标准**:
- ✅ SmartToolManager 拆分为 3 个独立服务
- ✅ 上下文分析、推荐、执行完全解耦
- ✅ 可独立测试每个组件

---

## 阶段 4: 依赖注入容器 (2 天)

### 4.1 创建 DI 容器

```swift
// SenseFlow/DI/DependencyContainer.swift

final class DependencyContainer {
    // MARK: - Singletons (Infrastructure)

    private lazy var databaseManager = DatabaseManager.shared
    private lazy var hotKeyManager = HotKeyManager.shared

    // MARK: - Repositories

    lazy var clipboardRepository: ClipboardRepository = {
        ClipboardRepositoryImpl(database: databaseManager)
    }()

    lazy var promptToolRepository: PromptToolRepository = {
        PromptToolRepositoryImpl(database: databaseManager)
    }()

    // MARK: - Services

    lazy var aiService: AIService = {
        AIServiceImpl()
    }()

    lazy var notificationService: NotificationService = {
        NotificationServiceImpl()
    }()

    lazy var hotKeyRegistration: HotKeyRegistration = {
        HotKeyRegistrationImpl(hotKeyManager: hotKeyManager)
    }()

    // MARK: - Executors

    lazy var promptToolExecutor: PromptToolExecutor = {
        PromptToolExecutorImpl(
            aiService: aiService,
            notificationService: notificationService
        )
    }()

    // MARK: - Coordinators

    lazy var promptToolCoordinator: PromptToolCoordinator = {
        PromptToolCoordinator(
            repository: promptToolRepository,
            executor: promptToolExecutor,
            hotKeyRegistration: hotKeyRegistration
        )
    }()

    lazy var smartToolCoordinator: SmartToolCoordinator = {
        SmartToolCoordinator(
            contextAnalyzer: ContextAnalyzer(),
            recommender: ToolRecommender(
                aiService: aiService,
                toolRepository: promptToolRepository
            ),
            executor: promptToolExecutor
        )
    }()
}
```

### 4.2 SwiftUI 集成

```swift
// SenseFlow/SenseFlowApp.swift

@main
struct SenseFlowApp: App {
    private let container = DependencyContainer()

    var body: some Scene {
        MenuBarExtra("SenseFlow", systemImage: "doc.on.clipboard") {
            ClipboardListView(
                repository: container.clipboardRepository
            )
        }

        Settings {
            SettingsView(
                promptToolCoordinator: container.promptToolCoordinator
            )
        }
    }
}

// SenseFlow/Views/ClipboardListView.swift

struct ClipboardListView: View {
    private let repository: ClipboardRepository
    @State private var items: [ClipboardItem] = []

    init(repository: ClipboardRepository) {
        self.repository = repository
    }

    var body: some View {
        List(items) { item in
            ClipboardCardView(item: item)
        }
        .task {
            items = try? await repository.findAll(limit: 50) ?? []
        }
    }
}
```

**验收标准**:
- ✅ 所有依赖通过 DI 容器创建
- ✅ Views 通过构造函数注入依赖
- ✅ 不再使用 `.shared` 单例访问

---

## 阶段 5: 适配器层重构 (3-4 天)

### 5.1 DatabaseManager 适配器化

```swift
// SenseFlow/Adapters/Database/ClipboardRepositoryImpl.swift

final class ClipboardRepositoryImpl: ClipboardRepository {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func save(_ item: ClipboardItem) async throws {
        try await database.insertClipboardItem(item)
    }

    func findAll(limit: Int) async throws -> [ClipboardItem] {
        try await database.fetchClipboardItems(limit: limit)
    }

    func search(query: String) async throws -> [ClipboardItem] {
        try await database.searchClipboardItems(query: query)
    }

    func delete(id: String) async throws {
        try await database.deleteClipboardItem(id: id)
    }
}
```

### 5.2 AIService 适配器化

```swift
// SenseFlow/Adapters/AI/AIServiceImpl.swift

final class AIServiceImpl: AIService {
    private let openAI: OpenAI

    init() {
        let apiKey = KeychainManager.shared.getAPIKey(for: .openAI) ?? ""
        self.openAI = OpenAI(apiToken: apiKey)
    }

    func generate(prompt: String, model: String) async throws -> String {
        let query = ChatQuery(
            messages: [.init(role: .user, content: prompt)],
            model: model
        )
        let result = try await openAI.chats(query: query)
        return result.choices.first?.message.content?.string ?? ""
    }
}
```

**验收标准**:
- ✅ 所有 Manager 都通过适配器访问
- ✅ 适配器实现协议接口
- ✅ 可轻松替换实现 (如 Mock)

---

## 阶段 6: 测试覆盖 (持续进行)

### 6.1 单元测试

```swift
// SenseFlowTests/UnitTests/PromptToolExecutorTests.swift

final class PromptToolExecutorTests: XCTestCase {
    func test_execute_replacesTemplateVariables() async throws {
        // Arrange
        let mockAI = MockAIService()
        mockAI.generateResult = "翻译结果"
        let mockNotification = MockNotificationService()

        let executor = PromptToolExecutorImpl(
            aiService: mockAI,
            notificationService: mockNotification
        )

        let tool = PromptTool(
            id: "1",
            name: "翻译",
            template: "Translate: {{input}}",
            model: "gpt-4"
        )

        // Act
        let result = try await executor.execute(tool: tool, input: "Hello")

        // Assert
        XCTAssertEqual(result, "翻译结果")
        XCTAssertEqual(mockAI.lastPrompt, "Translate: Hello")
        XCTAssertTrue(mockNotification.didShowNotification)
    }
}
```

### 6.2 集成测试

```swift
// SenseFlowTests/IntegrationTests/PromptToolCoordinatorTests.swift

final class PromptToolCoordinatorTests: XCTestCase {
    func test_createTool_savesAndRegistersHotkey() async throws {
        // Arrange
        let mockRepo = MockPromptToolRepository()
        let mockExecutor = MockPromptToolExecutor()
        let mockHotKey = MockHotKeyRegistration()

        let coordinator = PromptToolCoordinator(
            repository: mockRepo,
            executor: mockExecutor,
            hotKeyRegistration: mockHotKey
        )

        let tool = PromptTool(
            id: "1",
            name: "翻译",
            template: "Translate: {{input}}",
            shortcut: KeyCombo(key: .t, modifiers: [.command, .shift])
        )

        // Act
        try await coordinator.createTool(tool)

        // Assert
        XCTAssertTrue(mockRepo.savedTools.contains(where: { $0.id == "1" }))
        XCTAssertTrue(mockHotKey.registeredKeys.contains(tool.shortcut!))
    }
}
```

**验收标准**:
- ✅ 核心业务逻辑 80%+ 单元测试覆盖
- ✅ 关键路径集成测试覆盖
- ✅ 所有测试可独立运行

---

## 阶段 7: 清理遗留代码 (1-2 天)

### 7.1 删除旧的 Manager 类

```bash
# 确认所有引用已迁移后删除
rm "SenseFlow/Managers/PromptToolManager.swift"
rm "SenseFlow/Managers/SmartToolManager.swift"
```

### 7.2 更新文档

- 更新 `docs/DECISIONS.md` 记录架构变更
- 更新 `docs/SPEC.md` 反映新架构
- 创建 `docs/ARCHITECTURE.md` 说明分层设计

**验收标准**:
- ✅ 无遗留的旧代码
- ✅ 所有文档更新完成
- ✅ 代码审查通过

---

## 重构优先级

### P0 (必须完成)
1. ✅ 阶段 1: 定义协议层
2. ✅ 阶段 2: 拆分 PromptToolManager
3. ✅ 阶段 4: 依赖注入容器

### P1 (高优先级)
4. ✅ 阶段 3: 拆分 SmartToolManager
5. ✅ 阶段 5: 适配器层重构

### P2 (可延后)
6. ✅ 阶段 6: 测试覆盖
7. ✅ 阶段 7: 清理遗留代码

---

## 风险与缓解

### 风险 1: 重构期间功能回归
**缓解**:
- 每个阶段保持代码可运行
- 增量重构,不做大爆炸式改动
- 保留旧代码直到新代码验证通过

### 风险 2: SwiftUI 依赖注入复杂
**缓解**:
- 使用简单的构造函数注入
- 避免过度工程化 (不使用第三方 DI 框架)
- DependencyContainer 作为单一真源

### 风险 3: 性能影响
**缓解**:
- 协议调用开销可忽略 (Swift 编译器优化)
- 保持关键路径 (剪贴板监听) 性能不变
- 性能测试验证

---

## 成功标准

### 代码质量
- ✅ 每个类职责单一 (SRP)
- ✅ 依赖抽象而非具体实现 (DIP)
- ✅ 接口隔离 (ISP)
- ✅ 可扩展不修改 (OCP)

### 可测试性
- ✅ 核心逻辑可独立测试
- ✅ 可轻松 mock 外部依赖
- ✅ 测试覆盖率 >70%

### 可维护性
- ✅ 新功能添加不影响现有代码
- ✅ 依赖关系清晰
- ✅ 代码易于理解

---

**预计总时间**: 15-20 天 (按阶段增量完成)
**建议节奏**: 每完成一个阶段提交一次,保持代码可运行
