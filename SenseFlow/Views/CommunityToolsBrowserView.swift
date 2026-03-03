//
//  CommunityToolsBrowserView.swift
//  SenseFlow
//
//  Created on 2026-01-26.
//

import SwiftUI

/// 社区工具浏览器
struct CommunityToolsBrowserView: View {

    // MARK: - State

    @State private var tools: [RemoteTool] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var updateInfo: UpdateInfo?
    @State private var showingUpdateAlert = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerView

            // 更新提示
            if let info = updateInfo, info.hasUpdates {
                updateBanner(info: info)
            }

            // 工具列表
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else {
                toolsList
            }
        }
        .task {
            await loadTools()
            await checkForUpdates()
        }
        .alert("发现更新", isPresented: $showingUpdateAlert) {
            Button("稍后") { }
            Button("立即更新") {
                Task {
                    await installAllUpdates()
                }
            }
        } message: {
            if let info = updateInfo {
                Text("发现 \(info.newTools.count) 个新工具和 \(info.updatedTools.count) 个更新")
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("社区工具库")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    Task {
                        await checkForUpdates()
                    }
                } label: {
                    Label("检查更新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            // 搜索框
            TextField("搜索工具...", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func updateBanner(info: UpdateInfo) -> some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("发现 \(info.newTools.count + info.updatedTools.count) 个更新")
                    .font(.headline)
                Text("\(info.newTools.count) 个新工具，\(info.updatedTools.count) 个工具更新")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("立即更新") {
                Task {
                    await installAllUpdates()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.blue.opacity(Constants.opacity10))
        .cornerRadius(Constants.cornerRadiusSmall)
        .padding(.horizontal)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在加载社区工具...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(message)
                .foregroundColor(.secondary)

            Button("重试") {
                Task {
                    await loadTools()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredTools) { tool in
                    ToolCard(tool: tool) {
                        installTool(tool)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Computed Properties

    private var filteredTools: [RemoteTool] {
        if searchText.isEmpty {
            return tools
        }
        return tools.filter { tool in
            tool.title.localizedCaseInsensitiveContains(searchText) ||
            (tool.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // MARK: - Methods

    private func loadTools() async {
        isLoading = true
        errorMessage = nil

        do {
            let service = ToolUpdateService.shared
            let info = try await service.checkForUpdates()
            tools = info.availableTools
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func checkForUpdates() async {
        do {
            let service = ToolUpdateService.shared
            updateInfo = try await service.checkForUpdates()

            if let info = updateInfo, info.hasUpdates {
                showingUpdateAlert = true
            }
        } catch {
            print("检查更新失败: \(error)")
        }
    }

    private func installTool(_ tool: RemoteTool) {
        let success = ToolUpdateService.shared.installTool(tool)

        if success {
            NotificationService.shared.showSuccess(
                title: "安装成功",
                body: "工具「\(tool.title)」已添加到你的工具库"
            )
        } else {
            NotificationService.shared.showError(
                title: "安装失败",
                body: "无法安装工具「\(tool.title)」"
            )
        }
    }

    private func installAllUpdates() async {
        guard let info = updateInfo else { return }

        let allTools = info.newTools + info.updatedTools
        let result = await ToolUpdateService.shared.installTools(allTools)

        NotificationService.shared.showSuccess(
            title: "更新完成",
            body: "成功安装 \(result.success) 个工具"
        )

        // 重新加载
        await loadTools()
        updateInfo = nil
    }
}

// MARK: - Tool Card

struct ToolCard: View {

    let tool: RemoteTool
    let onInstall: () -> Void

    @State private var isInstalled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和作者
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.title)
                        .font(.headline)

                    HStack(spacing: 8) {
                        if let author = tool.author.name {
                            Label(author, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if tool.author.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }

                        Label("\(tool.voteCount)", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    onInstall()
                    isInstalled = true
                } label: {
                    if isInstalled {
                        Label("已安装", systemImage: "checkmark")
                    } else {
                        Label("安装", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isInstalled)
            }

            // 描述
            if let description = tool.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // 标签
            if !tool.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tool.tags, id: \.tagId) { tagWrapper in
                            TagChip(tag: tagWrapper.tag)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(Constants.cornerRadiusMedium)
        .onAppear {
            checkIfInstalled()
        }
    }

    private func checkIfInstalled() {
        let installedTools = DatabaseManager.shared.fetchAllPromptTools()
        isInstalled = installedTools.contains { $0.remoteId == tool.id }
    }
}

// MARK: - Tag Chip

struct TagChip: View {

    let tag: RemoteTag.TagInfo

    var body: some View {
        Text(tag.name)
            .font(.caption)
            .padding(.horizontal, Constants.spacing8)
            .padding(.vertical, Constants.spacing4)
            .background(Color(hex: tag.color).opacity(0.2))
            .foregroundColor(Color(hex: tag.color))
            .cornerRadius(Constants.PromptToolsEditor.tagCornerRadius)
    }
}

// MARK: - Preview

#Preview {
    CommunityToolsBrowserView()
        .frame(
            width: Constants.DialogWindow.communityBrowser.width,
            height: Constants.DialogWindow.communityBrowser.height
        )
}
