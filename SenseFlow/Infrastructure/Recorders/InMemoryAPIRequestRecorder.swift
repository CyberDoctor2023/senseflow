//
//  InMemoryAPIRequestRecorder.swift
//  SenseFlow
//
//  Created on 2026-02-26.
//
//  【架构说明 - Infrastructure Adapter】
//  这是 APIRequestRecorder 的内存实现（Adapter）
//
//  职责：
//  - 在内存中存储 API 请求记录
//  - 提供线程安全的访问
//  - 支持 SwiftUI 响应式更新
//
//  设计模式：
//  - Adapter Pattern：将内存存储适配到 APIRequestRecorder 接口
//  - Singleton Pattern：全局单例，便于访问
//  - Observer Pattern：通过 @Published 支持响应式
//
//  为什么用内存存储？
//  - 简单：无需数据库或文件 I/O
//  - 快速：读写性能最优
//  - 适合调试：重启清空，不会积累垃圾数据
//
//  未来扩展：
//  - 可以添加 DatabaseAPIRequestRecorder 实现持久化
//  - 可以添加 FileAPIRequestRecorder 导出到文件
//  - 可以使用 CompositeRecorder 同时记录到多个地方
//

import Foundation
import Combine

/// 内存 API 请求记录器
///
/// 【实现说明】
/// - 使用 actor 确保线程安全
/// - 使用 @Published 支持 SwiftUI 响应式
/// - 只保留最近的记录（可配置数量）
@MainActor
final class InMemoryAPIRequestRecorder: ObservableObject, ObservableAPIRequestRecorder {

    // MARK: - Singleton

    /// 单例实例
    ///
    /// 【为什么用单例？】
    /// - 全局唯一的记录器
    /// - 便于在 DI 容器中注册
    /// - 便于在 UI 中直接访问（用于展示）
    ///
    /// 【注意】
    /// 虽然是单例，但通过 DI 注入到 Use Case
    /// 这样既保证了便利性，又保持了可测试性
    static let shared = InMemoryAPIRequestRecorder()

    // MARK: - Properties

    /// 最后一次记录（可观察）
    @Published private(set) var lastRecord: APIRequestRecord?

    /// 所有记录（可观察，最新在前）
    @Published private(set) var allRecords: [APIRequestRecord] = []

    /// 最大记录数
    ///
    /// 【为什么限制数量？】
    /// - 防止内存无限增长
    /// - 调试时通常只关心最近的请求
    /// - 如果需要更多历史，应该用数据库实现
    private let maxRecords: Int?

    // MARK: - Initialization

    /// 初始化
    ///
    /// - Parameter maxRecords: 最大记录数，nil 表示不限制（默认）
    init(maxRecords: Int? = nil) {
        self.maxRecords = maxRecords
    }

    // MARK: - APIRequestRecorder

    /// 记录请求
    func record(_ record: APIRequestRecord) async {
        // 插入到列表开头（最新的在前面）
        allRecords.insert(record, at: 0)

        // 限制记录数量
        if let maxRecords, allRecords.count > maxRecords {
            allRecords.removeLast()
        }

        // 更新最后一次记录（触发 UI 更新）
        lastRecord = record
    }

    /// 获取最后一次记录
    func getLastRecord() async -> APIRequestRecord? {
        return lastRecord
    }

    /// 获取所有记录
    func getAllRecords(limit: Int? = nil) async -> [APIRequestRecord] {
        if let limit = limit {
            return Array(allRecords.prefix(limit))
        }
        return allRecords
    }

    /// 清空所有记录
    func clearAll() async {
        allRecords.removeAll()
        lastRecord = nil
    }
}

// MARK: - Factory

extension InMemoryAPIRequestRecorder {
    /// 创建用于测试的实例
    ///
    /// 【测试支持】
    /// 提供独立的实例，避免测试之间相互影响
    static func makeForTesting(maxRecords: Int? = 10) -> InMemoryAPIRequestRecorder {
        return InMemoryAPIRequestRecorder(maxRecords: maxRecords)
    }
}

/// 统一 API 请求展示服务
///
/// 通过同一业务接口提取截图与提示词，UI 无需关心底层 HTTP payload 结构。
struct UnifiedAPIRequestInspectionService: APIRequestInspectionService {
    func buildDetail(from record: APIRequestRecord) -> APIRequestDisplayDetail {
        var collected = CollectedFields()

        if let messages = decodeJSONObject(from: record.messagesJSON) {
            collected.merge(with: extractFromMessagesJSONObject(messages))
        }

        if (collected.systemPrompt.isEmpty || collected.userPrompt.isEmpty || collected.imageDataList.isEmpty),
           let requestBody = decodeJSONObject(from: record.requestBodyJSON) {
            collected.merge(with: extractFromRequestBodyJSONObject(requestBody))
        }

        return APIRequestDisplayDetail(
            systemPrompt: collected.systemPrompt.joined(separator: "\n\n"),
            userPrompt: collected.userPrompt.joined(separator: "\n\n"),
            responseText: record.responseText ?? "",
            screenshotPreviews: buildScreenshotPreviews(from: collected.imageDataList)
        )
    }
}

private extension UnifiedAPIRequestInspectionService {
    private var maxPreviewImages: Int { 2 }

    struct CollectedFields {
        var systemPrompt: [String] = []
        var userPrompt: [String] = []
        var imageDataList: [Data] = []

        mutating func merge(with other: CollectedFields) {
            if systemPrompt.isEmpty {
                systemPrompt = other.systemPrompt
            }
            if userPrompt.isEmpty {
                userPrompt = other.userPrompt
            }
            if imageDataList.isEmpty {
                imageDataList = other.imageDataList
            } else if imageDataList.count < 2 {
                for data in other.imageDataList where imageDataList.count < 2 {
                    guard !imageDataList.contains(data) else { continue }
                    imageDataList.append(data)
                }
            }
        }
    }

    func decodeJSONObject(from json: String) -> Any? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    func extractFromMessagesJSONObject(_ jsonObject: Any) -> CollectedFields {
        guard let messages = jsonObject as? [[String: Any]] else { return CollectedFields() }
        return extractFromMessagesArray(messages)
    }

    func extractFromRequestBodyJSONObject(_ jsonObject: Any) -> CollectedFields {
        guard let body = jsonObject as? [String: Any] else { return CollectedFields() }

        if let messages = body["messages"] as? [[String: Any]] {
            return extractFromMessagesArray(messages)
        }

        var fields = CollectedFields()

        if let systemInstruction = body["system_instruction"] as? [String: Any],
           let parts = systemInstruction["parts"] as? [[String: Any]] {
            collectTextAndImage(from: parts, role: "system", into: &fields)
        }

        if let contents = body["contents"] as? [[String: Any]] {
            for content in contents {
                let role = (content["role"] as? String) ?? "user"
                if let parts = content["parts"] as? [[String: Any]] {
                    collectTextAndImage(from: parts, role: role, into: &fields)
                }
            }
        }

        return fields
    }

    func extractFromMessagesArray(_ messages: [[String: Any]]) -> CollectedFields {
        var fields = CollectedFields()

        for message in messages {
            let role = (message["role"] as? String) ?? "user"
            let target: WritableKeyPath<CollectedFields, [String]> = role == "system" ? \.systemPrompt : \.userPrompt

            if let text = message["content"] as? String, !text.isEmpty {
                fields[keyPath: target].append(text)
                continue
            }

            if let parts = message["content"] as? [[String: Any]] {
                collectTextAndImage(from: parts, role: role, into: &fields)
                continue
            }

            if let content = message["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                collectTextAndImage(from: parts, role: role, into: &fields)
            }
        }

        return fields
    }

    func collectTextAndImage(from parts: [[String: Any]], role: String, into fields: inout CollectedFields) {
        let target: WritableKeyPath<CollectedFields, [String]> = role == "system" ? \.systemPrompt : \.userPrompt

        for part in parts {
            if let text = part["text"] as? String, !text.isEmpty {
                fields[keyPath: target].append(text)
            } else if let type = part["type"] as? String,
                      type == "text",
                      let text = part["text"] as? String,
                      !text.isEmpty {
                fields[keyPath: target].append(text)
            }

            if let imageURL = (part["image_url"] as? [String: Any])?["url"] as? String,
               let imageData = decodeImageData(from: imageURL) {
                appendImage(imageData, to: &fields)
            }

            if let inlineData = part["inline_data"] as? [String: Any],
               let rawBase64 = inlineData["data"] as? String,
               let imageData = decodeBase64(rawBase64) {
                appendImage(imageData, to: &fields)
            }
        }
    }

    func appendImage(_ imageData: Data, to fields: inout CollectedFields) {
        guard fields.imageDataList.count < maxPreviewImages else { return }
        guard !fields.imageDataList.contains(imageData) else { return }
        fields.imageDataList.append(imageData)
    }

    func decodeImageData(from source: String) -> Data? {
        if let base64MarkerRange = source.range(of: "base64,") {
            let base64 = String(source[base64MarkerRange.upperBound...])
            return decodeBase64(base64)
        }
        return decodeBase64(source)
    }

    func decodeBase64(_ input: String) -> Data? {
        let sanitized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        return Data(base64Encoded: sanitized)
    }

    func buildScreenshotPreviews(from imageDataList: [Data]) -> [APIRequestScreenshotPreview] {
        Array(imageDataList.prefix(maxPreviewImages).enumerated()).map { index, data in
            let title: String
            if imageDataList.count >= 2 && index == 0 {
                title = "图1（UI树标注图）"
            } else if imageDataList.count >= 2 && index == 1 {
                title = "图2（全屏）"
            } else {
                title = "图\(index + 1)"
            }
            return APIRequestScreenshotPreview(title: title, data: data)
        }
    }
}
