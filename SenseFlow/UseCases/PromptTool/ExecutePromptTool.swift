//
//  ExecutePromptTool.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//
//  【教学说明 - Use Case 层】
//  这是 Clean Architecture 的 Use Case 层（应用业务逻辑层）
//
//  核心职责：
//  - 编排业务流程（orchestration）
//  - 协调多个服务完成一个完整的用户场景
//  - 不依赖具体实现，只依赖接口（抽象）
//
//  解耦原理：
//  1. 依赖倒置原则（DIP）：Use Case 依赖接口，不依赖具体实现
//     - aiService: AIServiceProtocol（接口）而非 OpenAIService（实现）
//     - clipboardReader: ClipboardReader（接口）而非 NSPasteboard（实现）
//
//  2. 单一职责原则（SRP）：只负责"执行工具"这一个业务场景
//     - 不负责数据持久化（Repository 的职责）
//     - 不负责快捷键注册（RegisterToolHotKey 的职责）
//     - 不负责 UI 交互（Coordinator 的职责）
//
//  3. 开闭原则（OCP）：对扩展开放，对修改关闭
//     - 想换 AI 服务？只需实现 AIServiceProtocol 接口
//     - 想换剪贴板实现？只需实现 ClipboardReader/Writer 接口
//     - Use Case 代码无需修改
//
//  依赖流向：
//  Use Case → 接口（Port）← 实现（Adapter）
//  核心业务逻辑不依赖外部框架，外部框架适配到接口
//

import Foundation

/// 执行 Prompt Tool 用例
///
/// 【业务场景】
/// 用户触发快捷键 → 读取剪贴板 → AI 处理 → 写回剪贴板 → 通知用户
///
/// 【依赖注入】
/// 所有依赖通过构造器注入（Constructor Injection）
/// 这样做的好处：
/// 1. 依赖关系清晰可见
/// 2. 易于测试（可以注入 Mock 对象）
/// 3. 编译时检查依赖完整性
final class ExecutePromptTool: Sendable {
    // MARK: - 依赖（全部是接口，不是具体实现）

    /// AI 传输层接口（新架构）
    /// 为什么用 Transport 而不是 AIService？
    /// - Transport 层负责所有与 AI 的通信
    /// - 包含记录、重试、追踪等横切关注点
    /// - Use Case 只关心"发送请求，获取响应"
    private let aiTransport: AITransport

    /// 剪贴板读取接口
    /// 为什么是接口？可以切换 NSPasteboard、测试用 Mock 等实现
    private let clipboardReader: ClipboardReader

    /// 剪贴板写入接口
    /// 为什么是接口？同上，解耦具体实现
    private let clipboardWriter: ClipboardWriter

    /// 通知服务接口
    /// 为什么是接口？可以切换 UserNotification、测试用 Mock 等实现
    private let notificationService: NotificationServiceProtocol

    /// 构造器注入（Dependency Injection）
    ///
    /// 【设计模式】Constructor Injection
    /// 优点：
    /// 1. 依赖关系显式声明
    /// 2. 对象创建后立即可用（不会出现未初始化的依赖）
    /// 3. 易于单元测试（可以注入 Mock）
    ///
    /// 【架构改进】
    /// 之前：依赖 AIServiceProtocol（业务层接口）
    /// 现在：依赖 AITransport（传输层接口）
    /// 好处：
    /// - 关注点分离：Use Case 不关心记录、重试等细节
    /// - 横切关注点集中管理：所有 Transport 都有记录功能
    /// - 更好的可测试性：可以注入 MockTransport
    init(
        aiTransport: AITransport,
        clipboardReader: ClipboardReader,
        clipboardWriter: ClipboardWriter,
        notificationService: NotificationServiceProtocol
    ) {
        self.aiTransport = aiTransport
        self.clipboardReader = clipboardReader
        self.clipboardWriter = clipboardWriter
        self.notificationService = notificationService
    }

    /// 执行工具（核心业务流程）
    ///
    /// 【业务流程编排】
    /// 这个方法展示了 Use Case 的核心职责：编排（Orchestration）
    /// 它协调多个服务完成一个完整的业务场景
    ///
    /// 【Tell, Don't Ask 原则】
    /// 注意：我们"告诉"各个服务做什么，而不是"询问"它们的状态后再决定
    /// 例如：notificationService.showInProgress(...) 而不是 if notificationService.canShow() { ... }
    ///
    /// 【错误处理】
    /// 使用 Swift 的 throws 机制，让调用者决定如何处理错误
    /// 这符合"关注点分离"原则：Use Case 负责业务逻辑，Coordinator 负责错误处理
    ///
    /// - Parameter tool: 要执行的工具（Domain Entity）
    /// - Returns: AI 生成的结果
    /// - Throws: ExecuteToolError 如果执行失败
    func execute(tool: PromptTool) async throws -> String {
        // 【步骤 1】显示进度通知
        // 为什么先通知？给用户即时反馈，提升体验
        notificationService.showInProgress(
            title: tool.name,
            body: "正在处理剪贴板内容..."
        )

        // 【步骤 2】读取剪贴板内容
        // 注意：使用 guard let 进行早期返回（Early Return）
        // 这避免了深层嵌套，提高代码可读性
        guard let input = clipboardReader.readText() else {
            // 失败时通知用户
            notificationService.showError(
                title: tool.name,
                body: "剪贴板为空或不包含文本内容"
            )
            // 抛出领域错误（Domain Error）
            throw ExecuteToolError.emptyClipboard
        }

        // 【步骤 3】调用 AI 传输层生成结果
        // 新架构：通过 Transport 层发送请求
        // - Transport 层自动处理记录、追踪等横切关注点
        // - Use Case 只关心业务逻辑
        let transportRequest = AITransportRequest(
            toolName: tool.name,
            systemPrompt: tool.prompt,
            userInput: input
        )

        let transportResponse = try await aiTransport.send(transportRequest)
        let result = transportResponse.content

        // 【步骤 4】写入剪贴板
        // 为什么用 await？写入剪贴板可能涉及主线程操作
        await clipboardWriter.write(result)

        // 【步骤 5】自动粘贴（如果启用）
        // 检查用户设置，决定是否自动执行 Cmd+V
        let autoPasteEnabled = UserDefaults.standard.object(forKey: "auto_paste_enabled") as? Bool ?? true
        if autoPasteEnabled {
            await MainActor.run {
                AutoPasteManager.shared.performAutoPaste(delay: 0.15)
            }
        }

        // 【步骤 6】显示成功通知
        notificationService.showSuccess(
            title: tool.name,
            body: "已完成并写入剪贴板"
        )

        // 返回结果（供调用者使用，例如记录日志）
        return result
    }
}

// MARK: - Errors

enum ExecuteToolError: LocalizedError {
    case emptyClipboard
    case aiServiceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .emptyClipboard:
            return "剪贴板为空或不包含文本内容"
        case .aiServiceFailed(let error):
            return "AI 服务失败: \(error.localizedDescription)"
        }
    }
}
