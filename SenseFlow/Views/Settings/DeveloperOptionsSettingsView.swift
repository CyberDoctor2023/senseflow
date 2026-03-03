//
//  DeveloperOptionsSettingsView.swift
//  SenseFlow
//
//  Created on 2026-02-04.
//

import SwiftUI

/// Developer Options 设置页面（Form-based layout per macOS standards）
struct DeveloperOptionsSettingsView: View {
    @EnvironmentObject var dependencies: DependencyEnvironment

    // Langfuse 配置
    @State private var langfuseEnabled = false
    @State private var langfusePublicKey = ""
    @State private var langfuseSecretKey = ""
    @State private var langfuseSyncInterval: Double = BusinessRules.Langfuse.defaultSyncInterval
    @State private var langfuseActiveLabel = BusinessRules.Langfuse.defaultActiveLabel
    @State private var isSyncing = false
    @State private var lastSyncTime: Date?
    @State private var syncStatus: String = BusinessRules.Langfuse.defaultStatus

    // Keychain 批量保存状态
    @State private var hasUnsavedChanges = false
    @State private var saveSuccess = false

    var body: some View {
        Form {
            // Langfuse 集成
            Section {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text(Strings.DeveloperOptions.langfuseTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Toggle("", isOn: $langfuseEnabled)
                            .labelsHidden()
                            .onChange(of: langfuseEnabled) { newValue in
                                saveLangfuseConfig()
                            }
                    }

                    Text(Strings.DeveloperOptions.langfuseDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if langfuseEnabled {
                        Group {
                            TextField(Strings.DeveloperOptions.publicKeyPlaceholder, text: $langfusePublicKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: langfusePublicKey) { _ in
                                    hasUnsavedChanges = true
                                }

                            SecureField(Strings.DeveloperOptions.secretKeyPlaceholder, text: $langfuseSecretKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: langfuseSecretKey) { _ in
                                    hasUnsavedChanges = true
                                }

                            HStack {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(Strings.DeveloperOptions.syncIntervalText(Int(langfuseSyncInterval / BusinessRules.Langfuse.secondsPerMinute)))
                                        .font(.caption)
                                    Slider(value: $langfuseSyncInterval,
                                          in: BusinessRules.Langfuse.minSyncInterval...BusinessRules.Langfuse.maxSyncInterval,
                                          step: BusinessRules.Langfuse.syncIntervalStep)
                                        .onChange(of: langfuseSyncInterval) { _ in
                                            saveLangfuseConfig()
                                        }
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(Strings.DeveloperOptions.labelFieldTitle)
                                        .font(.caption)
                                    TextField(Strings.DeveloperOptions.labelPlaceholder, text: $langfuseActiveLabel)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 150)
                                        .onChange(of: langfuseActiveLabel) { _ in
                                            saveLangfuseConfig()
                                        }
                                }
                            }

                            HStack {
                                Button(action: saveAllKeys) {
                                    Label(
                                        saveSuccess ? Strings.DeveloperOptions.saveButtonSaved : Strings.DeveloperOptions.saveButtonDefault,
                                        systemImage: saveSuccess ? "checkmark.circle.fill" : "square.and.arrow.down"
                                    )
                                }
                                .compatibleButtonStyle(prominent: true)
                                .disabled(!hasUnsavedChanges)
                                .help(Strings.DeveloperOptions.saveButtonHelp)

                                if hasUnsavedChanges {
                                    Text(Strings.DeveloperOptions.unsavedChanges)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }

                                Spacer()
                            }

                            Divider()

                            HStack {
                                Button {
                                    syncNow()
                                } label: {
                                    if isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    } else {
                                        Label(Strings.DeveloperOptions.syncNowButton, systemImage: "arrow.triangle.2.circlepath")
                                    }
                                }
                                .disabled(isSyncing || langfusePublicKey.isEmpty || langfuseSecretKey.isEmpty)

                                Text(syncStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                if let lastSync = lastSyncTime {
                                    Text(lastSync, formatter: dateFormatter)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text(Strings.DeveloperOptions.sectionHeader)
            }

            // API Request Inspector
            Section {
                APIRequestInspectorView(
                    recorder: apiRequestRecorder,
                    inspectionService: dependencies.apiRequestInspectionService
                )
            } header: {
                Text("调试工具")
            }
        }
        .formStyle(.grouped)
        .compatibleControlSize()
        .onAppear {
            loadLangfuseConfig()
        }
    }

    // MARK: - Private Methods

    /// 加载 Langfuse 配置
    private func loadLangfuseConfig() {
        let config = LangfuseSyncService.shared.getConfiguration()

        langfuseEnabled = config.enabled
        langfusePublicKey = config.publicKey
        langfuseSecretKey = config.secretKey
        langfuseSyncInterval = config.syncInterval
        langfuseActiveLabel = config.activeLabel
        lastSyncTime = config.lastSyncTime
        updateSyncStatus()
    }

    /// 批量保存所有密钥
    private func saveAllKeys() {
        // Langfuse 配置保存到 UserDefaults（不触发授权）
        saveLangfuseConfig()

        // 更新状态
        hasUnsavedChanges = false
        saveSuccess = true

        // 2 秒后重置成功状态
        Task {
            try? await Task.sleep(nanoseconds: BusinessRules.Langfuse.twoSeconds)
            await MainActor.run {
                saveSuccess = false
            }
        }
    }

    private func saveLangfuseConfig() {
        LangfuseSyncService.shared.updateConfiguration(
            enabled: langfuseEnabled,
            publicKey: langfusePublicKey,
            secretKey: langfuseSecretKey,
            syncInterval: langfuseSyncInterval,
            activeLabel: langfuseActiveLabel
        )
    }

    private func syncNow() {
        guard !isSyncing else { return }

        isSyncing = true
        syncStatus = BusinessRules.Langfuse.syncing

        Task {
            do {
                try await LangfuseSyncService.shared.syncFromRemote()
                await MainActor.run {
                    isSyncing = false
                    lastSyncTime = Date()
                    syncStatus = BusinessRules.Langfuse.success
                }

                // 3 秒后恢复状态
                try await Task.sleep(nanoseconds: BusinessRules.Langfuse.threeSeconds)
                await MainActor.run {
                    updateSyncStatus()
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncStatus = BusinessRules.Langfuse.failure(error.localizedDescription)
                }
            }
        }
    }

    private func updateSyncStatus() {
        if let lastSync = lastSyncTime {
            let interval = Date().timeIntervalSince(lastSync)
            if interval < BusinessRules.Langfuse.oneMinute {
                syncStatus = BusinessRules.Langfuse.justNow
            } else if interval < BusinessRules.Langfuse.oneHour {
                syncStatus = BusinessRules.Langfuse.minutesAgo(Int(interval / BusinessRules.Langfuse.oneMinute))
            } else if interval < BusinessRules.Langfuse.oneDay {
                syncStatus = BusinessRules.Langfuse.hoursAgo(Int(interval / BusinessRules.Langfuse.oneHour))
            } else {
                syncStatus = BusinessRules.Langfuse.daysAgo(Int(interval / BusinessRules.Langfuse.oneDay))
            }
        } else {
            syncStatus = BusinessRules.Langfuse.defaultStatus
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    private var apiRequestRecorder: InMemoryAPIRequestRecorder {
        (dependencies.container.apiRequestRecorder as? InMemoryAPIRequestRecorder) ?? InMemoryAPIRequestRecorder.shared
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        DeveloperOptionsSettingsView()
            .frame(width: DesignSystem.WindowSize.settingsWindow.width, height: DesignSystem.WindowSize.settingsWindow.height)
    } else {
        Text(Strings.DeveloperOptions.previewFallback)
    }
}
