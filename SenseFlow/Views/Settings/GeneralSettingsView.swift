//
//  GeneralSettingsView.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-16.
//  Updated on 2026-02-10 for @Observable + @Bindable pattern
//

import SwiftUI
import ServiceManagement

/// 通用设置（使用 @Bindable 接收 SettingsModel 双向绑定）
struct GeneralSettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section(Strings.GeneralSettings.historySection) {
                Stepper(Strings.GeneralSettings.historyLimitLabel(model.historyLimit),
                       value: $model.historyLimit,
                       in: BusinessRules.ClipboardHistory.minLimit...BusinessRules.ClipboardHistory.maxLimit,
                       step: BusinessRules.ClipboardHistory.limitStep)
                    .help(Strings.GeneralSettings.historyLimitHelp)
                    .onChange(of: model.historyLimit) { _, newValue in
                        DatabaseManager.shared.enforceHistoryLimit(limit: newValue)
                    }
            }

            Section(Strings.GeneralSettings.behaviorSection) {
                Toggle(Strings.GeneralSettings.autoPasteToggle, isOn: $model.autoPasteEnabled)
                    .help(Strings.GeneralSettings.autoPasteHelp)

                Toggle(Strings.GeneralSettings.launchAtLoginToggle, isOn: $model.launchAtLogin)
                    .help(Strings.GeneralSettings.launchAtLoginHelp)
                    .onChange(of: model.launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .compatibleControlSize()
    }

    /// 设置开机自启动
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("✅ 开机自启动已启用")
            } else {
                try SMAppService.mainApp.unregister()
                print("✅ 开机自启动已禁用")
            }
        } catch {
            print("❌ 开机自启动设置失败: \(error)")
            // 回滚状态
            model.launchAtLogin = !enabled
        }
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        GeneralSettingsView(model: SettingsModel())
            .frame(
                width: DesignSystem.WindowSize.settingsWindow.width,
                height: DesignSystem.WindowSize.settingsWindow.height
            )
    } else {
        Text(Strings.GeneralSettings.previewRequirement)
    }
}
