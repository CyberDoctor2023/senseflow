//
//  APIRequestRecorder.swift
//  SenseFlow
//
//  Created on 2026-02-26.
//
//  【架构说明 - Domain Port】
//  这是 API 请求记录的抽象接口（Port）
//
//  职责：
//  - 定义记录 API 请求的能力
//  - 定义查询记录的能力
//  - 不依赖具体实现（内存、数据库、文件等）
//
//  设计原则：
//  - 依赖倒置原则（DIP）：Use Case 依赖接口，不依赖实现
//  - 接口隔离原则（ISP）：只定义必要的方法
//  - 单一职责原则（SRP）：只负责记录和查询
//

import Foundation

/// API 请求记录
///
/// 【Domain Entity】
/// 记录真正发送给 AI API 的 HTTP 请求内容
struct APIRequestRecord: Sendable {
    /// 唯一标识
    let id: UUID

    /// 时间戳
    let timestamp: Date

    /// 工具名称（哪个 Prompt Tool）
    let toolName: String

    /// AI 服务类型（OpenAI、Claude、Gemini 等）
    let serviceType: String

    /// 模型名称
    let modelName: String

    /// HTTP 方法
    let httpMethod: String

    /// HTTP Endpoint
    let endpoint: String

    /// HTTP 请求头（JSON 字符串，敏感字段已脱敏）
    let headersJSON: String?

    /// HTTP Body（JSON 字符串，完整请求体）
    let requestBodyJSON: String

    /// 完整的 messages 数组（JSON 字符串）
    /// 包括 system prompt、user input、图片 base64 等
    let messagesJSON: String

    /// 请求参数（JSON 字符串）
    /// 包括 temperature、max_tokens 等
    let parametersJSON: String?

    /// 是否包含图片
    let hasImage: Bool

    /// 图片数量
    let imageCount: Int

    /// 模型回复文本（成功时可用）
    let responseText: String?

    /// 错误信息（如果请求失败）
    let error: String?

    /// 是否成功
    var isSuccess: Bool {
        error == nil
    }

    /// 格式化的时间戳
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    /// 初始化
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        toolName: String,
        serviceType: String,
        modelName: String,
        httpMethod: String = "POST",
        endpoint: String = "",
        headersJSON: String? = nil,
        requestBodyJSON: String = "{}",
        messagesJSON: String,
        parametersJSON: String? = nil,
        hasImage: Bool = false,
        imageCount: Int = 0,
        responseText: String? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.toolName = toolName
        self.serviceType = serviceType
        self.modelName = modelName
        self.httpMethod = httpMethod
        self.endpoint = endpoint
        self.headersJSON = headersJSON
        self.requestBodyJSON = requestBodyJSON
        self.messagesJSON = messagesJSON
        self.parametersJSON = parametersJSON
        self.hasImage = hasImage
        self.imageCount = imageCount
        self.responseText = responseText
        self.error = error
    }
}

/// API 请求记录器协议（Port）
///
/// 【职责】
/// 定义记录和查询 API 请求的能力
///
/// 【实现者】
/// - InMemoryAPIRequestRecorder：内存实现（当前）
/// - DatabaseAPIRequestRecorder：数据库实现（未来）
/// - FileAPIRequestRecorder：文件实现（未来）
///
/// 【为什么需要协议？】
/// 1. 解耦：Use Case 不依赖具体实现
/// 2. 可测试：可以注入 Mock 实现
/// 3. 可扩展：可以随时切换存储方式
/// 4. 灵活性：可以同时使用多个实现（组合模式）
protocol APIRequestRecorder: Sendable {
    /// 记录请求
    ///
    /// - Parameter record: 请求记录
    func record(_ record: APIRequestRecord) async

    /// 获取最后一次记录
    ///
    /// - Returns: 最后一次记录，如果没有则返回 nil
    func getLastRecord() async -> APIRequestRecord?

    /// 获取所有记录
    ///
    /// - Parameter limit: 最多返回的记录数，nil 表示不限制
    /// - Returns: 记录列表，按时间倒序
    func getAllRecords(limit: Int?) async -> [APIRequestRecord]

    /// 清空所有记录
    func clearAll() async
}

/// 可观察的 API 请求记录器协议
///
/// 【扩展协议】
/// 为 UI 层提供响应式能力
///
/// 【为什么分离？】
/// - 核心协议（APIRequestRecorder）不依赖 UI 框架
/// - 可观察协议（ObservableAPIRequestRecorder）为 SwiftUI 提供便利
/// - 符合接口隔离原则（ISP）
protocol ObservableAPIRequestRecorder: APIRequestRecorder, AnyObject {
    /// 最后一次记录（可观察）
    var lastRecord: APIRequestRecord? { get }

    /// 所有记录（可观察，按时间倒序）
    var allRecords: [APIRequestRecord] { get }
}

/// API 请求展示详情（用于开发者面板）
///
/// 只包含界面真正需要的业务字段，避免 UI 直接解析底层 HTTP JSON
struct APIRequestScreenshotPreview: Sendable {
    /// 展示标题（例如：图1（焦点应用窗口））
    let title: String

    /// 图片二进制数据
    let data: Data
}

/// API 请求展示详情（用于开发者面板）
///
/// 只包含界面真正需要的业务字段，避免 UI 直接解析底层 HTTP JSON
struct APIRequestDisplayDetail: Sendable {
    /// 最终提取到的 system prompt
    let systemPrompt: String

    /// 最终提取到的 user prompt
    let userPrompt: String

    /// 模型原始回复文本（如有）
    let responseText: String

    /// 请求中的截图预览列表（按发送顺序）
    let screenshotPreviews: [APIRequestScreenshotPreview]
}

/// API 请求展示服务协议（Application Port）
///
/// 职责：
/// - 从记录模型中提取 UI 需要的业务信息
/// - 屏蔽底层 payload 结构差异
protocol APIRequestInspectionService: Sendable {
    /// 构建展示详情
    func buildDetail(from record: APIRequestRecord) -> APIRequestDisplayDetail
}
