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

    // Settings
    static let launchAtLogin = "launch_at_login"
    static let autoDeleteEnabled = "auto_delete_enabled"
    static let autoDeleteDays = "auto_delete_days"
    static let sensitiveContentFilterEnabled = "sensitive_content_filter_enabled"
    static let imageOCREnabled = "image_ocr_enabled"
    static let filterAppList = "filter_app_list"

    // HotKey
    static let hotKeyConfig = "hotkey_config"

    // Developer Options

    // Text Selection Auto-Copy
    static let textSelectionAutoCopyEnabled = "text_selection_auto_copy_enabled"
    static let textSelectionMinLength = "text_selection_min_length"
    static let textSelectionForcedExtractionEnabled = "text_selection_forced_extraction_enabled"
}
