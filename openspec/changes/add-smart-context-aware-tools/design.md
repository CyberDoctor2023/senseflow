# Design: Smart Context-Aware Tool Selection

## Metadata
- **Change ID**: add-smart-context-aware-tools
- **Version**: 0.3.0
- **Phase**: Design
- **Date**: 2026-01-22

## Overview

实现智能工具推荐功能，通过屏幕截图 + AI 分析自动推荐最合适的 Prompt Tool。

**核心流程**:
1. 用户按 Cmd+Ctrl+V
2. 收集上下文（应用名、剪贴板、截图）
3. AI 分析并推荐工具
4. 用户确认后执行

---

## Technical Architecture

### Component Diagram

```
User Press Hotkey (Cmd+Ctrl+V)
         ↓
   HotKeyManager
         ↓
  SmartToolManager ← (orchestrator)
         ↓
    ┌────┴────┬────────────┬──────────┐
    ↓         ↓            ↓          ↓
NSWorkspace  NSPasteboard  ScreenCapture  PromptToolManager
(app info)   (clipboard)   (screenshot)   (available tools)
         ↓
   SmartContext (data model)
         ↓
    AIService.recommendTool()
         ↓
   SmartRecommendation (result)
         ↓
SmartRecommendationView (UI)
         ↓
   User Confirms → Execute Tool
```

---

## Phase 1: MVP Implementation

### 1. ScreenCaptureManager

**File**: `SenseFlow/Managers/ScreenCaptureManager.swift`

**Responsibilities**:
- 屏幕截图捕获
- Screen Recording 权限检查
- 图像压缩和格式转换

**Implementation**:

```swift
import ScreenCaptureKit
import CoreGraphics

@MainActor
class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    
    private init() {}
    
    // MARK: - Permission Check
    
    /// 检查 Screen Recording 权限状态
    func checkPermission() -> Bool {
        // ScreenCaptureKit 会在首次调用时自动请求权限
        // 通过尝试获取内容来检测权限
        return true // 详细实现见下文
    }
    
    /// 请求 Screen Recording 权限
    func requestPermission() async throws {
        // 首次调用 SCShareableContent 会触发系统权限请求
        _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
    
    // MARK: - Screenshot Capture
    
    /// 捕获当前活跃窗口截图
    func captureCurrentWindow() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // 获取最前面的窗口
        guard let frontWindow = content.windows.first else {
            throw ScreenCaptureError.noWindowAvailable
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: frontWindow)
        let config = SCStreamConfiguration()
        
        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenCaptureError.captureFailedUnknown)
                }
            }
        }
    }
    
    /// 捕获全屏截图（fallback）
    func captureFullScreen() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplayAvailable
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        
        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenCaptureError.captureFailedUnknown)
                }
            }
        }
    }
    
    // MARK: - Image Conversion
    
    /// 将 CGImage 转换为 Base64 编码的 JPEG
    func imageToBase64(_ image: CGImage, quality: CGFloat = 0.7) -> String? {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        guard let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
}

// MARK: - Error Types

enum ScreenCaptureError: LocalizedError {
    case noWindowAvailable
    case noDisplayAvailable
    case captureFailedUnknown
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noWindowAvailable:
            return "No window available for capture"
        case .noDisplayAvailable:
            return "No display available for capture"
        case .captureFailedUnknown:
            return "Screenshot capture failed"
        case .permissionDenied:
            return "Screen Recording permission denied"
        }
    }
}
```

**Key Decisions**:
- 使用 `SCScreenshotManager.captureImage()` 而非 `SCStream`（截图场景更简单）
- JPEG 压缩质量 0.7（平衡质量与文件大小）
- 优先捕获当前窗口，失败时降级到全屏

---

### 2. SmartContext Model

**File**: `SenseFlow/Models/SmartContext.swift`

**Implementation**:

```swift
import Foundation

/// 智能推荐的上下文数据
struct SmartContext: Codable {
    // MARK: - Application Info
    
    /// 当前活跃应用名称
    let applicationName: String
    
    /// 当前活跃应用 Bundle ID
    let bundleID: String
    
    // MARK: - Clipboard Info
    
    /// 剪贴板文本内容
    let clipboardText: String?
    
    /// 剪贴板是否包含图像
    let clipboardHasImage: Bool
    
    // MARK: - Screenshot
    
    /// 屏幕截图（Base64 编码）
    let screenshot: String?
    
    // MARK: - Metadata
    
    /// 上下文收集时间
    let timestamp: Date
    
    /// 是否使用轻量模式（无截图）
    let isLightweightMode: Bool
    
    // MARK: - Initialization
    
    init(
        applicationName: String,
        bundleID: String,
        clipboardText: String?,
        clipboardHasImage: Bool,
        screenshot: String?,
        isLightweightMode: Bool = false
    ) {
        self.applicationName = applicationName
        self.bundleID = bundleID
        self.clipboardText = clipboardText
        self.clipboardHasImage = clipboardHasImage
        self.screenshot = screenshot
        self.timestamp = Date()
        self.isLightweightMode = isLightweightMode
    }
    
    // MARK: - Helper Methods
    
    /// 生成用于 AI 分析的文本摘要
    func toPromptSummary() -> String {
        var summary = """
        Current Context:
        - Application: \(applicationName) (\(bundleID))
        - Clipboard: \(clipboardText?.prefix(100) ?? "empty")
        - Has Image: \(clipboardHasImage)
        """
        
        if isLightweightMode {
            summary += "\n- Screenshot: disabled (lightweight mode)"
        } else if screenshot != nil {
            summary += "\n- Screenshot: attached"
        } else {
            summary += "\n- Screenshot: unavailable"
        }
        
        return summary
    }
}
```

---

### 3. SmartRecommendation Model

**File**: `SenseFlow/Models/SmartRecommendation.swift`

**Implementation**:

```swift
import Foundation

/// AI 推荐结果
struct SmartRecommendation: Codable {
    // MARK: - Recommended Tool
    
    /// 推荐的工具 ID
    let toolID: UUID
    
    /// 推荐的工具名称
    let toolName: String
    
    /// 推荐理由
    let reason: String
    
    /// 置信度（0.0 - 1.0）
    let confidence: Double
    
    // MARK: - Metadata
    
    /// 推荐生成时间
    let timestamp: Date
    
    /// AI 响应时间（秒）
    let responseTime: TimeInterval
    
    // MARK: - Initialization
    
    init(toolID: UUID, toolName: String, reason: String, confidence: Double, responseTime: TimeInterval) {
        self.toolID = toolID
        self.toolName = toolName
        self.reason = reason
        self.confidence = confidence
        self.timestamp = Date()
        self.responseTime = responseTime
    }
    
    // MARK: - Validation
    
    /// 是否是高置信度推荐
    var isHighConfidence: Bool {
        confidence >= 0.7
    }
    
    /// 是否应该显示给用户
    var shouldPresent: Bool {
        confidence >= 0.5
    }
}

/// AI 推荐响应（从 AI 服务返回）
struct SmartRecommendationResponse: Codable {
    let tool_id: String
    let tool_name: String
    let reason: String
    let confidence: Double
}
```

**Key Decisions**:
- 置信度 < 0.5 时不显示推荐（避免误导用户）
- 置信度 >= 0.7 标记为高置信度（UI 可区分显示）
- 记录响应时间用于性能监控

---

### 4. SmartToolManager (Orchestrator)

**File**: `SenseFlow/Managers/SmartToolManager.swift`

**Responsibilities**:
- 编排整个推荐流程
- 收集上下文数据
- 调用 AI 服务
- 错误处理和超时控制

**Implementation** (核心方法):

```swift
import Foundation
import AppKit

@MainActor
class SmartToolManager {
    static let shared = SmartToolManager()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// 超时时间（秒）
    private let timeout: TimeInterval = 10.0
    
    /// 是否启用轻量模式
    @AppStorage("smartLightweightMode") private var isLightweightMode = false
    
    // MARK: - Main Flow
    
    /// 分析当前上下文并推荐工具
    func analyzeCurrentContext() async throws -> SmartRecommendation {
        let startTime = Date()
        
        // 1. 收集上下文
        let context = try await collectContext()
        
        // 2. 获取可用工具列表
        let availableTools = PromptToolManager.shared.tools
        guard !availableTools.isEmpty else {
            throw SmartToolError.noToolsAvailable
        }
        
        // 3. 调用 AI 推荐（带超时）
        let recommendation = try await withTimeout(timeout) {
            try await AIService.shared.recommendTool(
                context: context,
                availableTools: availableTools
            )
        }
        
        // 4. 验证推荐
        guard recommendation.shouldPresent else {
            throw SmartToolError.lowConfidence(recommendation.confidence)
        }
        
        // 5. 记录性能
        let responseTime = Date().timeIntervalSince(startTime)
        NotificationCenter.default.post(
            name: .smartRecommendationCompleted,
            object: nil,
            userInfo: ["responseTime": responseTime]
        )
        
        return recommendation
    }
    
    // MARK: - Context Collection
    
    private func collectContext() async throws -> SmartContext {
        // 获取当前应用信息
        let workspace = NSWorkspace.shared
        guard let frontApp = workspace.frontmostApplication else {
            throw SmartToolError.noActiveApplication
        }
        
        let appName = frontApp.localizedName ?? "Unknown"
        let bundleID = frontApp.bundleIdentifier ?? "unknown"
        
        // 读取剪贴板
        let pasteboard = NSPasteboard.general
        let clipboardText = pasteboard.string(forType: .string)
        let clipboardHasImage = pasteboard.availableType(from: [.tiff, .png]) != nil
        
        // 捕获截图（可选）
        var screenshot: String?
        if !isLightweightMode {
            do {
                let image = try await ScreenCaptureManager.shared.captureCurrentWindow()
                screenshot = ScreenCaptureManager.shared.imageToBase64(image)
            } catch {
                // 截图失败时降级到纯文本模式
                print("Screenshot failed: \(error), falling back to lightweight mode")
            }
        }
        
        return SmartContext(
            applicationName: appName,
            bundleID: bundleID,
            clipboardText: clipboardText,
            clipboardHasImage: clipboardHasImage,
            screenshot: screenshot,
            isLightweightMode: isLightweightMode || screenshot == nil
        )
    }
    
    // MARK: - Timeout Helper
    
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw SmartToolError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Error Types

enum SmartToolError: LocalizedError {
    case noActiveApplication
    case noToolsAvailable
    case lowConfidence(Double)
    case timeout
    case aiServiceNotConfigured
    case screenRecordingPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noActiveApplication:
            return "No active application found"
        case .noToolsAvailable:
            return "No Prompt Tools available for recommendation"
        case .lowConfidence(let confidence):
            return "Recommendation confidence too low: \(confidence)"
        case .timeout:
            return "AI recommendation timed out (>10s)"
        case .aiServiceNotConfigured:
            return "AI service not configured. Please set API key in Settings."
        case .screenRecordingPermissionDenied:
            return "Screen Recording permission denied. Enable in System Settings."
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let smartRecommendationCompleted = Notification.Name("smartRecommendationCompleted")
}
```

**Key Decisions**:
- 10 秒超时（平衡用户体验与 AI 响应时间）
- 截图失败时自动降级到轻量模式
- 使用 Task Group 实现超时控制
- 发送通知用于性能监控

---

### 5. AIService Extension

**File**: `SenseFlow/Services/AIService.swift` (扩展)

**New Method**:

```swift
extension AIService {
    /// 推荐最合适的 Prompt Tool
    func recommendTool(context: SmartContext, availableTools: [PromptTool]) async throws -> SmartRecommendation {
        let startTime = Date()
        
        // 构建 AI Prompt
        let systemPrompt = buildRecommendationSystemPrompt()
        let userPrompt = buildRecommendationUserPrompt(context: context, tools: availableTools)
        
        // 调用 AI
        let response: String
        if let screenshot = context.screenshot, !context.isLightweightMode {
            // Vision 模式（带截图）
            response = try await generateWithImage(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                imageBase64: screenshot
            )
        } else {
            // 纯文本模式
            response = try await generate(prompt: "\(systemPrompt)\n\n\(userPrompt)")
        }
        
        // 解析响应
        let recommendationData = try parseRecommendationResponse(response)
        
        // 查找工具
        guard let toolID = UUID(uuidString: recommendationData.tool_id),
              let tool = availableTools.first(where: { $0.id == toolID }) else {
            throw AIServiceError.invalidToolID
        }
        
        let responseTime = Date().timeIntervalSince(startTime)
        
        return SmartRecommendation(
            toolID: toolID,
            toolName: tool.name,
            reason: recommendationData.reason,
            confidence: recommendationData.confidence,
            responseTime: responseTime
        )
    }
    
    // MARK: - Prompt Building
    
    private func buildRecommendationSystemPrompt() -> String {
        """
        You are an AI assistant helping recommend the most suitable Prompt Tool based on user context.
        
        Analyze the following information:
        1. Current application the user is working in
        2. Clipboard content
        3. Screenshot of the current window (if available)
        
        Return a JSON response with this structure:
        {
          "tool_id": "UUID of recommended tool",
          "tool_name": "Name of the tool",
          "reason": "Brief explanation (1-2 sentences)",
          "confidence": 0.85 (0.0-1.0, how confident you are)
        }
        
        Rules:
        - Only recommend from the provided tool list
        - Confidence < 0.5 means uncertain (user will see fallback)
        - Consider context: app type, clipboard content, visual elements
        - Be concise in your reason
        """
    }
    
    private func buildRecommendationUserPrompt(context: SmartContext, tools: [PromptTool]) -> String {
        let toolList = tools.map { tool in
            """
            {
              "id": "\(tool.id.uuidString)",
              "name": "\(tool.name)",
              "prompt": "\(tool.prompt.prefix(100))..."
            }
            """
        }.joined(separator: ",\n")
        
        return """
        \(context.toPromptSummary())
        
        Available Tools:
        [\(toolList)]
        
        Which tool is most suitable for this context?
        """
    }
    
    private func parseRecommendationResponse(_ response: String) throws -> SmartRecommendationResponse {
        // 提取 JSON（去除 markdown 包裹）
        let jsonString = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(SmartRecommendationResponse.self, from: data)
    }
    
    // MARK: - Vision API Support
    
    private func generateWithImage(systemPrompt: String, userPrompt: String, imageBase64: String) async throws -> String {
        // 根据当前服务类型调用对应的 Vision API
        switch currentServiceType {
        case .openai:
            return try await generateOpenAIVision(system: systemPrompt, user: userPrompt, image: imageBase64)
        case .claude:
            return try await generateClaudeVision(system: systemPrompt, user: userPrompt, image: imageBase64)
        default:
            // 不支持 Vision 时降级到纯文本
            return try await generate(prompt: "\(systemPrompt)\n\n\(userPrompt)")
        }
    }
    
    private func generateOpenAIVision(system: String, user: String, image: String) async throws -> String {
        // OpenAI Vision API 实现
        // 使用 gpt-4o 或 gpt-4-turbo
        // ...
        fatalError("To be implemented")
    }
    
    private func generateClaudeVision(system: String, user: String, image: String) async throws -> String {
        // Claude Vision API 实现
        // 使用 claude-3.5-sonnet
        // ...
        fatalError("To be implemented")
    }
}

enum AIServiceError: LocalizedError {
    case invalidToolID
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidToolID:
            return "Recommended tool ID not found"
        case .invalidResponse:
            return "Failed to parse AI response"
        }
    }
}
```

**Key Decisions**:
- 系统 prompt 指导 AI 返回结构化 JSON
- 自动检测服务是否支持 Vision（OpenAI/Claude）
- 不支持 Vision 时降级到纯文本模式
- 解析失败时抛出明确错误

---
