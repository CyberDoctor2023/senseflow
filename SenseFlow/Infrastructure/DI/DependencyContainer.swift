//
//  DependencyContainer.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - 依赖注入容器】
//  这是整个应用的"依赖工厂"，负责创建和组装所有对象
//
//  核心概念：
//  1. 控制反转（IoC - Inversion of Control）
//     - 传统方式：对象自己创建依赖 → new OpenAIService()
//     - IoC 方式：容器创建依赖并注入 → container.aiService
//
//  2. 依赖注入（DI - Dependency Injection）
//     - 对象不主动获取依赖，而是被动接收依赖
//     - 好处：解耦、可测试、可配置
//
//  3. 单一职责原则（SRP）
//     - 这个类只负责"组装对象"
//     - 不负责业务逻辑、不负责数据处理
//
//  设计模式：
//  - Factory Pattern：创建对象
//  - Service Locator Pattern：提供依赖查找
//  - Lazy Initialization：延迟创建（用到时才创建）
//
//  依赖层次（从底层到高层）：
//  Infrastructure（基础设施）→ Adapters（适配器）→ Use Cases（用例）→ Coordinators（协调器）
//

import Foundation

/// 依赖注入容器
///
/// 【职责】
/// 1. 创建所有依赖对象
/// 2. 管理对象生命周期
/// 3. 解决依赖关系（A 依赖 B，B 依赖 C...）
///
/// 【使用方式】
/// ```swift
/// let container = DependencyContainer()
/// let coordinator = container.promptToolCoordinator  // 自动创建所有依赖
/// ```
final class DependencyContainer {

    // MARK: - Singletons (Infrastructure Layer - 基础设施层)
    //
    // 【设计说明】
    // 这些是应用的基础设施单例（已存在的遗留代码）
    // 理想情况下应该也通过 DI 管理，但为了兼容性暂时保留
    //
    // 【Lazy 关键字】
    // lazy var 的作用：
    // 1. 延迟初始化：只有访问时才创建
    // 2. 避免循环依赖：可以在初始化时引用 self
    // 3. 性能优化：不用的对象不创建

    private lazy var databaseManager = DatabaseManager.shared
    private lazy var clipboardMonitor = ClipboardMonitor.shared
    private lazy var screenCaptureManager = ScreenCaptureManager.shared
    private lazy var existingNotificationService = SenseFlow.NotificationService.shared
    private lazy var uiTreeAXElementAccessor: any OpenClawAXElementAccessing = {
        OpenClawAXElementAccessor()
    }()
    private lazy var uiTreeCandidateBuilder: any OpenClawUITreeCandidateBuilding = {
        OpenClawUITreeCandidateBuilder()
    }()
    private lazy var uiTreeAnnotationMapper: any OpenClawUITreeAnnotationMapping = {
        OpenClawUITreeAnnotationMapper()
    }()
    private lazy var uiTreeOverlayAnnotationProvider: any SystemContextCollector.UITreeOverlayAnnotationProviding = {
        OpenClawUITreeOverlayAnnotationProvider(
            axAccessor: uiTreeAXElementAccessor,
            candidateBuilder: uiTreeCandidateBuilder,
            annotationMapper: uiTreeAnnotationMapper
        )
    }()
    private lazy var uiTreeOverlayRenderer: any SystemContextCollector.UITreeOverlayRendering = {
        OpenClawUITreeOverlayRenderer()
    }()
    private lazy var uiTreeLiveOverlayPresenter: any SystemContextCollector.UITreeLiveOverlayPresenting & SmartAILiveOverlaySessionControlling = {
        OpenClawUITreeLiveOverlayPresenter(overlayRenderer: uiTreeOverlayRenderer)
    }()

    // MARK: - Transport Layer (传输层)
    //
    // 【Transport Layer 传输层】
    // 职责：负责所有与外部服务的通信
    //
    // 为什么需要 Transport 层？
    // 1. 关注点分离：Use Case 不关心传输细节
    // 2. 横切关注点：记录、重试、追踪等逻辑集中管理
    // 3. 装饰器模式：可以灵活组合多个 Transport
    //
    // 【架构层次】
    // Use Case → Transport（接口）→ Logging Transport → Real Transport → AI Service
    //
    // 【Decorator Pattern】
    // LoggingTransport 装饰 RealTransport，透传请求上下文
    // 真实请求记录在 Provider 层完成
    // 未来可以继续添加：RetryTransport、TracingTransport 等

    lazy var aiTransport: AITransport = {
        // 1. 创建真实的传输层（调用 AI API）
        let realTransport = RealAITransport(aiService: aiService)

        // 2. 用 Logging 装饰器包装（透传上下文）
        let loggingTransport = LoggingAITransport(
            transport: realTransport
        )

        // 3. 返回装饰后的 Transport
        // 所有请求都会经过：Use Case → Logging(Context) → Real → AI Service
        return loggingTransport
    }()

    // MARK: - Recorders (Infrastructure Layer - 记录器)
    //
    // 【Recorder Pattern 记录器模式】
    // 职责：记录应用运行时的关键信息（API 请求、日志、追踪等）
    //
    // 为什么需要 Recorder？
    // 1. 调试支持：开发者可以查看 API 请求详情
    // 2. 可观测性：了解应用运行状态
    // 3. 解耦：Use Case 不关心记录的具体实现
    //
    // 【依赖关系】
    // Use Case → APIRequestRecorder（接口）
    // InMemoryAPIRequestRecorder（实现）

    lazy var apiRequestRecorder: APIRequestRecorder = {
        // 使用内存实现的 API 请求记录器
        // 未来可以切换到数据库或文件实现
        InMemoryAPIRequestRecorder.shared
    }()

    /// API 请求展示服务（将底层 payload 映射为可读业务信息）
    lazy var apiRequestInspectionService: APIRequestInspectionService = {
        UnifiedAPIRequestInspectionService()
    }()

    // MARK: - Repositories (Data Access Layer - 数据访问层)
    //
    // 【Repository Pattern 仓库模式】
    // 职责：封装数据访问逻辑，提供领域对象的 CRUD 操作
    //
    // 为什么需要 Repository？
    // 1. 隔离数据源：业务逻辑不关心数据来自 SQLite、CoreData 还是网络
    // 2. 统一接口：所有数据访问通过统一的接口（PromptToolRepository）
    // 3. 易于测试：可以用 MockRepository 替换真实实现
    //
    // 【依赖关系】
    // Repository → DatabaseManager（基础设施）
    // Use Case → Repository（接口）
    //
    // 【对比传统方式】
    // 传统：Use Case 直接调用 DatabaseManager.shared.query(...)  ❌ 紧耦合
    // 现在：Use Case 调用 repository.findAll()  ✅ 松耦合

    lazy var promptToolRepository: PromptToolRepository = {
        // 创建 SQLite 实现的 Repository
        // 注意：返回类型是接口（PromptToolRepository）
        // 实际类型是实现（SQLitePromptToolRepository）
        // 这就是"面向接口编程"
        SQLitePromptToolRepository(databaseManager: databaseManager)
    }()

    // MARK: - Services (Adapter Layer - 适配器层)
    //
    // 【Adapter Pattern 适配器模式】
    // 职责：将外部框架/服务适配到我们定义的接口
    //
    // 为什么需要 Adapter？
    // 1. 隔离外部依赖：业务逻辑不直接依赖 NSPasteboard、全局快捷键实现等
    // 2. 统一接口：不同的实现（NSPasteboard、Mock）都实现同一接口
    // 3. 易于替换：想换实现？只需写一个新的 Adapter
    //
    // 【六边形架构（Hexagonal Architecture）】
    // 核心思想：业务逻辑在中心，外部世界通过"端口和适配器"连接
    // - Port（端口）：接口定义（ClipboardReader、AIServiceProtocol）
    // - Adapter（适配器）：接口实现（NSPasteboardAdapter、OpenAIServiceAdapter）
    //
    // 依赖流向：
    // Use Case → Port（接口）← Adapter → 外部框架
    //           ↑ 依赖方向      ↑ 实现方向

    lazy var clipboardReader: ClipboardReader = {
        // 将 NSPasteboard 适配到 ClipboardReader 接口
        // 好处：Use Case 不知道 NSPasteboard 的存在
        NSPasteboardAdapter(monitor: clipboardMonitor)
    }()

    lazy var clipboardWriter: ClipboardWriter = {
        // 将 NSPasteboard 适配到 ClipboardWriter 接口
        // 注意：Reader 和 Writer 是分离的接口（Interface Segregation Principle）
        NSPasteboardAdapter(monitor: clipboardMonitor)
    }()

    lazy var notificationService: NotificationServiceProtocol = {
        // 将现有的 NotificationService 适配到接口
        UserNotificationAdapter(notificationService: existingNotificationService)
    }()

    lazy var aiService: AIServiceProtocol = {
        // 将现有的 AIService.shared 适配到接口
        // 这样 Use Case 不依赖具体的 AI 服务实现
        OpenAIServiceAdapter(aiService: SenseFlow.AIService.shared)
    }()

    /// 用户可见 AI API 配置服务（不包含 Langfuse）
    /// 用于 Settings 等 UI 层，统一管理服务切换、API Key、连接测试
    lazy var userAPISettingsService: UserAPISettingsServiceProtocol = {
        UserAPISettingsServiceAdapter(
            aiService: SenseFlow.AIService.shared,
            keychainManager: KeychainManager.shared
        )
    }()

    lazy var contextCollector: ContextCollector = {
        // 上下文收集器：收集剪贴板、屏幕截图等上下文信息
        // 用于 Smart AI 功能
        SystemContextCollector(
            clipboardReader: clipboardReader,
            screenCapture: screenCaptureManager,
            overlayAnnotationProvider: uiTreeOverlayAnnotationProvider,
            overlayRenderer: uiTreeOverlayRenderer,
            liveOverlayPresenter: uiTreeLiveOverlayPresenter
        )
    }()

    // MARK: - Use Cases (Application Business Logic - 应用业务逻辑层)
    //
    // 【Use Case Layer 用例层】
    // 职责：实现具体的业务场景（用户故事）
    //
    // 特点：
    // 1. 每个 Use Case 对应一个用户操作
    // 2. 编排多个服务完成业务流程
    // 3. 不依赖具体实现，只依赖接口
    //
    // 【依赖注入的威力】
    // 看下面的 executePromptToolUseCase：
    // - 它需要 4 个依赖：aiService, clipboardReader, clipboardWriter, notificationService
    // - 容器自动解决这些依赖关系
    // - Use Case 代码完全不知道具体实现是什么
    //
    // 【测试友好】
    // 单元测试时，可以注入 Mock 对象：
    // ```swift
    // let mockAI = MockAIService()
    // let useCase = ExecutePromptTool(aiService: mockAI, ...)
    // ```

    lazy var executePromptToolUseCase: ExecutePromptTool = {
        // 创建"执行工具"用例
        // 注入 4 个依赖（全部是接口）
        // 注意：现在使用 aiTransport 而不是 aiService
        ExecutePromptTool(
            aiTransport: aiTransport,                // AI 传输层接口（新架构）
            clipboardReader: clipboardReader,        // 剪贴板读取接口
            clipboardWriter: clipboardWriter,        // 剪贴板写入接口
            notificationService: notificationService // 通知服务接口
        )
    }()

    lazy var analyzeAndRecommendUseCase: AnalyzeAndRecommend = {
        // 创建"智能推荐"用例
        // 这是一个复杂的 Use Case，依赖多个服务
        AnalyzeAndRecommend(
            contextCollector: contextCollector,           // 上下文收集
            toolRepository: promptToolRepository,         // 工具仓库
            aiService: aiService,                         // AI 服务
            executeToolUseCase: executePromptToolUseCase, // 执行工具用例（Use Case 可以依赖其他 Use Case）
            notificationService: notificationService,      // 通知服务
            liveOverlaySessionController: uiTreeLiveOverlayPresenter
        )
    }()

    // MARK: - Coordinators (Presentation Logic - 表现层逻辑)
    //
    // 【Coordinator Pattern 协调器模式】
    // 职责：协调 UI 和业务逻辑，处理用户交互
    //
    // 为什么需要 Coordinator？
    // 1. 分离关注点：UI 不直接调用 Use Case
    // 2. 错误处理：统一处理业务逻辑的错误
    // 3. 导航逻辑：管理页面跳转（本项目中较少）
    //
    // 【层次关系】
    // SwiftUI View → Coordinator → Use Case → Repository/Service
    //
    // 【依赖方向】
    // 所有依赖都指向内层（业务逻辑）
    // Coordinator 依赖 Use Case，Use Case 依赖 Service
    // 反过来不行！Use Case 不能依赖 Coordinator

    lazy var promptToolCoordinator: PromptToolCoordinator = {
        // 创建 Prompt Tool 协调器
        // 它协调 2 个 Use Case + 1 个快捷键协调器：
        // 1. Repository：数据访问
        // 2. ExecutePromptTool：执行工具
        // 3. AppHotKeyCoordinator：统一快捷键业务
        PromptToolCoordinator(
            repository: promptToolRepository,
            executeToolUseCase: executePromptToolUseCase,
            hotKeyCoordinator: AppHotKeyCoordinator.shared
        )
    }()

    lazy var smartToolCoordinator: SmartToolCoordinator = {
        // 创建 Smart Tool 协调器
        // 它只需要一个 Use Case：智能推荐
        SmartToolCoordinator(
            analyzeAndRecommendUseCase: analyzeAndRecommendUseCase
        )
    }()
}
