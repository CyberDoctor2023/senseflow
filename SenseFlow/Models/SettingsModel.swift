//
//  SettingsModel.swift
//  SenseFlow
//
//  Created on 2026-02-10.
//  Centralized settings data model using @Observable (Landmarks pattern)
//

import SwiftUI

/// Chooses the additional card motion without changing native scroll physics.
enum HistoryCardMotion: String, CaseIterable {
    case classic, wave
    static let preferenceKey = "history_card_motion"
    var title: String { self == .classic ? "经典" : "起伏" }
}

/// 设置数据模型 - 集中管理所有设置属性
/// 模仿 Landmarks 项目的 ModelData 模式，使用 @Observable 驱动 UI
@Observable @MainActor
class SettingsModel {
    private let defaults = UserDefaults.standard

    // MARK: - General Settings

    /// 开机自启动
    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: UserDefaultsKeys.launchAtLogin) }
    }

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
        self.launchAtLogin = defaults.bool(forKey: UserDefaultsKeys.launchAtLogin)

        // Advanced
        self.textSelectionEnabled = defaults.object(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled) as? Bool ?? false
        let savedMinLength = defaults.integer(forKey: UserDefaultsKeys.textSelectionMinLength)
        self.minTextLength = savedMinLength > 0 ? savedMinLength : 3
        self.forcedExtractionEnabled = defaults.bool(forKey: UserDefaultsKeys.textSelectionForcedExtractionEnabled)

        // Privacy
        self.filterAppListString = defaults.string(forKey: UserDefaultsKeys.filterAppList) ?? ""
    }

}
