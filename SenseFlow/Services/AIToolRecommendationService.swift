//
//  AIToolRecommendationService.swift
//  SenseFlow
//
//  Created by Refactoring on 2026-02-14.
//  负责基于上下文推荐最合适的 Prompt Tool
//

import Foundation

enum IntentClassification: String {
    case titleInput = "title_input"
    case bodyInput = "body_input"
    case searchInput = "search_input"
    case genericText = "text_input_generic"
    case unknown = "unknown"
}

/// 唯一意图分类规则实现（Single Source of Truth）
struct IntentClassifier {
    struct Signals {
        let role: String?
        let subrole: String?
        let roleDescription: String?
        let title: String?
        let description: String?
        let placeholder: String?
        let valuePreview: String?
        let characterCount: Int?
        let frameHeight: Double?
        let neighborhoodSnapshot: String?
        let uiRoleSnapshot: String?
        let focusedSnapshotWindow: String?
        let uiRoleReferences: [SmartUIRoleReference]?
        let cursorNeighborhoodOCRText: String?
    }

    static let titleKeywords = ["标题", "title", "headline", "subject", "题目"]
    static let bodyKeywords = ["正文", "内容", "body", "content", "文案", "caption", "描述", "成稿", "article"]
    static let searchKeywords = ["搜索", "search", "find", "query", "检索"]

    private static let searchRoleKeywords = ["searchfield", "searchbox", "search box"]
    private static let singleLineRoleKeywords = ["textfield", "textbox"]
    private static let multiLineRoleKeywords = ["textarea", "text area"]
    private static let genericTextRoleKeywords = ["textfield", "textarea", "textbox", "webarea", "text area"]

    func classify(
        focusedElement: SmartFocusedElementContext?,
        cursorNeighborhoodOCRText: String?
    ) -> IntentClassification {
        guard let focusedElement else {
            return classify(
                signals: Signals(
                    role: nil,
                    subrole: nil,
                    roleDescription: nil,
                    title: nil,
                    description: nil,
                    placeholder: nil,
                    valuePreview: nil,
                    characterCount: nil,
                    frameHeight: nil,
                    neighborhoodSnapshot: nil,
                    uiRoleSnapshot: nil,
                    focusedSnapshotWindow: nil,
                    uiRoleReferences: nil,
                    cursorNeighborhoodOCRText: cursorNeighborhoodOCRText
                )
            )
        }

        return classify(
            signals: Signals(
                role: focusedElement.role,
                subrole: focusedElement.subrole,
                roleDescription: focusedElement.roleDescription,
                title: focusedElement.title,
                description: focusedElement.description,
                placeholder: focusedElement.placeholder,
                valuePreview: focusedElement.valuePreview,
                characterCount: focusedElement.characterCount,
                frameHeight: focusedElement.frameHeight,
                neighborhoodSnapshot: focusedElement.neighborhoodSnapshot,
                uiRoleSnapshot: focusedElement.uiRoleSnapshot,
                focusedSnapshotWindow: focusedElement.focusedSnapshotWindow,
                uiRoleReferences: focusedElement.uiRoleReferences,
                cursorNeighborhoodOCRText: cursorNeighborhoodOCRText
            )
        )
    }

    func classify(signals: Signals) -> IntentClassification {
        let roleRaw = [
            signals.role,
            signals.subrole,
            signals.roleDescription
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        let strongSignals = [
            compact(signals.title, maxLength: 180),
            compact(signals.placeholder, maxLength: 180),
            compact(signals.description, maxLength: 180),
            compact(signals.focusedSnapshotWindow, maxLength: 260),
            compact(signals.cursorNeighborhoodOCRText, maxLength: 260)
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        let weakSignals = [
            compact(signals.valuePreview, maxLength: 120),
            compact(signals.neighborhoodSnapshot, maxLength: 220),
            compact(signals.uiRoleSnapshot, maxLength: 220),
            signals.uiRoleReferences?
                .prefix(10)
                .map { "\($0.role) \($0.name ?? "")" }
                .joined(separator: " ")
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        let hasAnySignal =
            !roleRaw.isEmpty ||
            !strongSignals.isEmpty ||
            !weakSignals.isEmpty ||
            signals.characterCount != nil ||
            signals.frameHeight != nil
        if !hasAnySignal {
            return .unknown
        }

        let hasNewlineValue = signals.valuePreview?.contains("\n") == true
        let searchText = [signals.title, signals.placeholder, signals.description]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let titleText = [signals.title, signals.placeholder, signals.description, signals.focusedSnapshotWindow]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let isSearchField = containsAny(Self.searchRoleKeywords, in: roleRaw) || containsAny(Self.searchKeywords, in: searchText)
        let isSingleLineTextField = containsAny(Self.singleLineRoleKeywords, in: roleRaw)
        let isMultiLineTextField = containsAny(Self.multiLineRoleKeywords, in: roleRaw)
        let hasTitleAnchor = containsAny(Self.titleKeywords, in: titleText)

        // 结构优先硬约束：单行输入框不会被正文词反超
        if isSearchField {
            return .searchInput
        }
        if hasTitleAnchor && !hasNewlineValue {
            if let frameHeight = signals.frameHeight, frameHeight > 0, frameHeight <= 82 {
                return .titleInput
            }
            if let characterCount = signals.characterCount, characterCount > 0, characterCount <= 90 {
                return .titleInput
            }
        }
        if isSingleLineTextField && !hasNewlineValue {
            return .titleInput
        }
        if isMultiLineTextField || hasNewlineValue {
            return .bodyInput
        }

        var titleScore = 0
        var bodyScore = 0
        var searchScore = 0

        titleScore += scoreKeywordMatch(Self.titleKeywords, in: strongSignals, weight: 6)
        titleScore += scoreKeywordMatch(Self.titleKeywords, in: weakSignals, weight: 1)

        bodyScore += scoreKeywordMatch(Self.bodyKeywords, in: strongSignals, weight: 6)
        bodyScore += scoreKeywordMatch(Self.bodyKeywords, in: weakSignals, weight: 1)

        searchScore += scoreKeywordMatch(Self.searchKeywords, in: strongSignals, weight: 6)
        searchScore += scoreKeywordMatch(Self.searchKeywords, in: weakSignals, weight: 1)

        if containsAny(Self.searchRoleKeywords, in: roleRaw) {
            searchScore += 6
        }
        if containsAny(Self.multiLineRoleKeywords, in: roleRaw) {
            bodyScore += 4
        }
        if containsAny(Self.singleLineRoleKeywords, in: roleRaw) {
            titleScore += 4
        }

        if let characterCount = signals.characterCount {
            if characterCount >= 80 {
                bodyScore += 2
            } else if characterCount > 0, characterCount <= 40 {
                titleScore += 2
            }
        }

        if let frameHeight = signals.frameHeight {
            if frameHeight >= 110 {
                bodyScore += 3
            } else if frameHeight > 0, frameHeight <= 68 {
                titleScore += 3
            }
        }

        if titleScore >= max(bodyScore, searchScore) + 2 && titleScore >= 4 {
            return .titleInput
        }
        if bodyScore >= max(titleScore, searchScore) + 2 && bodyScore >= 4 {
            return .bodyInput
        }
        if searchScore >= max(titleScore, bodyScore) + 2 && searchScore >= 4 {
            return .searchInput
        }

        if containsAny(Self.genericTextRoleKeywords, in: roleRaw) {
            return .genericText
        }
        return .unknown
    }

    private func containsAny(_ keywords: [String], in text: String) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }

    private func scoreKeywordMatch(_ keywords: [String], in text: String, weight: Int) -> Int {
        guard !text.isEmpty else { return 0 }
        let matches = keywords.filter { text.contains($0) }.count
        guard matches > 0 else { return 0 }
        return weight + max(0, matches - 1)
    }

    private func compact(_ text: String?, maxLength: Int) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return String(text.prefix(maxLength))
    }
}

/// AI 工具推荐服务
/// 职责：分析用户上下文并推荐最合适的 Prompt Tool
class AIToolRecommendationService {
    // MARK: - Dependencies

    private let aiClient: SmartRecommendationAIClient
    private let intentClassifier: IntentClassifier

    // MARK: - Initialization

    init(
        aiClient: SmartRecommendationAIClient = AIService.shared,
        intentClassifier: IntentClassifier = IntentClassifier()
    ) {
        self.aiClient = aiClient
        self.intentClassifier = intentClassifier
    }

    // MARK: - Public Methods

    /// 推荐最合适的 Prompt Tool
    /// - Parameters:
    ///   - context: 当前用户上下文（应用、剪贴板、截图）
    ///   - availableTools: 可用的 prompt tools 列表
    /// - Returns: SmartRecommendation 推荐结果
    /// - Throws: PromptToolError 如果推荐失败
    func recommendTool(context: SmartContext, availableTools: [PromptTool]) async throws -> SmartRecommendation {
        try await APIRequestExecutionContext.$toolName.withValue("Smart AI Recommendation") {
            let startTime = Date()
            let systemPrompt = buildRecommendationSystemPrompt()
            let intent: IntentClassification = .unknown
            let scopedTools: [PromptTool] = availableTools

            if let deterministic = deterministicRecommendationIfPossible(
                intent: intent,
                scopedTools: scopedTools,
                startTime: startTime
            ) {
                return deterministic
            }

            let userPrompt = buildRecommendationUserPrompt(
                context: context,
                tools: scopedTools
            )

            let response: String
            if shouldUseVisionAPI(context: context) {
                response = try await generateWithVision(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    context: context
                )
            } else {
                response = try await aiClient.generate(
                    systemPrompt: systemPrompt,
                    userInput: userPrompt
                )
            }

            let recommendation = try buildRecommendation(
                from: response,
                availableTools: scopedTools,
                startTime: startTime
            )
            return recommendation
        }
    }

    // MARK: - Private Methods

    /// 判断是否应该使用 Vision API
    private func shouldUseVisionAPI(context: SmartContext) -> Bool {
        return context.screenshots.hasAny && !context.isLightweightMode
    }

    /// 使用 Vision API 生成响应
    private func generateWithVision(
        systemPrompt: String,
        userPrompt: String,
        context: SmartContext
    ) async throws -> String {
        return try await aiClient.generateSmartRecommendationWithScreenshots(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            screenshots: context.screenshots
        )
    }

    /// 构建推荐系统 Prompt
    private func buildRecommendationSystemPrompt() -> String {
        // 从 UserDefaults 读取用户自定义的系统提示词
        let customPrompt = UserDefaults.standard.string(forKey: "smartAISystemPrompt")
        return customPrompt ?? SettingsModel.defaultSmartAISystemPrompt
    }

    /// 构建推荐用户 Prompt
    private func buildRecommendationUserPrompt(
        context: SmartContext,
        tools: [PromptTool]
    ) -> String {
        let screenshotScope = screenshotScope(for: context)

        let toolsJSON = buildToolsJSON(tools)
        let screenshotAttentionPolicy = buildScreenshotAttentionPolicy(screenshotScope: screenshotScope)
        return """
        Context:
        - Application: \(context.applicationName)
        - Bundle ID: \(context.bundleID)
        - Screenshot Scope: \(screenshotScope)

        Screenshot Attention Policy:
        \(screenshotAttentionPolicy)

        Available Tools:
        \(toolsJSON)

        Decision Rules:
        - Decide primarily from screenshot evidence.
        - All intent judgments must expand outward from the cursor/caret-centered region.
        - First locate cursor/caret position in screenshot (explicit marker or native pointer/caret), then identify the nearest editable/control region.
        - Read tight local text around cursor/caret first (nearest control text before any other text).
        - Give higher weight to cursor-near text as local evidence, then combine with nearby controls and overall page context.
        - Avoid deciding only from page title/header/footer CTA (for example, "一键排版") when cursor-near evidence suggests otherwise.
        - Application/bundle and tool-name similarity are weak priors; never use them as primary evidence.
        - Ignore previous runs/history; decide this turn independently.
        - If ambiguous, pick the safest generic tool.
        - Output JSON must include tool_id/tool_name/reason/confidence.

        Which tool is most suitable for this context?
        """
    }

    private func buildScreenshotAttentionPolicy(screenshotScope: String) -> String {
        switch screenshotScope {
        case "annotated_ui_tree":
            return """
            1. Use the annotated UI tree screenshot as primary evidence.
            2. Locate cursor/caret first (explicit marker or native pointer/caret).
            3. Read text in the tight cursor-neighborhood first (nearest control text).
            4. Inspect controls around that cursor-located region.
            5. Then verify nearest editable control.
            6. Ignore page title/footer CTA unless cursor is on them.
            """
        case "annotated_ui_tree + full_screen":
            return """
            1. Use the annotated UI tree screenshot as primary evidence.
            2. Locate cursor/caret first (explicit marker or native pointer/caret).
            3. Read text in the tight cursor-neighborhood first (nearest control text).
            4. Inspect controls around that cursor-located region before global cues.
            5. Use full-screen screenshot as secondary global context.
            6. If conflict exists, trust local screenshot evidence around cursor first.
            7. Ignore page title/footer CTA unless cursor is on them.
            """
        case "full_screen":
            return """
            1. Locate cursor/caret first (explicit marker or native pointer/caret).
            2. Read text in the tight cursor-neighborhood first (nearest control text).
            3. Focus on the cursor-located region and nearest editable control.
            4. Use other regions only as secondary context.
            5. Ignore page title/footer CTA unless cursor is on them.
            """
        default:
            return "No screenshot provided."
        }
    }

    private func screenshotScope(for context: SmartContext) -> String {
        if context.screenshots.focusedApp != nil && context.screenshots.fullScreen != nil {
            return "annotated_ui_tree + full_screen"
        }
        if context.screenshots.fullScreen != nil {
            return "full_screen"
        }
        if context.screenshots.focusedApp != nil {
            return "annotated_ui_tree"
        }
        return "none"
    }

    private func scopedTools(for intent: IntentClassification, from tools: [PromptTool]) -> [PromptTool] {
        switch intent {
        case .titleInput:
            let preferred = tools.filter { isTitleTool($0) }
            if !preferred.isEmpty {
                return preferred
            }
            let nonBody = tools.filter { !isBodyTool($0) }
            if !nonBody.isEmpty {
                return nonBody
            }
            return tools
        case .bodyInput:
            let preferred = tools.filter { isBodyTool($0) }
            if !preferred.isEmpty {
                return preferred
            }
            let nonTitle = tools.filter { !isTitleTool($0) }
            if !nonTitle.isEmpty {
                return nonTitle
            }
            return tools
        case .searchInput:
            let preferred = tools.filter { isSearchTool($0) }
            if !preferred.isEmpty {
                return preferred
            }
            let nonBodyAndTitle = tools.filter { !isBodyTool($0) && !isTitleTool($0) }
            if !nonBodyAndTitle.isEmpty {
                return nonBodyAndTitle
            }
            return tools
        case .genericText, .unknown:
            return tools
        }
    }

    private func deterministicRecommendationIfPossible(
        intent: IntentClassification,
        scopedTools: [PromptTool],
        startTime: Date
    ) -> SmartRecommendation? {
        guard scopedTools.count == 1, let tool = scopedTools.first else {
            return nil
        }

        let reason: String
        switch intent {
        case .titleInput:
            reason = "结构化意图判定为标题输入，候选唯一，直接执行以避免漂移"
        case .bodyInput:
            reason = "结构化意图判定为正文输入，候选唯一，直接执行以避免漂移"
        case .searchInput:
            reason = "结构化意图判定为搜索输入，候选唯一，直接执行以避免漂移"
        case .genericText, .unknown:
            reason = "候选工具唯一，直接执行"
        }

        return SmartRecommendation(
            toolID: tool.id,
            toolName: tool.name,
            reason: reason,
            confidence: 0.96,
            responseTime: Date().timeIntervalSince(startTime)
        )
    }

    private func resolveIntent(context: SmartContext) -> IntentClassification {
        let inferred = intentClassifier.classify(
            focusedElement: context.focusedElement,
            cursorNeighborhoodOCRText: context.cursorNeighborhoodOCRText
        )
        if inferred != .unknown {
            return inferred
        }

        guard let hintRaw = context.focusedElement?.intentHint,
              let hintIntent = IntentClassification(rawValue: hintRaw),
              hintIntent != .unknown else {
            return inferred
        }
        return hintIntent
    }

    private func enforceIntentConsistency(
        recommendation: SmartRecommendation,
        intent: IntentClassification,
        scopedTools: [PromptTool],
        startTime: Date
    ) -> SmartRecommendation {
        guard let selectedTool = scopedTools.first(where: { $0.id == recommendation.toolID }),
              isIntentConflict(intent: intent, tool: selectedTool),
              let fallbackTool = firstCompatibleTool(for: intent, in: scopedTools, excluding: selectedTool.id) else {
            return recommendation
        }

        let reason = "当前焦点意图为 \(intent.rawValue)，已忽略冲突候选并回退到一致工具"
        return SmartRecommendation(
            toolID: fallbackTool.id,
            toolName: fallbackTool.name,
            reason: reason,
            confidence: min(recommendation.confidence, 0.78),
            responseTime: Date().timeIntervalSince(startTime)
        )
    }

    private func isIntentConflict(intent: IntentClassification, tool: PromptTool) -> Bool {
        switch intent {
        case .titleInput:
            return isBodyTool(tool) && !isTitleTool(tool)
        case .bodyInput:
            return isTitleTool(tool) && !isBodyTool(tool)
        case .searchInput:
            return (isTitleTool(tool) || isBodyTool(tool)) && !isSearchTool(tool)
        case .genericText, .unknown:
            return false
        }
    }

    private func firstCompatibleTool(
        for intent: IntentClassification,
        in tools: [PromptTool],
        excluding toolID: UUID
    ) -> PromptTool? {
        let candidates = tools.filter { $0.id != toolID }
        guard !candidates.isEmpty else { return nil }

        switch intent {
        case .titleInput:
            return candidates.first(where: isTitleTool) ??
                candidates.first(where: { !isBodyTool($0) })
        case .bodyInput:
            return candidates.first(where: isBodyTool) ??
                candidates.first(where: { !isTitleTool($0) })
        case .searchInput:
            return candidates.first(where: isSearchTool) ??
                candidates.first(where: { !isTitleTool($0) && !isBodyTool($0) })
        case .genericText, .unknown:
            return nil
        }
    }

    private func isTitleTool(_ tool: PromptTool) -> Bool {
        effectiveCapabilities(of: tool).contains(.title)
    }

    private func isBodyTool(_ tool: PromptTool) -> Bool {
        effectiveCapabilities(of: tool).contains(.body)
    }

    private func isSearchTool(_ tool: PromptTool) -> Bool {
        effectiveCapabilities(of: tool).contains(.search)
    }

    private func effectiveCapabilities(of tool: PromptTool) -> Set<PromptToolCapability> {
        let explicit = Set(tool.capabilities)
        if !explicit.isEmpty {
            return explicit
        }
        return Set(PromptToolCapability.infer(fromName: tool.name, prompt: tool.prompt))
    }

    private func buildToolsJSON(_ tools: [PromptTool]) -> String {
        let payload: [[String: Any]] = tools
            .sorted {
                let lhs = $0.name.localizedCaseInsensitiveCompare($1.name)
                if lhs == .orderedSame {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return lhs == .orderedAscending
            }
            .map { tool in
            return [
                "id": tool.id.uuidString,
                "name": tool.name
            ]
        }
        return serializePrettyJSON(payload)
    }

    private func buildIntentSignalsJSON(
        context: SmartContext,
        intent: IntentClassification,
        screenshotScope: String
    ) -> String {
        let focused = context.focusedElement

        let framePayload: [String: Any] = [
            "x": focused?.frameX ?? -1,
            "y": focused?.frameY ?? -1,
            "width": focused?.frameWidth ?? -1,
            "height": focused?.frameHeight ?? -1
        ]

        var focusedElementPayload: [String: Any] = [:]
        focusedElementPayload["role"] = focused?.role ?? "unknown"
        focusedElementPayload["subrole"] = focused?.subrole ?? "unknown"
        focusedElementPayload["role_description"] = focused?.roleDescription ?? "unknown"
        focusedElementPayload["title"] = focused?.title ?? "unknown"
        focusedElementPayload["description"] = focused?.description ?? "unknown"
        focusedElementPayload["placeholder"] = focused?.placeholder ?? "unknown"
        focusedElementPayload["identifier"] = focused?.identifier ?? "unknown"
        focusedElementPayload["value_preview"] = focused?.valuePreview ?? "unknown"
        focusedElementPayload["character_count"] = focused?.characterCount ?? -1
        focusedElementPayload["intent_hint"] = focused?.intentHint ?? "unknown"
        focusedElementPayload["frame"] = framePayload

        let payload: [String: Any] = [
            "inferred_intent": intent.rawValue,
            "intent_rule_source": "IntentClassifier.v1",
            "decision_policy": [
                "structure_signals_priority": "hard_constraint",
                "cursor_and_focused_ui_priority": "high",
                "app_metadata_priority": "low_auxiliary",
                "snapshot_text_priority": "low_auxiliary"
            ],
            "app": [
                "name": context.applicationName,
                "bundle_id": context.bundleID
            ],
            "screenshot_scope": screenshotScope,
            "focused_element": focusedElementPayload,
            "cursor_neighborhood_ocr_text": compactSignalText(context.cursorNeighborhoodOCRText, maxLength: 320) ?? "unknown"
        ]

        return serializePrettyJSON(payload)
    }

    private func compactSignalText(_ text: String?, maxLength: Int) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return String(text.prefix(maxLength))
    }

    private func serializePrettyJSON(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    /// 构建推荐结果
    private func buildRecommendation(
        from response: String,
        availableTools: [PromptTool],
        startTime: Date
    ) throws -> SmartRecommendation {
        let recommendationData = try parseRecommendationResponse(response)

        guard let toolID = UUID(uuidString: recommendationData.tool_id),
              let tool = availableTools.first(where: { $0.id == toolID }) else {
            throw PromptToolError.apiError("Recommended tool ID not found: \(recommendationData.tool_id)")
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

    /// 解析 AI 响应为 SmartRecommendationResponse
    private func parseRecommendationResponse(_ response: String) throws -> SmartRecommendationResponse {
        // 提取 JSON（移除 markdown 包装）
        let jsonString = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            throw PromptToolError.apiError("Failed to encode response as UTF-8")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(SmartRecommendationResponse.self, from: data)
        } catch {
            throw PromptToolError.apiError("Failed to parse AI response: \(error.localizedDescription)")
        }
    }

}
