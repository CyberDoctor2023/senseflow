//
//  AnalyzeAndRecommendTests.swift
//  SenseFlowTests
//
//  Created on 2026-02-03.
//

import XCTest
@testable import SenseFlow

final class AnalyzeAndRecommendTests: XCTestCase {

    // MARK: - Properties

    var mockContextCollector: MockContextCollector!
    var mockToolRepository: MockPromptToolRepository!
    var mockAIService: MockAIService!
    var mockExecuteTool: MockExecutePromptTool!
    var mockNotification: MockNotificationService!
    var mockLiveOverlaySessionController: MockLiveOverlaySessionController!
    var sut: AnalyzeAndRecommend!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        mockContextCollector = MockContextCollector()
        mockToolRepository = MockPromptToolRepository()
        mockAIService = MockAIService()
        mockExecuteTool = MockExecutePromptTool()
        mockNotification = MockNotificationService()
        mockLiveOverlaySessionController = MockLiveOverlaySessionController()

        sut = AnalyzeAndRecommend(
            contextCollector: mockContextCollector,
            toolRepository: mockToolRepository,
            aiService: mockAIService,
            executeToolUseCase: mockExecuteTool,
            notificationService: mockNotification,
            liveOverlaySessionController: mockLiveOverlaySessionController
        )
    }

    override func tearDown() {
        sut = nil
        mockNotification = nil
        mockExecuteTool = nil
        mockAIService = nil
        mockToolRepository = nil
        mockContextCollector = nil
        mockLiveOverlaySessionController = nil

        super.tearDown()
    }

    // MARK: - Tests: analyze() - Success Cases

    func test_analyze_withValidContext_returnsRecommendation() async throws {
        // Arrange
        let tool = PromptTool(name: "Test Tool", prompt: "Test")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.8,
            reasoning: "Test reasoning"
        )

        // Act
        let result = try await sut.analyze()

        // Assert
        XCTAssertEqual(result.toolID, tool.id, "应该返回推荐的工具 ID")
        XCTAssertEqual(result.confidence, 0.8, "应该返回正确的置信度")
        XCTAssertEqual(mockContextCollector.collectCallCount, 1, "应该收集上下文一次")
        XCTAssertEqual(mockAIService.recommendToolCallCount, 1, "应该调用 AI 推荐一次")
    }

    func test_analyze_bindsOverlaySessionLifecycle() async throws {
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]
        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.8,
            reasoning: "ok"
        )

        let endExpectation = expectation(description: "overlay session ended")
        await MainActor.run {
            mockLiveOverlaySessionController.onEnd = { endExpectation.fulfill() }
        }

        _ = try await sut.analyze()
        await fulfillment(of: [endExpectation], timeout: 1.0)

        let beginCount = await MainActor.run { mockLiveOverlaySessionController.beginCount }
        let endCount = await MainActor.run { mockLiveOverlaySessionController.endCount }
        XCTAssertEqual(beginCount, 1)
        XCTAssertEqual(endCount, 1)
    }

    func test_analyze_withHighConfidence_passesValidation() async throws {
        // Arrange
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.95, // 高置信度
            reasoning: "Very confident"
        )

        // Act
        let result = try await sut.analyze()

        // Assert
        XCTAssertEqual(result.confidence, 0.95)
    }

    func test_analyze_withMinimumConfidence_passesValidation() async throws {
        // Arrange
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.6, // 最低阈值
            reasoning: "Minimum confidence"
        )

        // Act
        let result = try await sut.analyze()

        // Assert
        XCTAssertEqual(result.confidence, 0.6)
    }

    // MARK: - Tests: analyze() - Error Cases

    func test_analyze_withNoTools_throwsError() async {
        // Arrange
        mockToolRepository.toolsToReturn = [] // 无工具

        // Act & Assert
        do {
            _ = try await sut.analyze()
            XCTFail("应该抛出错误")
        } catch let error as SmartAIError {
            if case .noToolsAvailable = error {
                // 正确的错误类型
            } else {
                XCTFail("错误类型不正确")
            }
        } catch {
            XCTFail("错误类型不正确")
        }
    }

    func test_analyze_withLowConfidence_throwsError() async {
        // Arrange
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.5, // 低于阈值 0.6
            reasoning: "Low confidence"
        )

        // Act & Assert
        do {
            _ = try await sut.analyze()
            XCTFail("应该抛出低置信度错误")
        } catch let error as SmartAIError {
            if case .lowConfidence(let confidence) = error {
                XCTAssertEqual(confidence, 0.5, "应该包含实际置信度")
            } else {
                XCTFail("错误类型不正确")
            }
        } catch {
            XCTFail("错误类型不正确")
        }
    }

    func test_analyze_withContextCollectionError_throwsError() async {
        // Arrange
        mockContextCollector.shouldThrowError = true
        mockContextCollector.errorToThrow = MockError.generic

        // Act & Assert
        do {
            _ = try await sut.analyze()
            XCTFail("应该抛出错误")
        } catch {
            // 错误应该被传播
            XCTAssertTrue(error is MockError)
        }
    }

    func test_analyze_withAIServiceError_throwsError() async {
        // Arrange
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.shouldThrowError = true
        mockAIService.errorToThrow = MockError.generic

        // Act & Assert
        do {
            _ = try await sut.analyze()
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertTrue(error is MockError)
        }
    }

    // MARK: - Tests: analyzeAndExecute() - Success Cases

    func test_analyzeAndExecute_withValidRecommendation_executesTool() async throws {
        // Arrange
        let tool = PromptTool(name: "Translation Tool", prompt: "Translate")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.8,
            reasoning: "Good match"
        )

        // Act
        try await sut.analyzeAndExecute()

        // Assert
        XCTAssertEqual(mockExecuteTool.executeCallCount, 1, "应该执行工具一次")
        XCTAssertEqual(mockExecuteTool.lastExecutedTool?.id, tool.id, "应该执行推荐的工具")
    }

    func test_analyzeAndExecute_bindsOverlaySessionLifecycle() async throws {
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]
        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.8,
            reasoning: "ok"
        )

        let endExpectation = expectation(description: "overlay session ended")
        await MainActor.run {
            mockLiveOverlaySessionController.onEnd = { endExpectation.fulfill() }
        }

        try await sut.analyzeAndExecute()
        await fulfillment(of: [endExpectation], timeout: 1.0)

        let beginCount = await MainActor.run { mockLiveOverlaySessionController.beginCount }
        let endCount = await MainActor.run { mockLiveOverlaySessionController.endCount }
        XCTAssertEqual(beginCount, 1)
        XCTAssertEqual(endCount, 1)
    }

    func test_analyzeAndExecute_showsProgressNotifications() async throws {
        // Arrange
        let tool = PromptTool(name: "Test Tool", prompt: "Test")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.8,
            reasoning: "Test"
        )

        // Act
        try await sut.analyzeAndExecute()

        // Assert
        XCTAssertEqual(mockNotification.showInProgressCallCount, 2, "应该显示两次进度通知")
        XCTAssertTrue(mockNotification.lastInProgressBody?.contains("分析上下文") ?? false, "第一次通知应该是分析")
        XCTAssertTrue(mockNotification.lastInProgressBody?.contains("Test Tool") ?? false, "第二次通知应该包含工具名")
    }

    func test_analyzeAndExecute_withCompleteFlow_callsAllComponents() async throws {
        // Arrange
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.7,
            reasoning: "Match"
        )

        // Act
        try await sut.analyzeAndExecute()

        // Assert
        XCTAssertEqual(mockContextCollector.collectCallCount, 1, "应该收集上下文")
        XCTAssertEqual(mockAIService.recommendToolCallCount, 1, "应该调用 AI 推荐")
        XCTAssertEqual(mockExecuteTool.executeCallCount, 1, "应该执行工具")
        XCTAssertEqual(mockNotification.showInProgressCallCount, 2, "应该显示通知")
    }

    // MARK: - Tests: analyzeAndExecute() - Error Cases

    func test_analyzeAndExecute_withToolNotFound_throwsError() async {
        // Arrange
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]

        // 推荐一个不存在的工具
        let nonExistentID = UUID()
        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: nonExistentID,
            confidence: 0.8,
            reasoning: "Test"
        )

        // Act & Assert
        do {
            try await sut.analyzeAndExecute()
            XCTFail("应该抛出工具未找到错误")
        } catch let error as SmartAIError {
            if case .toolNotFound = error {
                // 正确的错误类型
            } else {
                XCTFail("错误类型不正确")
            }
        } catch {
            XCTFail("错误类型不正确")
        }
    }

    func test_analyzeAndExecute_withLowConfidence_doesNotExecute() async {
        // Arrange
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.3, // 低置信度
            reasoning: "Not sure"
        )

        // Act
        do {
            try await sut.analyzeAndExecute()
            XCTFail("应该抛出低置信度错误")
        } catch {
            // 预期错误
        }

        // Assert
        XCTAssertEqual(mockExecuteTool.executeCallCount, 0, "低置信度时不应该执行工具")
    }

    func test_analyzeAndExecute_withExecutionError_throwsError() async {
        // Arrange
        let tool = PromptTool(name: "Tool", prompt: "Prompt")
        mockToolRepository.toolsToReturn = [tool]

        mockAIService.recommendationToReturn = SmartRecommendation(
            toolID: tool.id,
            confidence: 0.8,
            reasoning: "Test"
        )

        mockExecuteTool.shouldThrowError = true
        mockExecuteTool.errorToThrow = MockError.generic

        // Act & Assert
        do {
            try await sut.analyzeAndExecute()
            XCTFail("应该抛出执行错误")
        } catch {
            XCTAssertTrue(error is MockError, "应该传播执行错误")
        }
    }
}

@MainActor
final class MockLiveOverlaySessionController: SmartAILiveOverlaySessionControlling {
    private(set) var beginCount = 0
    private(set) var endCount = 0
    var onEnd: (() -> Void)?

    func beginSession() {
        beginCount += 1
    }

    func endSession() {
        endCount += 1
        onEnd?()
    }
}

final class IntentClassifierTests: XCTestCase {
    private var sut: IntentClassifier!

    override func setUp() {
        super.setUp()
        sut = IntentClassifier()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_classify_xiaohongshuTitleField_withBodyNoise_returnsTitleInput() {
        let signals = makeSignals(
            role: "AXTextField",
            title: "标题",
            description: "正文内容编辑区域在下方",
            placeholder: "填写标题会有更多赞哦",
            valuePreview: "春日通勤穿搭",
            characterCount: 14,
            frameHeight: 42,
            neighborhoodSnapshot: "附近出现大量词：正文 内容 文案 成稿",
            uiRoleSnapshot: "- textarea \"正文内容\"\n- textfield \"标题\" [focused=true]",
            focusedSnapshotWindow: "- textfield \"标题\" [focused=true]"
        )

        let result = sut.classify(signals: signals)

        XCTAssertEqual(result, .titleInput, "单行标题框不应被正文关键词反超")
    }

    func test_classify_xiaohongshuBodyEditor_returnsBodyInput() {
        let signals = makeSignals(
            role: "AXTextArea",
            title: "正文",
            description: "输入正文内容",
            placeholder: "分享你的真实体验",
            valuePreview: "第一行\n第二行",
            characterCount: 128,
            frameHeight: 180,
            neighborhoodSnapshot: "标题在上方，正文在当前焦点",
            uiRoleSnapshot: "- textarea \"正文\" [focused=true]"
        )

        let result = sut.classify(signals: signals)

        XCTAssertEqual(result, .bodyInput)
    }

    func test_classify_searchBox_returnsSearchInput() {
        let signals = makeSignals(
            role: "AXSearchField",
            placeholder: "搜索小红书内容",
            frameHeight: 34,
            uiRoleSnapshot: "- searchfield \"搜索\" [focused=true]"
        )

        let result = sut.classify(signals: signals)

        XCTAssertEqual(result, .searchInput)
    }

    func test_classify_webAreaWithTitleAnchor_andShortFrame_returnsTitleInput() {
        let signals = makeSignals(
            role: "AXWebArea",
            title: "标题",
            placeholder: "请输入标题",
            valuePreview: "短句",
            characterCount: 2,
            frameHeight: 46
        )

        let result = sut.classify(signals: signals)

        XCTAssertEqual(result, .titleInput)
    }

    func test_classify_nonTextRole_returnsUnknown() {
        let signals = makeSignals(
            role: "AXButton",
            title: "发布",
            frameHeight: 30
        )

        let result = sut.classify(signals: signals)

        XCTAssertEqual(result, .unknown)
    }

    func test_classify_sameXiaohongshuTitleScenario_isStableAcross20Runs() {
        let signals = makeSignals(
            role: "AXTextField",
            title: "标题",
            description: "正文区词汇噪音：正文 内容 文案",
            placeholder: "填写标题会有更多赞哦",
            valuePreview: "周末citywalk",
            characterCount: 10,
            frameHeight: 44,
            neighborhoodSnapshot: "正文 正文 内容 内容",
            uiRoleSnapshot: "- textarea \"正文\"\n- textfield \"标题\" [focused=true]",
            focusedSnapshotWindow: "- textfield \"标题\" [focused=true]"
        )

        let baseline = sut.classify(signals: signals)
        XCTAssertEqual(baseline, .titleInput)

        for _ in 0..<20 {
            XCTAssertEqual(sut.classify(signals: signals), baseline)
        }
    }

    func test_classify_withoutFocusedElement_withCursorOCRTitleKeyword_returnsTitleInput() {
        let result = sut.classify(
            focusedElement: nil,
            cursorNeighborhoodOCRText: "请填写标题，吸引更多点击"
        )

        XCTAssertEqual(result, .titleInput, "无焦点对象时，仍应可基于光标邻域 OCR 推断标题意图")
    }

    private func makeSignals(
        role: String? = nil,
        subrole: String? = nil,
        roleDescription: String? = nil,
        title: String? = nil,
        description: String? = nil,
        placeholder: String? = nil,
        valuePreview: String? = nil,
        characterCount: Int? = nil,
        frameHeight: Double? = nil,
        neighborhoodSnapshot: String? = nil,
        uiRoleSnapshot: String? = nil,
        focusedSnapshotWindow: String? = nil
    ) -> IntentClassifier.Signals {
        IntentClassifier.Signals(
            role: role,
            subrole: subrole,
            roleDescription: roleDescription,
            title: title,
            description: description,
            placeholder: placeholder,
            valuePreview: valuePreview,
            characterCount: characterCount,
            frameHeight: frameHeight,
            neighborhoodSnapshot: neighborhoodSnapshot,
            uiRoleSnapshot: uiRoleSnapshot,
            focusedSnapshotWindow: focusedSnapshotWindow,
            uiRoleReferences: nil,
            cursorNeighborhoodOCRText: nil
        )
    }
}

final class AIToolRecommendationServiceGuardrailTests: XCTestCase {
    private final class MockSmartRecommendationAIClient: SmartRecommendationAIClient, @unchecked Sendable {
        var generateCallCount = 0
        var generateWithScreenshotsCallCount = 0
        var lastSystemPrompt: String?
        var lastUserInput: String?
        var capturedUserInputs: [String] = []
        var textResponse: String?

        func generate(systemPrompt: String, userInput: String) async throws -> String {
            generateCallCount += 1
            lastSystemPrompt = systemPrompt
            lastUserInput = userInput
            capturedUserInputs.append(userInput)
            if let textResponse {
                return textResponse
            }
            return """
            {"tool_id":"00000000-0000-0000-0000-000000000000","tool_name":"mock","reason":"mock","confidence":0.5}
            """
        }

        func generateSmartRecommendationWithScreenshots(
            systemPrompt: String,
            userPrompt: String,
            screenshots: SmartContextScreenshots
        ) async throws -> String {
            generateWithScreenshotsCallCount += 1
            lastSystemPrompt = systemPrompt
            lastUserInput = userPrompt
            capturedUserInputs.append(userPrompt)
            if let textResponse {
                return textResponse
            }
            return """
            {"tool_id":"00000000-0000-0000-0000-000000000000","tool_name":"mock","reason":"mock","confidence":0.5}
            """
        }
    }

    func test_recommendTool_sameSceneAcross20Runs_keepsStableSelection() async throws {
        let aiClient = MockSmartRecommendationAIClient()
        let sut = AIToolRecommendationService(aiClient: aiClient)

        let toolA = PromptTool(name: "标题精炼", prompt: "title polish")
        let toolB = PromptTool(name: "小红书成稿", prompt: "body draft")

        aiClient.textResponse = """
        {"tool_id":"\(toolA.id.uuidString)","tool_name":"\(toolA.name)","reason":"mock","confidence":0.83}
        """

        let context = makeContext(clipboardText: "标题输入：周末穿搭")
        var selectedToolIDs: [UUID] = []

        for _ in 0..<20 {
            let recommendation = try await sut.recommendTool(context: context, availableTools: [toolA, toolB])
            selectedToolIDs.append(recommendation.toolID)
        }

        XCTAssertEqual(Set(selectedToolIDs), [toolA.id], "同场景连续运行应稳定返回同一工具")
        XCTAssertEqual(aiClient.generateCallCount, 20, "文本路径应每次调用模型")
        XCTAssertEqual(aiClient.generateWithScreenshotsCallCount, 0)
    }

    func test_recommendTool_twoRunsWithDifferentClipboardText_doesNotLeakPreviousClipboard() async throws {
        let aiClient = MockSmartRecommendationAIClient()
        let sut = AIToolRecommendationService(aiClient: aiClient)

        let titleTool = PromptTool(name: "标题精炼", prompt: "title polish")
        let bodyTool = PromptTool(name: "小红书成稿", prompt: "body draft")
        let markerRun1 = "RUN1_TITLE_MARKER_123"
        let markerRun2 = "RUN2_BODY_MARKER_456"

        aiClient.textResponse = """
        {"tool_id":"\(titleTool.id.uuidString)","tool_name":"\(titleTool.name)","reason":"mock","confidence":0.9}
        """

        let recommendationRun1 = try await sut.recommendTool(
            context: makeContext(clipboardText: markerRun1),
            availableTools: [titleTool, bodyTool]
        )
        let recommendationRun2 = try await sut.recommendTool(
            context: makeContext(clipboardText: markerRun2),
            availableTools: [titleTool, bodyTool]
        )

        XCTAssertEqual(recommendationRun1.toolID, titleTool.id)
        XCTAssertEqual(recommendationRun2.toolID, titleTool.id)
        XCTAssertEqual(aiClient.generateCallCount, 2)
        XCTAssertEqual(aiClient.capturedUserInputs.count, 2)
        XCTAssertTrue(aiClient.capturedUserInputs.allSatisfy { $0.contains("Clipboard Signals: disabled for recommendation") })
        XCTAssertTrue(aiClient.capturedUserInputs.allSatisfy { !$0.contains(markerRun1) && !$0.contains(markerRun2) })
    }

    func test_recommendTool_withScreenshots_usesVisionPath() async throws {
        let aiClient = MockSmartRecommendationAIClient()
        let sut = AIToolRecommendationService(aiClient: aiClient)

        let toolA = PromptTool(name: "标题精炼", prompt: "title polish")
        let toolB = PromptTool(name: "小红书成稿", prompt: "body draft")

        aiClient.textResponse = """
        {"tool_id":"\(toolA.id.uuidString)","tool_name":"\(toolA.name)","reason":"vision","confidence":0.88}
        """

        let recommendation = try await sut.recommendTool(
            context: makeContext(clipboardText: "任意内容", includeScreenshots: true),
            availableTools: [toolA, toolB]
        )

        XCTAssertEqual(recommendation.toolID, toolA.id)
        XCTAssertEqual(aiClient.generateWithScreenshotsCallCount, 1)
        XCTAssertEqual(aiClient.generateCallCount, 0)
    }

    func test_recommendTool_acceptsMarkdownWrappedJSON() async throws {
        let aiClient = MockSmartRecommendationAIClient()
        let sut = AIToolRecommendationService(aiClient: aiClient)

        let toolA = PromptTool(name: "标题精炼", prompt: "title polish")
        let toolB = PromptTool(name: "小红书成稿", prompt: "body draft")

        aiClient.textResponse = """
        ```json
        {"tool_id":"\(toolB.id.uuidString)","tool_name":"\(toolB.name)","reason":"markdown","confidence":0.71}
        ```
        """

        let recommendation = try await sut.recommendTool(
            context: makeContext(clipboardText: "任意内容"),
            availableTools: [toolA, toolB]
        )

        XCTAssertEqual(recommendation.toolID, toolB.id)
        XCTAssertEqual(recommendation.toolName, toolB.name)
    }

    private func makeContext(
        clipboardText: String,
        includeScreenshots: Bool = false
    ) -> SmartContext {
        SmartContext(
            applicationName: "Xiaohongshu",
            bundleID: "com.xingin.xhs",
            clipboardText: clipboardText,
            clipboardHasImage: false,
            cursorNeighborhoodOCRText: nil,
            focusedElement: SmartFocusedElementContext(
                role: "AXTextField",
                subrole: nil,
                roleDescription: "text field",
                title: "标题",
                description: nil,
                placeholder: "请输入标题",
                identifier: nil,
                valuePreview: "露营穿搭",
                characterCount: 4,
                frameX: 0,
                frameY: 0,
                frameWidth: 300,
                frameHeight: 40,
                intentHint: "title_input",
                neighborhoodSnapshot: nil,
                uiRoleSnapshot: nil,
                focusedSnapshotWindow: nil,
                uiRoleReferences: nil,
                uiRoleSnapshotStats: nil
            ),
            screenshot: includeScreenshots ? "focused_app_base64" : nil,
            fullScreenScreenshot: includeScreenshots ? "full_screen_base64" : nil,
            isLightweightMode: !includeScreenshots
        )
    }
}
