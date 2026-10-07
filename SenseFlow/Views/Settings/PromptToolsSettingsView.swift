//
//  PromptToolsSettingsView.swift
//  SenseFlow
//
//  Created on 2026-01-19.
//  Updated on 2026-01-26 for Form-based layout
//

import SwiftUI

/// Prompt Tools 设置 Tab（Form-based layout per macOS standards）
struct PromptToolsSettingsView: View {
    @EnvironmentObject var dependencies: DependencyEnvironment
    @State private var tools: [PromptTool] = []
    @State private var connectionExpanded = false
    @State private var connectionLoaded = false

    // 使用独立的状态管理编辑模式
    enum EditorMode: Identifiable {
        case new
        case edit(PromptTool)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let tool): return tool.id.uuidString
            }
        }

        var tool: PromptTool? {
            switch self {
            case .new: return nil
            case .edit(let tool): return tool
            }
        }
    }

    @State private var editorMode: EditorMode?

    // AI 服务配置
    @State private var selectedService: AIServiceType = .openai
    @State private var apiKey = ""
    @State private var originalApiKey = ""  // 跟踪原始加载的值
    @State private var modelName = ""
    @State private var originalModelName = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    @State private var codexAuthStatus: CodexAuthStatus = .loggedOut()
    @State private var codexLoginMessage: String?
    @State private var isCodexAuthInProgress = false

    // 缓存所有 API Keys（避免切换服务时重复读取 Keychain）
    @State private var cachedAPIKeys: [AIServiceType: String] = [:]
    @State private var cachedModelNames: [AIServiceType: String] = [:]

    // Keychain 批量保存状态
    @State private var saveSuccess = false
    @State private var showToolSaveError = false
    @State private var toolSaveErrorMessage = ""

    // 计算属性：检查是否有未保存的更改
    private var hasUnsavedChanges: Bool {
        return apiKey != originalApiKey || modelName != originalModelName
    }

    private var apiSettingsService: UserAPISettingsServiceProtocol {
        dependencies.userAPISettingsService
    }

    private var codexAuthSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: codexAuthStatus.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(codexAuthStatus.isAuthenticated ? .green : .red)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(Strings.PromptToolsSettings.codexAuthTitle)
                    Text(codexAuthStatus.message)
                        .font(.pingFang(.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }


            HStack {
                Button {
                    startCodexLogin()
                } label: {
                    Label(Strings.PromptToolsSettings.codexLoginButton, systemImage: "person.crop.circle.badge.plus")
                }
                .compatibleButtonStyle(prominent: !codexAuthStatus.isAuthenticated)
                .disabled(isCodexAuthInProgress)

                Button {
                    refreshCodexAuthStatus()
                } label: {
                    Label(Strings.PromptToolsSettings.codexRefreshButton, systemImage: "arrow.clockwise")
                }
                .compatibleButtonStyle()
                .disabled(isCodexAuthInProgress)

                if codexAuthStatus.accountID != nil {
                    Button {
                        signOutCodex()
                    } label: {
                        Label(Strings.PromptToolsSettings.codexSignOutButton, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .compatibleButtonStyle()
                    .disabled(isCodexAuthInProgress)
                }

                if isCodexAuthInProgress {
                    ProgressView()
                        .scaleEffect(Constants.scaleTiny)
                }

                if let codexLoginMessage {
                    Text(codexLoginMessage)
                        .font(.pingFang(.caption))
                        .foregroundStyle(codexLoginMessage.contains("失败") ? .red : .secondary)
                }
            }
        }
    }

    var body: some View {
        SettingsFormContainer {
                // Tool 列表
                SettingsSection(title: "工具列表") {
                    if tools.filter({ !$0.isSmart }).isEmpty {
                        Text(Strings.PromptToolsSettings.emptyToolsMessage)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tools.filter { !$0.isSmart }) { tool in
                            ToolRowView(tool: tool, onEdit: {
                                // 如果是云端工具，提示复制后编辑
                                if tool.isCloudManaged {
                                    // 创建本地副本
                                    let localCopy = PromptTool(
                                        name: tool.name + Strings.PromptToolsSettings.toolCopySuffix,
                                        prompt: tool.prompt,
                                        capabilities: tool.capabilities,
                                        shortcutKeyCode: 0,  // 清空快捷键避免冲突
                                        shortcutModifiers: 0,
                                        source: .custom  // 标记为本地工具
                                    )
                                    editorMode = .edit(localCopy)
                                } else {
                                    editorMode = .edit(tool)
                                }
                            }, onDelete: {
                                Task {
                                    try? await dependencies.promptToolCoordinator.deleteTool(id: ToolID(tool.id))
                                    loadTools()
                                }
                            })
                        }
                    }

                    HStack {
                        Button {
                            editorMode = .new
                        } label: {
                            Label("新建工具", systemImage: "plus")
                        }
                        .compatibleButtonStyle(prominent: true)
                        .help("创建一个文字处理工具")

                        Spacer()

                        Button("恢复默认") {
                            Task {
                                try? await dependencies.promptToolCoordinator.restoreDefaultTools()
                                loadTools()
                            }
                        }
                        .compatibleButtonStyle()
                        .help("恢复系统预设的 Prompt Tools")
                        .foregroundStyle(.secondary)
                    }
                }

                // AI 服务配置
                SettingsSection(title: "服务配置") {
                    DisclosureGroup("账号与模型", isExpanded: $connectionExpanded) {
                    Picker(Strings.PromptToolsSettings.aiServicePicker, selection: $selectedService) {
                        ForEach(AIServiceType.allCases, id: \.rawValue) { service in
                            Text(service.displayName).tag(service)
                        }
                    }
                    .help(Strings.PromptToolsSettings.aiServiceHelp)
                    .onChange(of: selectedService) { _, newValue in
                        guard connectionLoaded else { return }
                        // 从缓存中加载对应服务的 API Key（不触发 Keychain 读取）
                        loadServiceConfigFromCache()
                        apiSettingsService.updateCurrentServiceType(newValue)
                        if newValue == .codex {
                            refreshCodexAuthStatus()
                        }
                    }

                    if selectedService.requiresAPIKey {
                        SecureField(Strings.PromptToolsSettings.apiKeyPlaceholder, text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .help(Strings.PromptToolsSettings.apiKeyHelp(selectedService.displayName))
                            .onSubmit {
                                saveAllKeys()
                            }
                    }

                    if selectedService == .codex {
                        codexAuthSection
                    }

                    TextField(Strings.PromptToolsSettings.modelPlaceholder, text: $modelName)
                        .textFieldStyle(.roundedBorder)
                        .help(Strings.PromptToolsSettings.modelHelp(selectedService.displayName, selectedService.defaultModel))
                        .onSubmit {
                            saveAllKeys()
                        }

                    HStack {
                        Button(action: saveAllKeys) {
                            Label(
                                saveSuccess ? Strings.PromptToolsSettings.saveButtonSaved : Strings.PromptToolsSettings.saveButtonDefault,
                                systemImage: saveSuccess ? "checkmark.circle.fill" : "square.and.arrow.down"
                            )
                        }
                        .compatibleButtonStyle(prominent: true)
                        .disabled(!hasUnsavedChanges)
                        .help(Strings.PromptToolsSettings.saveButtonHelp)

                        if hasUnsavedChanges {
                            Text(Strings.PromptToolsSettings.unsavedChanges)
                                .font(.pingFang(.caption))
                                .foregroundStyle(.orange)
                        }

                        Spacer()

                        Button(Strings.PromptToolsSettings.testConnectionButton) {
                            testConnection()
                        }
                        .compatibleButtonStyle()
                        .disabled(isTestingConnection || (selectedService.requiresAPIKey && apiKey.isEmpty))
                        .help(Strings.PromptToolsSettings.testConnectionHelp)

                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(Constants.scaleTiny)
                        }

                        if let result = connectionTestResult {
                            Text(result)
                                .font(.pingFang(.caption))
                                .foregroundStyle(result.contains("成功") ? .green : .red)
                        }
                    }
                }

                }


            }

        .onAppear {
            loadCurrentServiceSelection()
            loadTools()

        }
        .onChange(of: connectionExpanded) { _, expanded in
            guard expanded, !connectionLoaded else { return }
            connectionLoaded = true
            loadAllSettings()
            if selectedService == .codex { refreshCodexAuthStatus() }
        }

        .sheet(item: $editorMode) { mode in
            PromptToolEditorView(
                tool: mode.tool,
                onSave: { tool in
                    Task {
                        do {
                            switch mode {
                            case .new:
                                try await dependencies.promptToolCoordinator.createTool(
                                    name: tool.name,
                                    prompt: tool.prompt,
                                    capabilities: tool.capabilities,
                                    shortcutKeyCode: tool.shortcutKeyCode,
                                    shortcutModifiers: tool.shortcutModifiers
                                )
                            case .edit:
                                try await dependencies.promptToolCoordinator.updateTool(tool)
                            }

                            await MainActor.run {
                                loadTools()
                                editorMode = nil
                            }
                        } catch {
                            await MainActor.run {
                                toolSaveErrorMessage = "保存失败：\(error.localizedDescription)"
                                showToolSaveError = true
                            }
                        }
                    }
                },
                onCancel: {
                    editorMode = nil
                }
            )
        }
        .alert("工具保存失败", isPresented: $showToolSaveError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(toolSaveErrorMessage)
        }
    }

    // MARK: - Private Methods

    private func loadTools() {
        Task {
            tools = (try? await dependencies.promptToolCoordinator.loadTools()) ?? []
        }
    }

    /// 加载当前选中的 AI 服务
    private func loadCurrentServiceSelection() {
        selectedService = apiSettingsService.currentServiceType
    }

    /// 批量加载所有密钥（单次授权）
    private func loadAllSettings() {
        cachedAPIKeys = apiSettingsService.loadAllAPIKeys()
        cachedModelNames = apiSettingsService.loadAllModelNames()
        loadServiceConfigFromCache()
    }

    /// 从缓存中加载服务配置（用于服务切换时，不触发额外读取）
    private func loadServiceConfigFromCache() {
        let loadedKey = cachedAPIKeys[selectedService] ?? apiSettingsService.apiKey(for: selectedService)
        let loadedModel = cachedModelNames[selectedService] ?? apiSettingsService.modelName(for: selectedService)
        apiKey = loadedKey
        modelName = loadedModel
        originalApiKey = loadedKey  // 记录原始值
        originalModelName = loadedModel
    }

    /// 批量保存所有密钥（单次授权）
    private func saveAllKeys() {
        // 保存 AI 服务 API Key 到 Keychain（触发授权）
        if selectedService.requiresAPIKey {
            _ = apiSettingsService.saveAPIKey(apiKey, for: selectedService)
            cachedAPIKeys[selectedService] = apiKey
        }

        apiSettingsService.saveModelName(modelName, for: selectedService)
        let normalizedModel = selectedService.selectedModel
        cachedModelNames[selectedService] = normalizedModel

        // 更新原始值（保存后，当前值就是新的原始值）
        originalApiKey = apiKey
        originalModelName = normalizedModel
        modelName = normalizedModel

        // 更新状态
        saveSuccess = true

        // 2 秒后重置成功状态
        Task {
            try? await Task.sleep(nanoseconds: BusinessRules.Animation.successDisplayDuration)
            await MainActor.run {
                saveSuccess = false
            }
        }
    }

    private func refreshCodexAuthStatus() {
        codexAuthStatus = apiSettingsService.codexAuthStatus
    }

    private func startCodexLogin() {
        isCodexAuthInProgress = true
        codexLoginMessage = Strings.PromptToolsSettings.codexLoginOpening

        Task {
            do {
                try await apiSettingsService.startCodexBrowserLogin()
                await MainActor.run {
                    codexLoginMessage = Strings.PromptToolsSettings.codexLoginStarted
                    refreshCodexAuthStatus()
                    isCodexAuthInProgress = false
                }
            } catch {
                await MainActor.run {
                    codexLoginMessage = "\(Strings.PromptToolsSettings.codexLoginFailedPrefix): \(error.localizedDescription)"
                    refreshCodexAuthStatus()
                    isCodexAuthInProgress = false
                }
            }
        }
    }

    private func signOutCodex() {
        do {
            try apiSettingsService.signOutCodex()
            codexLoginMessage = Strings.PromptToolsSettings.codexSignedOut
        } catch {
            codexLoginMessage = "\(Strings.PromptToolsSettings.codexSignOutFailedPrefix): \(error.localizedDescription)"
        }
        refreshCodexAuthStatus()
    }

    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil

        Task {
            do {
                _ = try await apiSettingsService.testConnection()
                await MainActor.run {
                    connectionTestResult = Strings.PromptToolsSettings.connectionSuccess
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = "❌ \(error.localizedDescription)"
                    isTestingConnection = false
                }
            }
        }
    }
}

// MARK: - Tool Row View

struct ToolRowView: View {
    let tool: PromptTool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                // 来源图标
                if tool.source == .langfuse {
                    Text("☁️")
                        .font(.pingFang(.caption))
                } else if tool.source == .custom {
                    Text("📝")
                        .font(.pingFang(.caption))
                }

                Text(tool.name)
                    .fontWeight(.medium)

                // SMART 徽章（Smart AI 工具）
                if tool.isSmart {
                    Text("SMART")
                        .font(.pingFang(.caption2))
                        .padding(.horizontal, Constants.spacing4)
                        .padding(.vertical, Constants.spacing4)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(Constants.PromptToolsEditor.tagCornerRadius)
                        .help("AI-powered context-aware tool recommendation")
                }

                if tool.isDefault {
                    Text("默认")
                        .font(.pingFang(.caption2))
                        .padding(.horizontal, Constants.spacing4)
                        .padding(.vertical, Constants.spacing4)
                        .background(Color.blue.opacity(Constants.opacity20))
                        .cornerRadius(Constants.PromptToolsEditor.tagCornerRadius)
                }

                if tool.isCloudManaged {
                    Text("只读")
                        .font(.pingFang(.caption2))
                        .padding(.horizontal, Constants.spacing4)
                        .padding(.vertical, Constants.spacing4)
                        .background(Color.orange.opacity(Constants.opacity20))
                        .foregroundStyle(.orange)
                        .cornerRadius(Constants.PromptToolsEditor.tagCornerRadius)
                }

                Spacer()

                // 操作按钮
                HStack(spacing: 8) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .disabled(tool.isCloudManaged || tool.isSmart)  // 云端工具和 Smart AI 不可删除
                    .help(tool.isSmart ? "Smart AI is a system tool and cannot be deleted" : "")
                }
            }

            // Prompt 预览
            Text(tool.prompt)
                .font(.pingFang(.caption))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !tool.capabilities.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tool.capabilities, id: \.rawValue) { capability in
                        Text(capability.displayName)
                            .font(.pingFang(.caption2))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
            }

            // 快捷键
            Text(tool.shortcutDisplayString)
                .font(.pingFang(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Constants.spacing8)
        .padding(.horizontal, Constants.spacing12)
        .background(.primary.opacity(0.025), in: .rect(cornerRadius: 12))
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        PromptToolsSettingsView()
            .frame(width: Constants.DialogWindow.promptToolEditor.width, height: Constants.DialogWindow.promptToolEditor.height)
    } else {
        Text("需要 macOS 13.0+")
    }
}
