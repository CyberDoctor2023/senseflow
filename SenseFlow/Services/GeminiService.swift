 //
//  GeminiService.swift
//  SenseFlow
//
//  Created on 2026-01-22.
//  使用 Google 官方 GenerativeAI SDK
//

import Foundation
import GoogleGenerativeAI
import OpenTelemetryApi

/// Gemini 服务（使用 Google 官方 SDK）
class GeminiService {
    private let deterministicTemperature: Float = 0

    // MARK: - Singleton

    static let shared = GeminiService()

    // MARK: - Private Properties

    private var model: GenerativeModel?
    private let apiRequestRecorder: APIRequestRecorder

    // MARK: - Initialization

    private init(apiRequestRecorder: APIRequestRecorder = InMemoryAPIRequestRecorder.shared) {
        self.apiRequestRecorder = apiRequestRecorder
    }

    // MARK: - Public Methods

    /// 生成文本
    /// - Parameters:
    ///   - systemPrompt: 系统 Prompt
    ///   - userInput: 用户输入
    ///   - apiKey: Gemini API Key
    ///   - modelName: 模型名称
    /// - Returns: 生成的文本
    func generate(
        systemPrompt: String,
        userInput: String,
        apiKey: String,
        modelName: String = "gemini-2.5-flash"
    ) async throws -> String {
        return try await TracingService.shared.withSpan(
            name: "gemini.generate",
            kind: .client,
            attributes: [
                "gen_ai.system": .string("gemini"),
                "gen_ai.request.model": .string(modelName)
            ]
        ) { span in
            try validateAPIKey(apiKey)
            let toolName = APIRequestExecutionContext.toolName
            let endpoint = buildEndpointURL(modelName: modelName)
            let headersPayload = buildRequestHeadersPayload()
            let messagesPayload = buildTextMessagesPayload(systemPrompt: systemPrompt, userInput: userInput)
            let parametersPayload = buildRequestParametersPayload(modelName: modelName, hasImage: false)
            let requestBodyPayload = buildGeminiRequestBodyPayload(
                systemPrompt: systemPrompt,
                modelName: modelName,
                messagesPayload: messagesPayload
            )

            recordPrompt(span: span, prompt: userInput)

            do {
                let model = try createGenerativeModel(apiKey: apiKey, modelName: modelName, systemPrompt: systemPrompt)
                let response = try await model.generateContent(userInput)
                let result = try extractTextFromResponse(response)

                await recordRequestPayload(
                    toolName: toolName,
                    modelName: modelName,
                    httpMethod: "POST",
                    endpoint: endpoint,
                    headersPayload: headersPayload,
                    requestBodyPayload: requestBodyPayload,
                    messagesPayload: messagesPayload,
                    parametersPayload: parametersPayload,
                    hasImage: false,
                    imageCount: 0,
                    responseText: result,
                    error: nil
                )
                recordCompletion(span: span, completion: result)

                return result
            } catch {
                let handledError = handleGeminiError(error)
                await recordRequestPayload(
                    toolName: toolName,
                    modelName: modelName,
                    httpMethod: "POST",
                    endpoint: endpoint,
                    headersPayload: headersPayload,
                    requestBodyPayload: requestBodyPayload,
                    messagesPayload: messagesPayload,
                    parametersPayload: parametersPayload,
                    hasImage: false,
                    imageCount: 0,
                    responseText: nil,
                    error: handledError
                )
                recordError(span: span, error: error)
                throw handledError
            }
        }
    }

    /// 生成带图片的内容（Vision API）
    func generateWithImage(
        systemPrompt: String,
        userPrompt: String,
        imageBase64: String,
        apiKey: String,
        modelName: String = "gemini-2.5-flash"
    ) async throws -> String {
        return try await generateWithImages(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            imageBase64List: [imageBase64],
            apiKey: apiKey,
            modelName: modelName
        )
    }

    /// 生成带多图的内容（Vision API）
    func generateWithImages(
        systemPrompt: String,
        userPrompt: String,
        imageBase64List: [String],
        apiKey: String,
        modelName: String = "gemini-2.5-flash"
    ) async throws -> String {
        return try await TracingService.shared.withSpan(
            name: "gemini.generate_with_image",
            kind: .client,
            attributes: [
                "gen_ai.system": .string("gemini"),
                "gen_ai.request.model": .string(modelName),
                "langfuse.observation.metadata.has_image": .bool(true)
            ]
        ) { span in
            try validateAPIKey(apiKey)
            let toolName = APIRequestExecutionContext.toolName
            let endpoint = buildEndpointURL(modelName: modelName)
            let headersPayload = buildRequestHeadersPayload()

            let preparedImages = prepareVisionImages(Array(imageBase64List.prefix(2)))
            guard !preparedImages.isEmpty else {
                print("❌ Gemini: Invalid image payload, falling back to text-only mode")
                return try await generate(
                    systemPrompt: systemPrompt,
                    userInput: userPrompt,
                    apiKey: apiKey,
                    modelName: modelName
                )
            }

            recordPrompt(span: span, prompt: userPrompt)
            let messagesPayload = buildVisionMessagesPayload(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                imageBase64List: preparedImages.map(\.base64)
            )
            let parametersPayload = buildRequestParametersPayload(modelName: modelName, hasImage: true)
            let requestBodyPayload = buildGeminiRequestBodyPayload(
                systemPrompt: systemPrompt,
                modelName: modelName,
                messagesPayload: messagesPayload
            )

            do {
                let model = try createGenerativeModel(apiKey: apiKey, modelName: modelName, systemPrompt: systemPrompt)
                let response: GenerateContentResponse
                if preparedImages.count >= 2 {
                    response = try await model.generateContent(
                        userPrompt,
                        ModelContent.Part.data(mimetype: "image/jpeg", preparedImages[0].data),
                        ModelContent.Part.data(mimetype: "image/jpeg", preparedImages[1].data)
                    )
                } else {
                    response = try await model.generateContent(
                        userPrompt,
                        ModelContent.Part.data(mimetype: "image/jpeg", preparedImages[0].data)
                    )
                }
                let result = try extractTextFromResponse(response, context: "Vision")

                await recordRequestPayload(
                    toolName: toolName,
                    modelName: modelName,
                    httpMethod: "POST",
                    endpoint: endpoint,
                    headersPayload: headersPayload,
                    requestBodyPayload: requestBodyPayload,
                    messagesPayload: messagesPayload,
                    parametersPayload: parametersPayload,
                    hasImage: true,
                    imageCount: preparedImages.count,
                    responseText: result,
                    error: nil
                )
                recordCompletion(span: span, completion: result)

                return result
            } catch {
                let handledError = handleGeminiError(error, context: "Vision")
                await recordRequestPayload(
                    toolName: toolName,
                    modelName: modelName,
                    httpMethod: "POST",
                    endpoint: endpoint,
                    headersPayload: headersPayload,
                    requestBodyPayload: requestBodyPayload,
                    messagesPayload: messagesPayload,
                    parametersPayload: parametersPayload,
                    hasImage: true,
                    imageCount: preparedImages.count,
                    responseText: nil,
                    error: handledError
                )
                recordError(span: span, error: error)
                throw handledError
            }
        }
    }

    // MARK: - Private Helper Methods

    /// 记录输入到 span
    private func recordPrompt(span: Span?, prompt: String) {
        span?.setAttribute(key: "gen_ai.prompt", value: .string(prompt))
    }

    /// 记录输出到 span
    private func recordCompletion(span: Span?, completion: String) {
        span?.setAttribute(key: "gen_ai.completion", value: .string(completion))
    }

    /// 记录错误到 span
    private func recordError(span: Span?, error: Error) {
        span?.setAttribute(key: "error", value: .bool(true))
        span?.setAttribute(key: "error.message", value: .string(error.localizedDescription))
    }

    /// 验证 API Key
    private func validateAPIKey(_ apiKey: String) throws {
        guard !apiKey.isEmpty else {
            throw PromptToolError.apiError("Gemini API key is empty")
        }
    }

    /// 创建 GenerativeModel 实例
    private func createGenerativeModel(apiKey: String, modelName: String, systemPrompt: String) throws -> GenerativeModel {
        let config = GenerationConfig(temperature: deterministicTemperature)
        let systemInstruction = try ModelContent(role: "system", systemPrompt)

        return GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: config,
            safetySettings: createSafetySettings(),
            systemInstruction: systemInstruction
        )
    }

    /// 创建安全设置
    private func createSafetySettings() -> [SafetySetting] {
        return [
            SafetySetting(harmCategory: .harassment, threshold: .blockNone),
            SafetySetting(harmCategory: .hateSpeech, threshold: .blockNone),
            SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockNone),
            SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone)
        ]
    }

    /// 从响应中提取文本
    private func extractTextFromResponse(_ response: GenerateContentResponse, context: String = "") throws -> String {
        let prefix = context.isEmpty ? "Gemini" : "Gemini \(context)"

        guard !response.candidates.isEmpty else {
            print("❌ \(prefix): No candidates in response")
            if let promptFeedback = response.promptFeedback {
                print("Prompt feedback: \(promptFeedback)")
            }
            throw PromptToolError.apiError("\(prefix): No response generated (possibly blocked by safety filters)")
        }

        guard let text = response.text, !text.isEmpty else {
            print("❌ \(prefix): No text in response")
            throw PromptToolError.apiError("\(prefix): Empty response")
        }

        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// 处理 Gemini 错误
    private func handleGeminiError(_ error: Error, context: String = "") -> Error {
        let prefix = context.isEmpty ? "Gemini" : "Gemini \(context)"
        let errorString = String(describing: error)
        print("❌ \(prefix) Error: \(errorString)")

        if let message = extractErrorMessage(from: errorString) {
            return PromptToolError.apiError("\(prefix): \(message)")
        }

        return PromptToolError.apiError("\(prefix): \(error.localizedDescription)")
    }

    /// 从错误字符串中提取错误消息
    private func extractErrorMessage(from errorString: String) -> String? {
        guard let range = errorString.range(of: "message: \"([^\"]*)\"", options: .regularExpression) else {
            return nil
        }

        return String(errorString[range])
            .replacingOccurrences(of: "message: \"", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    /// 文本请求 messages 负载
    private func buildTextMessagesPayload(systemPrompt: String, userInput: String) -> [[String: Any]] {
        [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": userInput
            ]
        ]
    }

    /// 视觉请求 messages 负载
    private func buildVisionMessagesPayload(
        systemPrompt: String,
        userPrompt: String,
        imageBase64List: [String]
    ) -> [[String: Any]] {
        var userContent: [[String: Any]] = imageBase64List.map { imageBase64 in
            [
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": imageBase64
                ]
            ]
        }
        userContent.append([
            "text": userPrompt
        ])

        return [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": userContent
            ]
        ]
    }

    private func prepareVisionImages(_ imageBase64List: [String]) -> [(base64: String, data: Data)] {
        imageBase64List.compactMap { base64 in
            let sanitized = sanitizeBase64(base64)
            guard let data = Data(base64Encoded: sanitized) else { return nil }
            return (base64: sanitized, data: data)
        }
    }

    private func sanitizeBase64(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
    }

    /// 请求参数（messages 之外）
    private func buildRequestParametersPayload(modelName: String, hasImage: Bool) -> [String: Any] {
        [
            "model": modelName,
            "generation_config": [
                "temperature": deterministicTemperature
            ],
            "has_image": hasImage
        ]
    }

    /// Gemini Endpoint
    private func buildEndpointURL(modelName: String) -> String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent"
    }

    /// 请求头（敏感信息脱敏）
    private func buildRequestHeadersPayload() -> [String: String] {
        [
            "Content-Type": "application/json",
            "x-goog-api-key": "[REDACTED]",
            "X-Provider": AIServiceType.gemini.rawValue
        ]
    }

    /// 构建 Gemini 请求体
    private func buildGeminiRequestBodyPayload(
        systemPrompt: String,
        modelName: String,
        messagesPayload: [[String: Any]]
    ) -> [String: Any] {
        [
            "model": modelName,
            "system_instruction": [
                "role": "system",
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": messagesPayload.filter { message in
                (message["role"] as? String) == "user"
            }.map { message in
                [
                    "role": "user",
                    "parts": normalizeGeminiParts(from: message["content"])
                ]
            },
            "generationConfig": [
                "temperature": deterministicTemperature
            ]
        ]
    }

    /// 统一把 user content 归一化为 Gemini 的 parts 数组
    private func normalizeGeminiParts(from content: Any?) -> [[String: Any]] {
        if let text = content as? String {
            return [["text": text]]
        }

        if let items = content as? [[String: Any]] {
            return items.map { item in
                if let text = item["text"] as? String {
                    return ["text": text]
                }
                if let inlineData = item["inline_data"] as? [String: Any] {
                    return ["inline_data": inlineData]
                }
                return item
            }
        }

        return []
    }

    /// 记录真实 API 请求负载
    private func recordRequestPayload(
        toolName: String?,
        modelName: String,
        httpMethod: String,
        endpoint: String,
        headersPayload: [String: String],
        requestBodyPayload: [String: Any],
        messagesPayload: [[String: Any]],
        parametersPayload: [String: Any],
        hasImage: Bool,
        imageCount: Int,
        responseText: String?,
        error: Error?
    ) async {
        let record = APIRequestRecord(
            toolName: toolName ?? "Unknown Tool",
            serviceType: AIServiceType.gemini.displayName,
            modelName: modelName,
            httpMethod: httpMethod,
            endpoint: endpoint,
            headersJSON: serializeToPrettyJSON(headersPayload),
            requestBodyJSON: serializeToPrettyJSON(requestBodyPayload),
            messagesJSON: serializeToPrettyJSON(messagesPayload),
            parametersJSON: serializeToPrettyJSON(parametersPayload),
            hasImage: hasImage,
            imageCount: imageCount,
            responseText: responseText,
            error: error?.localizedDescription
        )

        await apiRequestRecorder.record(record)
    }

    /// 序列化为可读 JSON
    private func serializeToPrettyJSON(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}
