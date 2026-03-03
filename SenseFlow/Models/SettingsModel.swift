//
//  SettingsModel.swift
//  SenseFlow
//
//  Created on 2026-02-10.
//  Centralized settings data model using @Observable (Landmarks pattern)
//

import SwiftUI

/// 设置数据模型 - 集中管理所有设置属性
/// 模仿 Landmarks 项目的 ModelData 模式，使用 @Observable 驱动 UI
@Observable @MainActor
class SettingsModel {
    private let defaults = UserDefaults.standard
    private static let legacyClipboardDominantMarker = "The clipboard content is the ABSOLUTE SOURCE OF TRUTH"
    private static let legacyClipboardDominantMarker2 = "ALWAYS base your recommendation on the clipboard content"
    private static let legacyFocusedIntentMarker = "FIRST classify the focused input intent"
    private static let legacyCursorOCRMarker = "cursor_neighborhood_ocr_text is strong local evidence around pointer position"

    // MARK: - General Settings

    /// 历史记录上限
    var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: UserDefaultsKeys.historyLimit) }
    }

    /// 自动粘贴开关
    var autoPasteEnabled: Bool {
        didSet { defaults.set(autoPasteEnabled, forKey: UserDefaultsKeys.autoPasteEnabled) }
    }

    /// 开机自启动
    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: UserDefaultsKeys.launchAtLogin) }
    }

    // MARK: - Smart AI Settings

    /// Smart AI 开关
    var smartAIEnabled: Bool {
        didSet { defaults.set(smartAIEnabled, forKey: "smartAIEnabled") }
    }

    /// 轻量模式
    var lightweightMode: Bool {
        didSet { defaults.set(lightweightMode, forKey: "smartAILightweightMode") }
    }

    /// Smart AI 系统提示词（开发者选项）
    var smartAISystemPrompt: String {
        didSet { defaults.set(smartAISystemPrompt, forKey: "smartAISystemPrompt") }
    }

    /// 重置 Smart AI 系统提示词为默认值
    func resetSmartAISystemPrompt() {
        smartAISystemPrompt = Self.defaultSmartAISystemPrompt
    }

    /// 默认的 Smart AI 系统提示词
    nonisolated static let defaultSmartAISystemPrompt = """
        You recommend exactly one Prompt Tool from a provided list.

        Available context may include:
        - Application metadata (app name, bundle id)
        - One or two screenshots (annotated UI tree and/or full screen)
        - Clipboard metadata/text

        Decision policy:
        1. Start from screenshot evidence, not stereotypes.
        2. Locate cursor/caret first (explicit marker or native pointer/caret), and treat the nearest cursor-located region as the primary intent region.
        3. All intent judgments must expand outward from the cursor/caret-centered region.
        4. Treat app name, bundle id, and tool-name similarity as weak priors only.
        5. Choose the tool that best matches the observed local UI intent.
        6. Give higher weight to cursor-near text as local evidence, then combine with nearby controls and global screenshot context.
        7. Do not rely only on page title/header/footer CTA when cursor-near evidence suggests another intent.
        8. If local screenshot evidence conflicts with global hints, trust local screenshot evidence.
        9. If uncertain, choose the safest generic tool.

        Return JSON only:
        {
          "tool_id": "UUID from provided list",
          "tool_name": "Tool name from provided list",
          "reason": "1-2 short sentences grounded in screenshot/local evidence",
          "confidence": 0.0
        }

        Output constraints:
        - Only choose from provided tools.
        - Reason should mention cursor-near evidence when available.
        - Do not use "the user is in app X" as the primary reason for tool selection.
        - No markdown, no extra text, valid JSON only.
        """

    // MARK: - Advanced Settings

    /// 划词即复制开关
    var textSelectionEnabled: Bool {
        didSet { defaults.set(textSelectionEnabled, forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled) }
    }

    /// 最小文本长度
    var minTextLength: Int {
        didSet { defaults.set(minTextLength, forKey: UserDefaultsKeys.textSelectionMinLength) }
    }

    /// 强制取词开关
    var forcedExtractionEnabled: Bool {
        didSet { defaults.set(forcedExtractionEnabled, forKey: UserDefaultsKeys.textSelectionForcedExtractionEnabled) }
    }

    // MARK: - Privacy Settings

    /// 应用过滤列表
    var filterAppListString: String {
        didSet { defaults.set(filterAppListString, forKey: UserDefaultsKeys.filterAppList) }
    }

    // MARK: - Initialization

    init() {
        // 从 UserDefaults 加载初始值
        let defaults = UserDefaults.standard

        // General
        let savedLimit = defaults.integer(forKey: UserDefaultsKeys.historyLimit)
        self.historyLimit = savedLimit > 0 ? savedLimit : BusinessRules.ClipboardHistory.defaultLimit
        self.autoPasteEnabled = defaults.object(forKey: UserDefaultsKeys.autoPasteEnabled) as? Bool ?? true
        self.launchAtLogin = defaults.bool(forKey: UserDefaultsKeys.launchAtLogin)

        // Smart AI
        self.smartAIEnabled = defaults.object(forKey: "smartAIEnabled") as? Bool ?? true
        self.lightweightMode = defaults.bool(forKey: "smartAILightweightMode")
        let savedPrompt = defaults.string(forKey: "smartAISystemPrompt")
        let resolvedSmartPrompt: String
        if let savedPrompt, Self.shouldMigrateSmartPrompt(savedPrompt) {
            resolvedSmartPrompt = Self.defaultSmartAISystemPrompt
            defaults.set(resolvedSmartPrompt, forKey: "smartAISystemPrompt")
        } else {
            resolvedSmartPrompt = savedPrompt ?? Self.defaultSmartAISystemPrompt
        }
        self.smartAISystemPrompt = resolvedSmartPrompt

        // Advanced
        self.textSelectionEnabled = defaults.object(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled) as? Bool ?? false
        let savedMinLength = defaults.integer(forKey: UserDefaultsKeys.textSelectionMinLength)
        self.minTextLength = savedMinLength > 0 ? savedMinLength : 3
        self.forcedExtractionEnabled = defaults.bool(forKey: UserDefaultsKeys.textSelectionForcedExtractionEnabled)

        // Privacy
        self.filterAppListString = defaults.string(forKey: UserDefaultsKeys.filterAppList) ?? ""
    }

    private static func shouldMigrateSmartPrompt(_ prompt: String) -> Bool {
        if prompt.contains(Self.legacyClipboardDominantMarker),
           prompt.contains(Self.legacyClipboardDominantMarker2) {
            return true
        }

        if prompt.contains(Self.legacyFocusedIntentMarker),
           prompt.contains(Self.legacyCursorOCRMarker) {
            return true
        }

        return false
    }
}
