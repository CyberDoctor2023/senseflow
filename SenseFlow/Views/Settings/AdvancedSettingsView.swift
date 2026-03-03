//
//  AdvancedSettingsView.swift
//  SenseFlow
//
//  Created on 2026-01-19 for v0.2.1
//  Updated on 2026-02-10 for @Observable + @Bindable pattern
//

import SwiftUI

/// 高级设置（使用 @Bindable 接收 SettingsModel 双向绑定）
struct AdvancedSettingsView: View {
    @Bindable var model: SettingsModel

    @State private var showResetConfirmation = false
    @State private var resetSuccess = false

    var body: some View {
        Form {
            // 划词即复制设置
            Section(Strings.AdvancedSettings.textSelectionSection) {
                Toggle(Strings.AdvancedSettings.textSelectionToggle, isOn: $model.textSelectionEnabled)
                    .help(Strings.AdvancedSettings.textSelectionDescription)

                Stepper(
                    Strings.AdvancedSettings.minLengthLabel(model.minTextLength),
                    value: $model.minTextLength,
                    in: 1...20
                )
                .help(Strings.AdvancedSettings.minLengthHelp)
                .disabled(!model.textSelectionEnabled)

                // 强制取词开关
                Toggle(Strings.AdvancedSettings.forcedExtractionToggle, isOn: $model.forcedExtractionEnabled)
                    .help(Strings.AdvancedSettings.forcedExtractionHelp)
                    .disabled(!model.textSelectionEnabled)

                Text(Strings.AdvancedSettings.forcedExtractionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(Strings.AdvancedSettings.textSelectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 开发者选项
            Section("开发者选项") {
                Text("自定义 Smart AI 系统提示词（用于工具推荐）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextEditor(text: $model.smartAISystemPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color.secondary.opacity(0.2), width: 1)

                HStack {
                    Button("恢复默认") {
                        model.resetSmartAISystemPrompt()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text("修改后立即生效")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section(Strings.AdvancedSettings.sectionTitle) {
                Text(Strings.AdvancedSettings.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(Strings.AdvancedSettings.resetButton) {
                    showResetConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .help(Strings.AdvancedSettings.resetButtonHelp)

                // 成功提示
                if resetSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(Strings.AdvancedSettings.successMessage)
                            .font(.caption)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .formStyle(.grouped)
        .compatibleControlSize()
        .confirmationDialog(
                Strings.AdvancedSettings.confirmTitle,
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(Strings.AdvancedSettings.confirmButton, role: .destructive) {
                    resetToDefaults()
                }
                Button(Strings.AdvancedSettings.cancelButton, role: .cancel) {}
            } message: {
                Text(Strings.AdvancedSettings.confirmMessage)
            }
    }

    // MARK: - Private Methods

    private func resetToDefaults() {
        // 重置 UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.historyLimit)
        defaults.removeObject(forKey: UserDefaultsKeys.autoPasteEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.launchAtLogin)
        defaults.removeObject(forKey: UserDefaultsKeys.filterAppList)
        defaults.removeObject(forKey: UserDefaultsKeys.selectedAIService)
        defaults.removeObject(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.textSelectionMinLength)
        defaults.removeObject(forKey: UserDefaultsKeys.textSelectionForcedExtractionEnabled)
        for service in AIServiceType.allCases {
            service.saveSelectedModel("")
        }

        // 重置快捷键
        HotKeyPreferences.reset()
        HotKeyPreferences.resetSmart()

        // 重新注册快捷键
        _ = AppHotKeyCoordinator.shared.reloadMainHotKey()
        _ = AppHotKeyCoordinator.shared.reloadSmartHotKey()

        // 同步 model 状态（从重置后的 UserDefaults 重新加载）
        let freshModel = SettingsModel()
        model.historyLimit = freshModel.historyLimit
        model.autoPasteEnabled = freshModel.autoPasteEnabled
        model.launchAtLogin = freshModel.launchAtLogin
        model.textSelectionEnabled = freshModel.textSelectionEnabled
        model.minTextLength = freshModel.minTextLength
        model.forcedExtractionEnabled = freshModel.forcedExtractionEnabled
        model.filterAppListString = freshModel.filterAppListString

        print("✅ 设置已重置为默认值")

        // 显示成功提示
        withAnimation(.compatibleSnappy(duration: BusinessRules.Animation.successFeedbackDuration)) {
            resetSuccess = true
        }

        // 3 秒后隐藏提示
        Task {
            try? await Task.sleep(nanoseconds: BusinessRules.Animation.successDisplayDuration)
            await MainActor.run {
                withAnimation(.compatibleSnappy(duration: BusinessRules.Animation.successFeedbackDuration)) {
                    resetSuccess = false
                }
            }
        }
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        AdvancedSettingsView(model: SettingsModel())
            .frame(
                width: DesignSystem.WindowSize.settingsWindow.width,
                height: DesignSystem.WindowSize.settingsWindow.height
            )
    } else {
        Text(Strings.AdvancedSettings.previewFallback)
    }
}
