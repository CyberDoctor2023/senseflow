//
//  SmartContext.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-22.
//

import Foundation

/// OpenClaw 风格 UI 角色引用
struct SmartUIRoleReference: Codable {
    let ref: String
    let role: String
    let name: String?
    let nth: Int?
    let isInteractive: Bool
    let isFocused: Bool
}

/// OpenClaw 风格 UI 角色快照统计
struct SmartUIRoleSnapshotStats: Codable {
    let lines: Int
    let chars: Int
    let refs: Int
    let interactiveRefs: Int
    let focusedRef: String?
}

/// 当前焦点 UI 元素的语义信息（用于意图识别）
struct SmartFocusedElementContext: Codable {
    let role: String?
    let subrole: String?
    let roleDescription: String?
    let title: String?
    let description: String?
    let placeholder: String?
    let identifier: String?
    let valuePreview: String?
    let characterCount: Int?
    let frameX: Double?
    let frameY: Double?
    let frameWidth: Double?
    let frameHeight: Double?
    /// Heuristic local intent tag derived from focused element metadata.
    /// e.g. title_input / body_input / search_input / unknown
    let intentHint: String
    /// Compact nearby UI snapshot around focused element (parent + siblings cues).
    let neighborhoodSnapshot: String?
    /// Interactive role-based UI tree snapshot (OpenClaw-style compact format).
    let uiRoleSnapshot: String?
    /// Focused line-centered window in role snapshot (for local intent).
    let focusedSnapshotWindow: String?
    /// Structured role refs from snapshot.
    let uiRoleReferences: [SmartUIRoleReference]?
    /// Snapshot stats (OpenClaw-style).
    let uiRoleSnapshotStats: SmartUIRoleSnapshotStats?
}

/// Smart AI 截图集合
/// 统一表达业务层的双截图语义：
/// 1) 当前焦点应用窗口
/// 2) 全屏截图
struct SmartContextScreenshots: Codable {
    /// 当前焦点应用窗口截图（Base64 JPEG）
    let focusedApp: String?

    /// 全屏截图（Base64 JPEG）
    let fullScreen: String?

    /// 是否至少存在一张截图
    var hasAny: Bool {
        focusedApp != nil || fullScreen != nil
    }

    /// 按业务优先级返回可用截图列表
    /// 顺序固定：先焦点应用，再全屏
    var orderedAvailable: [String] {
        [focusedApp, fullScreen].compactMap { $0 }
    }
}

/// Smart recommendation context data
/// Collects information about current user environment
struct SmartContext: Codable {
    enum ClipboardPromptMode {
        case fullText
        case metadataOnly
    }

    // MARK: - Application Info

    /// Current active application name
    let applicationName: String

    /// Current active application bundle ID
    let bundleID: String

    // MARK: - Clipboard Info

    /// Clipboard text content
    let clipboardText: String?

    /// Whether clipboard contains image
    let clipboardHasImage: Bool

    /// OCR text extracted from cursor-near neighborhood screenshot
    let cursorNeighborhoodOCRText: String?

    // MARK: - Focused UI Element

    /// 当前焦点输入控件语义（如果可用）
    let focusedElement: SmartFocusedElementContext?

    // MARK: - Screenshot

    /// 双截图（焦点应用 + 全屏）
    let screenshots: SmartContextScreenshots

    // MARK: - Metadata

    /// Context collection timestamp
    let timestamp: Date

    /// Whether using lightweight mode (no screenshot)
    let isLightweightMode: Bool

    // MARK: - Initialization

    init(
        applicationName: String,
        bundleID: String,
        clipboardText: String?,
        clipboardHasImage: Bool,
        cursorNeighborhoodOCRText: String? = nil,
        focusedElement: SmartFocusedElementContext? = nil,
        screenshot: String?,
        fullScreenScreenshot: String? = nil,
        isLightweightMode: Bool = false
    ) {
        self.applicationName = applicationName
        self.bundleID = bundleID
        self.clipboardText = clipboardText
        self.clipboardHasImage = clipboardHasImage
        self.cursorNeighborhoodOCRText = cursorNeighborhoodOCRText
        self.focusedElement = focusedElement
        self.screenshots = SmartContextScreenshots(
            focusedApp: screenshot,
            fullScreen: fullScreenScreenshot
        )
        self.timestamp = Date()
        self.isLightweightMode = isLightweightMode
    }

    init(
        applicationName: String,
        bundleID: String,
        clipboardText: String?,
        clipboardHasImage: Bool,
        cursorNeighborhoodOCRText: String? = nil,
        focusedElement: SmartFocusedElementContext? = nil,
        screenshots: SmartContextScreenshots,
        isLightweightMode: Bool = false
    ) {
        self.applicationName = applicationName
        self.bundleID = bundleID
        self.clipboardText = clipboardText
        self.clipboardHasImage = clipboardHasImage
        self.cursorNeighborhoodOCRText = cursorNeighborhoodOCRText
        self.focusedElement = focusedElement
        self.screenshots = screenshots
        self.timestamp = Date()
        self.isLightweightMode = isLightweightMode
    }

    // MARK: - Helper Methods

    /// Generate text summary for AI analysis
    func toPromptSummary(clipboardMode: ClipboardPromptMode = .fullText) -> String {
        let clipboardSummary: String
        switch clipboardMode {
        case .fullText:
            clipboardSummary = "\(clipboardText?.prefix(BusinessRules.TextPreview.contextPreview) ?? "empty")"
        case .metadataOnly:
            if let clipboardText {
                let charCount = clipboardText.count
                let lineCount = clipboardText.split(separator: "\n", omittingEmptySubsequences: false).count
                clipboardSummary = "omitted (structured_intent_mode, chars=\(charCount), lines=\(lineCount))"
            } else {
                clipboardSummary = "empty"
            }
        }

        var summary = """
        Current Context:
        - Application: \(applicationName) (\(bundleID))
        - Clipboard: \(clipboardSummary)
        - Has Image: \(clipboardHasImage)
        """

        if let focusedElement {
            summary += "\n- Focused Element Role: \(focusedElement.role ?? "unknown")"
            summary += "\n- Focused Element Placeholder: \(focusedElement.placeholder ?? "unknown")"
            summary += "\n- Focused Element Title: \(focusedElement.title ?? "unknown")"
            summary += "\n- Focused Element Char Count: \(focusedElement.characterCount.map(String.init) ?? "unknown")"
            summary += "\n- Focused Element Frame H: \(focusedElement.frameHeight.map { String(Int($0)) } ?? "unknown")"
            summary += "\n- Focused Element Intent Hint: \(focusedElement.intentHint)"
            summary += "\n- Focused Element UI Role Snapshot: \(focusedElement.uiRoleSnapshot != nil ? "attached" : "unavailable")"
            summary += "\n- Focused Element UI Role Refs: \(focusedElement.uiRoleReferences?.count ?? 0)"
            summary += "\n- Focused Snapshot Window: \(focusedElement.focusedSnapshotWindow != nil ? "attached" : "unavailable")"
        }
        summary += "\n- Cursor Neighborhood OCR: \(cursorNeighborhoodOCRText != nil ? "attached" : "unavailable")"

        if isLightweightMode {
            summary += "\n- Screenshot: disabled (lightweight mode)"
        } else {
            summary += "\n- Annotated UI Tree Screenshot: \(screenshots.focusedApp != nil ? "attached" : "unavailable")"
            summary += "\n- Full Screen Screenshot: \(screenshots.fullScreen != nil ? "attached" : "unavailable")"
        }

        return summary
    }
}
