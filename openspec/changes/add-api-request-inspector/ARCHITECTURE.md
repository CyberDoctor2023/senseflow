# API Request Inspector - 工程化架构设计

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│              (APIRequestInspectorView)                       │
│                         ↓ 读取                                │
│              InMemoryAPIRequestRecorder                      │
│                    (@ObservedObject)                         │
└─────────────────────────────────────────────────────────────┘
                              ↑ 记录
┌─────────────────────────────────────────────────────────────┐
│                     Use Case Layer                           │
│                  (ExecutePromptTool)                         │
│                         ↓ 依赖注入                            │
│                    AITransport (Port)                        │
└─────────────────────────────────────────────────────────────┘
                              ↓ 实现
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                        │
│                                                              │
│  LoggingAITransport (Decorator)                             │
│         ↓ 装饰                                               │
│  RealAITransport (Adapter)                                  │
│         ↓ 委托                                               │
│  AIServiceProtocol → AIService.shared                       │
└─────────────────────────────────────────────────────────────┘
```

## 核心设计原则

### 1. 传输层（Transport Layer）

**职责**：
- 所有与 AI API 的通信都经过 Transport 层
- 处理横切关注点（记录、重试、追踪、超时等）
- 提供统一的错误处理

**为什么需要？**
- ✅ 关注点分离：Use Case 只关心业务逻辑
- ✅ 横切关注点集中管理：记录、重试等逻辑不散落在各处
- ✅ 可测试性：可以注入 MockTransport
- ✅ 可观测性：所有 API 调用都经过这一层

### 2. Decorator Pattern（装饰器模式）

**实现**：
```swift
// 1. 真实传输层（调用 AI API）
let realTransport = RealAITransport(aiService: aiService)

// 2. 装饰器：添加记录功能
let loggingTransport = LoggingAITransport(
    transport: realTransport,
    recorder: recorder
)

// 3. 未来可以继续装饰
let retryTransport = RetryAITransport(
    transport: loggingTransport,
    maxRetries: 3
)
```

**好处**：
- ✅ 开闭原则：不修改 RealTransport，通过装饰添加功能
- ✅ 单一职责：每个 Transport 只负责一件事
- ✅ 灵活组合：可以选择性地添加功能

### 3. Dependency Injection（依赖注入）

**Use Case 依赖**：
```swift
class ExecutePromptTool {
    private let aiTransport: AITransport  // 接口，不是具体实现

    init(aiTransport: AITransport, ...) {
        self.aiTransport = aiTransport
    }
}
```

**DI 容器组装**：
```swift
class DependencyContainer {
    lazy var aiTransport: AITransport = {
        let real = RealAITransport(aiService: aiService)
        return LoggingAITransport(transport: real, recorder: recorder)
    }()

    lazy var executePromptToolUseCase: ExecutePromptTool = {
        ExecutePromptTool(aiTransport: aiTransport, ...)
    }()
}
```

## 数据流

### 请求流程

```
1. User 触发 Prompt Tool
   ↓
2. ExecutePromptTool.execute(tool)
   ↓
3. aiTransport.send(request)  // Transport 接口
   ↓
4. LoggingAITransport.send()  // 装饰器
   ├─ 记录开始时间
   ├─ 调用被装饰的 Transport
   ├─ 记录结果（成功/失败）
   └─ recorder.record(APIRequestRecord)
   ↓
5. RealAITransport.send()  // 真实实现
   ├─ 调用 aiService.generate()
   └─ 封装响应
   ↓
6. AIService.shared.generate()  // 底层 AI 服务
   ↓
7. OpenAI/Gemini/Claude API
```

### 记录流程

```
1. LoggingAITransport 记录请求
   ↓
2. recorder.record(APIRequestRecord)
   ↓
3. InMemoryAPIRequestRecorder.record()
   ├─ 更新 @Published lastRecord
   └─ 触发 SwiftUI 更新
   ↓
4. APIRequestInspectorView 自动刷新
```

## 文件结构

```
SenseFlow/
├── Domain/
│   └── Protocols/
│       ├── AITransport.swift              # 传输层接口（Port）
│       └── APIRequestRecorder.swift       # 记录器接口（Port）
│
├── Infrastructure/
│   ├── Transport/
│   │   ├── RealAITransport.swift         # 真实传输层实现
│   │   └── LoggingAITransport.swift      # 带记录的装饰器
│   │
│   ├── Recorders/
│   │   └── InMemoryAPIRequestRecorder.swift  # 内存记录器实现
│   │
│   └── DI/
│       └── DependencyContainer.swift      # DI 容器（组装所有依赖）
│
├── UseCases/
│   └── PromptTool/
│       └── ExecutePromptTool.swift        # Use Case（依赖 Transport）
│
└── Views/
    └── Settings/
        └── APIRequestInspectorView.swift  # UI（展示记录）
```

## 关键接口

### AITransport（传输层接口）

```swift
protocol AITransport: Sendable {
    func send(_ request: AITransportRequest) async throws -> AITransportResponse
}
```

### APIRequestRecorder（记录器接口）

```swift
protocol APIRequestRecorder: Sendable {
    func record(_ record: APIRequestRecord) async
    func getLastRecord() async -> APIRequestRecord?
    func getAllRecords(limit: Int?) async -> [APIRequestRecord]
    func clearAll() async
}
```

## 扩展性

### 添加重试功能

```swift
class RetryAITransport: AITransport {
    private let transport: AITransport
    private let maxRetries: Int

    func send(_ request: AITransportRequest) async throws -> AITransportResponse {
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                return try await transport.send(request)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        throw lastError!
    }
}
```

### 添加追踪功能

```swift
class TracingAITransport: AITransport {
    private let transport: AITransport
    private let tracer: Tracer

    func send(_ request: AITransportRequest) async throws -> AITransportResponse {
        return try await tracer.withSpan(name: "ai.transport") { span in
            span.setAttribute(key: "tool.name", value: request.toolName)
            return try await transport.send(request)
        }
    }
}
```

### 组合多个装饰器

```swift
lazy var aiTransport: AITransport = {
    let real = RealAITransport(aiService: aiService)
    let logging = LoggingAITransport(transport: real, recorder: recorder)
    let retry = RetryAITransport(transport: logging, maxRetries: 3)
    let tracing = TracingAITransport(transport: retry, tracer: tracer)
    return tracing
}()
```

## 测试支持

### Mock Transport

```swift
class MockAITransport: AITransport {
    var mockResponse: AITransportResponse?
    var mockError: Error?

    func send(_ request: AITransportRequest) async throws -> AITransportResponse {
        if let error = mockError {
            throw error
        }
        return mockResponse!
    }
}
```

### 单元测试

```swift
func testExecutePromptTool() async throws {
    // Arrange
    let mockTransport = MockAITransport()
    mockTransport.mockResponse = AITransportResponse(
        content: "Hello",
        serviceType: "OpenAI",
        modelName: "gpt-4"
    )

    let useCase = ExecutePromptTool(
        aiTransport: mockTransport,
        ...
    )

    // Act
    let result = try await useCase.execute(tool: testTool)

    // Assert
    XCTAssertEqual(result, "Hello")
}
```

## 总结

这个架构的核心思想是：

1. **传输层是核心业务逻辑的一部分**，不是"调试专用"的附加功能
2. **所有 AI 请求都经过 Transport 层**，确保横切关注点统一处理
3. **Decorator 模式**提供灵活的功能组合
4. **依赖注入**确保可测试性和可扩展性
5. **关注点分离**：Use Case 只关心业务逻辑，Transport 处理传输细节

这是一个**工程级的架构设计**，不是简单的"加个调试功能"。
