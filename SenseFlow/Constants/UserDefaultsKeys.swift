//
//  UserDefaultsKeys.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//  UserDefaults 键名常量
//

import Foundation

/// UserDefaults 键名 - 避免拼写错误
enum UserDefaultsKeys {
    // Onboarding
    static let skipOnboardingPermissions = "skipOnboardingPermissions"

    // Settings
    static let historyLimit = "history_limit"
    static let autoPasteEnabled = "auto_paste_enabled"
    static let launchAtLogin = "launch_at_login"
    static let autoDeleteEnabled = "auto_delete_enabled"
    static let autoDeleteDays = "auto_delete_days"
    static let sensitiveContentFilterEnabled = "sensitive_content_filter_enabled"
    static let imageOCREnabled = "image_ocr_enabled"
    static let smartRecommendationEnabled = "smart_recommendation_enabled"
    static let filterAppList = "filter_app_list"
    static let selectedAIService = "selected_ai_service"

    // HotKey
    static let hotKeyConfig = "hotkey_config"
    static let smartHotKeyConfig = "smart_hotkey_config"

    // Developer Options
    static let langfuseSyncInterval = "langfuse_sync_interval"
    static let langfuseActiveLabel = "langfuse_active_label"

    // Text Selection Auto-Copy
    static let textSelectionAutoCopyEnabled = "text_selection_auto_copy_enabled"
    static let textSelectionMinLength = "text_selection_min_length"
    static let textSelectionForcedExtractionEnabled = "text_selection_forced_extraction_enabled"
}
