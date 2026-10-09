//
//  InMemoryAPIRequestRecorder.swift
//  SenseFlow
//
//  Created on 2026-02-26.
//

import Foundation
import Combine

/// Bounded diagnostic records; originals and generated tool results are stored elsewhere.
@MainActor final class InMemoryAPIRequestRecorder: ObservableObject, ObservableAPIRequestRecorder {
    static let shared = InMemoryAPIRequestRecorder()
    @Published private(set) var lastRecord: APIRequestRecord?
    @Published private(set) var allRecords: [APIRequestRecord] = []
    private let maxRecords: Int
    private let maxBytes: Int
    private var recordCosts: [Int] = []
    private(set) var retainedBytes = 0

    /// Limits apply to diagnostic payloads, including duplicated screenshot base64.
    init(maxRecords: Int = 50, maxBytes: Int = 32 * 1024 * 1024) {
        self.maxRecords = max(0, maxRecords)
        self.maxBytes = max(0, maxBytes)
    }

    func record(_ record: APIRequestRecord) async {
        let cost = payloadCost(record)
        guard maxRecords > 0, cost <= maxBytes else { return }
        while !allRecords.isEmpty && (allRecords.count >= maxRecords || retainedBytes > maxBytes - cost) {
            allRecords.removeLast()
            retainedBytes -= recordCosts.removeLast()
        }
        allRecords.insert(record, at: 0)
        recordCosts.insert(cost, at: 0)
        retainedBytes += cost
        lastRecord = record
    }

    func getLastRecord() async -> APIRequestRecord? { lastRecord }
    func getAllRecords(limit: Int? = nil) async -> [APIRequestRecord] {
        if let limit { return Array(allRecords.prefix(max(0, limit))) }
        return allRecords
    }
    func clearAll() async {
        allRecords.removeAll()
        recordCosts.removeAll()
        retainedBytes = 0
        lastRecord = nil
    }

    private func payloadCost(_ record: APIRequestRecord) -> Int {
        [record.toolName, record.serviceType, record.modelName, record.httpMethod, record.endpoint,
         record.headersJSON, record.requestBodyJSON, record.messagesJSON, record.parametersJSON,
         record.responseText, record.error].reduce(0) { $0 + ($1?.utf8.count ?? 0) }
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
