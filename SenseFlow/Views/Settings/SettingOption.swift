//
//  SettingOption.swift
//  SenseFlow
//
//  Created on 2026-02-10.
//  An enumeration of settings navigation options (Landmarks NavigationOptions pattern)
//

import SwiftUI

/// 设置页面导航选项（模仿 Landmarks 的 NavigationOptions）
enum SettingOption: String, Equatable, Hashable, Identifiable, CaseIterable {
    case general
    case shortcuts
    case smartAI
    case promptTools
    case developerOptions
    case privacy
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .shortcuts: "快捷键"
        case .smartAI: "Smart AI"
        case .promptTools: "Prompt Tools"
        case .developerOptions: "开发者选项"
        case .privacy: "隐私"
        case .advanced: "高级"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gear"
        case .shortcuts: "keyboard"
        case .smartAI: "sparkles"
        case .promptTools: "wand.and.stars"
        case .developerOptions: "hammer"
        case .privacy: "lock"
        case .advanced: "wrench.and.screwdriver"
        }
    }

    /// 根据选项返回对应的设置子视图（模仿 NavigationOptions.viewForPage()）
    @MainActor @ViewBuilder func viewForPage(model: SettingsModel) -> some View {
        switch self {
        case .general: GeneralSettingsView(model: model)
        case .shortcuts: ShortcutSettingsView()
        case .smartAI: SmartAISettingsView(model: model)
        case .promptTools: PromptToolsSettingsView()
        case .developerOptions: DeveloperOptionsSettingsView()
        case .privacy: PrivacySettingsView(model: model)
        case .advanced: AdvancedSettingsView(model: model)
        }
    }
}
