//
//  SmartAISettingsView.swift
//  SenseFlow
//
//  Created on 2026-02-04.
//  Updated on 2026-02-10 for @Observable + @Bindable pattern
//

import SwiftUI
import KeyboardShortcuts

/// Smart AI 设置页面（使用 @Bindable 接收 SettingsModel 双向绑定）
struct SmartAISettingsView: View {
    @EnvironmentObject var dependencies: DependencyEnvironment
    @Bindable var model: SettingsModel

    // 权限状态（运行时检测，不持久化到 Model）
    @State private var hasScreenRecordingPermission = false
    @State private var smartHotKeyConfig = HotKeyPreferences.loadSmart()
    @State private var showShortcutConflictAlert = false
    @State private var showShortcutUpdated = false
    @State private var showNoChangeHint = false
    @State private var isSyncingRecorder = false
    @State private var isRecorderActive = false
    @State private var shortcutBeforeRecording: KeyboardShortcuts.Shortcut?

    private let recorderStatusNotification = Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange")

    var body: some View {
        Form {
            // Smart AI 功能概述
            Section {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(Strings.SmartAISettings.title)
                                .font(.headline)
                            Text(Strings.SmartAISettings.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(Strings.SmartAISettings.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }

            // 基本配置
            Section(Strings.SmartAISettings.configSection) {
                Toggle(Strings.SmartAISettings.enableToggle, isOn: $model.smartAIEnabled)
                    .help(Strings.SmartAISettings.enableHelp)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text(Strings.SmartAISettings.shortcutLabel)
                            .foregroundStyle(.secondary)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: HotKeyNames.smart, onChange: applyRecordedSmartShortcut)
                        Button(Strings.Buttons.reset) {
                            resetSmartHotKey()
                        }
                        .buttonStyle(.bordered)
                    }

                    if showShortcutUpdated {
                        Text(Strings.HotKey.successMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if showNoChangeHint {
                        Text("快捷键未变更：通常表示该组合被系统/菜单占用，或本次录制已取消。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .help(Strings.SmartAISettings.shortcutHelp)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Toggle(Strings.SmartAISettings.lightweightToggle, isOn: $model.lightweightMode)
                        .disabled(!model.smartAIEnabled)

                    Text(Strings.SmartAISettings.lightweightDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 权限状态
            Section(Strings.SmartAISettings.permissionSection) {
                HStack {
                    Image(systemName: hasScreenRecordingPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(hasScreenRecordingPermission ? .green : .red)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(Strings.SmartAISettings.screenRecordingTitle)
                            .font(.body)
                        Text(hasScreenRecordingPermission ? Strings.SmartAISettings.permissionGranted : Strings.SmartAISettings.permissionDenied)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !hasScreenRecordingPermission {
                        Button(Strings.SmartAISettings.openGuideButton) {
                            restoreOnboarding()
                        }
                        .compatibleButtonStyle()
                    }
                }

                if !hasScreenRecordingPermission {
                    Text(Strings.SmartAISettings.permissionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .compatibleControlSize()
        .alert(Strings.HotKey.conflictTitle, isPresented: $showShortcutConflictAlert) {
            Button(Strings.Buttons.confirm, role: .cancel) { }
        } message: {
            Text(Strings.HotKey.conflictMessage)
        }
        .onAppear {
            checkPermissions()
            smartHotKeyConfig = HotKeyPreferences.loadSmart()
        }
        .onReceive(NotificationCenter.default.publisher(for: recorderStatusNotification)) { event in
            let active = event.userInfo?["isActive"] as? Bool ?? false

            if active {
                isRecorderActive = true
                shortcutBeforeRecording = KeyboardShortcuts.getShortcut(for: HotKeyNames.smart)
                showNoChangeHint = false
                return
            }

            guard isRecorderActive else { return }
            isRecorderActive = false

            let current = KeyboardShortcuts.getShortcut(for: HotKeyNames.smart)
            if current == shortcutBeforeRecording {
                showNoChangeHint = true
            }
        }
    }

    // MARK: - Private Methods

    private func checkPermissions() {
        hasScreenRecordingPermission = ScreenCaptureManager.shared.checkPermission()
    }

    private func applyRecordedSmartShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        guard !isSyncingRecorder else { return }
        showNoChangeHint = false

        guard let shortcut else {
            restoreRecorderWithCurrentConfig()
            return
        }

        let carbon = HotKeyShortcutCodec.toCarbon(shortcut)
        if carbon.keyCode == smartHotKeyConfig.keyCode &&
            carbon.modifiers == smartHotKeyConfig.modifierFlags {
            return
        }

        updateSmartHotKey(
            keyCode: carbon.keyCode,
            modifiers: carbon.modifiers
        )
    }

    private func updateSmartHotKey(keyCode: UInt32, modifiers: UInt32) {
        let result = HotKeySettingsTransaction.apply(
            kind: .smart,
            keyCode: keyCode,
            modifiers: modifiers
        )
        smartHotKeyConfig = result.config
        guard result.success else {
            showShortcutConflictAlert = true
            restoreRecorderWithCurrentConfig()
            return
        }

        showTransientSuccess()
    }

    private func resetSmartHotKey() {
        let defaultConfig = HotKeyConfig.smartDefault
        guard defaultConfig != smartHotKeyConfig else { return }

        let result = HotKeySettingsTransaction.resetToDefault(kind: .smart)
        smartHotKeyConfig = result.config
        guard result.success else {
            showShortcutConflictAlert = true
            restoreRecorderWithCurrentConfig()
            return
        }
        showTransientSuccess()
    }

    private func restoreRecorderWithCurrentConfig() {
        smartHotKeyConfig = HotKeyPreferences.loadSmart()
        let shortcut = HotKeySettingsTransaction.currentShortcut(kind: .smart)
        setRecorderShortcut(shortcut)
    }

    private func setRecorderShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        isSyncingRecorder = true
        KeyboardShortcuts.setShortcut(shortcut, for: HotKeyNames.smart)
        DispatchQueue.main.async {
            isSyncingRecorder = false
        }
    }

    private func showTransientSuccess() {
        showShortcutUpdated = true
        DispatchQueue.main.asyncAfter(deadline: .now() + BusinessRules.TimeInterval.successMessageDisplay) {
            showShortcutUpdated = false
        }
    }

    private func restoreOnboarding() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.skipOnboardingPermissions)

        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
            OnboardingWindowManager.shared.showWindow()
            return
        }

        appDelegate.showOnboardingWindow()
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        SmartAISettingsView(model: SettingsModel())
            .frame(width: DesignSystem.WindowSize.settingsWindow.width, height: DesignSystem.WindowSize.settingsWindow.height)
    } else {
        Text(Strings.SmartAISettings.previewFallback)
    }
}
