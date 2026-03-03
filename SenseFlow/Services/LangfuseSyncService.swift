//
//  LangfuseSyncService.swift
//  SenseFlow
//
//  Created on 2026-01-27.
//  Langfuse Prompt 同步服务
//

import Foundation
import Combine

/// Langfuse Prompt 同步服务
/// 负责定期从 Langfuse 拉取 prompts 并更新本地缓存
class LangfuseSyncService: ObservableObject {

    // MARK: - Singleton

    static let shared = LangfuseSyncService()

    // MARK: - Properties

    private let promptService = LangfusePromptService.shared
    private let databaseManager = DatabaseManager.shared
    private var syncTimer: Timer?
    private var isSyncing = false

    /// 同步状态
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date?
    @Published var lastSyncError: String?

    /// 内存缓存（60秒 TTL）
    private var memoryCache: [String: CachedPromptTool] = [:]
    private let cacheQueue = DispatchQueue(label: "com.senseflow.promptcache")
    private let cacheTTL: TimeInterval = BusinessRules.Langfuse.promptCacheTTL

    // MARK: - Configuration

    /// 同步间隔（默认 5 分钟）
    var syncInterval: TimeInterval {
        get {
            UserDefaults.standard.double(forKey: "langfuseSyncInterval").nonZero ?? BusinessRules.Langfuse.defaultSyncInterval
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "langfuseSyncInterval")
            restartSyncTimer()
        }
    }

    /// 是否启用自动同步
    var isSyncEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "langfuseSyncEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "langfuseSyncEnabled")
            if newValue {
                startAutoSync()
            } else {
                stopAutoSync()
            }
        }
    }

    /// 使用的标签（production/staging）
    var activeLabel: String {
        get {
            UserDefaults.standard.string(forKey: "langfuseActiveLabel") ?? "production"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "langfuseActiveLabel")
        }
    }

    // MARK: - Initialization

    private init() {
        // 私有初始化
    }

    // MARK: - Public Methods

    /// 启动自动同步
    func startAutoSync() {
        guard isSyncEnabled else {
            print("⚠️ Langfuse 同步未启用")
            return
        }

        stopAutoSync()

        // 立即执行一次同步
        Task {
            await sync()
        }

        // 启动定时器
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.sync()
            }
        }

        print("✅ Langfuse 自动同步已启动（间隔: \(syncInterval)秒）")
    }

    /// 停止自动同步
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("⏹️ Langfuse 自动同步已停止")
    }

    /// 重启同步定时器（配置变更时调用）
    private func restartSyncTimer() {
        if isSyncEnabled {
            startAutoSync()
        }
    }

    /// 手动触发同步（从 UI 调用）
    func syncFromRemote() async throws {
        await sync()

        if let error = lastSyncError {
            throw NSError(domain: "LangfuseSyncService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: error
            ])
        }
    }

    /// 手动触发同步
    func sync() async {
        guard !isSyncing else {
            print("⚠️ 同步正在进行中，跳过")
            return
        }

        isSyncing = true
        syncStatus = .syncing

        do {
            try await performSync()
            updateSyncSuccess()
        } catch {
            handleSyncError(error)
        }

        isSyncing = false
    }

    /// 执行同步流程
    private func performSync() async throws {
        print("🔄 开始同步 Langfuse prompts...")

        let remoteMeta = try await fetchRemotePrompts()
        let localTools = fetchLocalTools()
        let changes = comparePrompts(remote: remoteMeta, local: localTools)

        try await applyChanges(changes)
        clearMemoryCache()

        print("✅ Langfuse 同步完成")
    }

    /// 获取远程 prompts
    private func fetchRemotePrompts() async throws -> [LangfusePromptMeta] {
        let remoteMeta = try await promptService.listPrompts(limit: BusinessRules.Langfuse.defaultPromptLimit)
        print("📥 获取到 \(remoteMeta.count) 个远程 prompts")
        return remoteMeta
    }

    /// 获取本地工具
    private func fetchLocalTools() -> [PromptTool] {
        let localTools = databaseManager.fetchLangfuseTools()
        print("📦 本地有 \(localTools.count) 个 Langfuse 工具")
        return localTools
    }

    /// 应用变更
    private func applyChanges(_ changes: (newTools: [LangfusePromptMeta], updatedTools: [LangfusePromptMeta], deletedTools: [PromptTool])) async throws {
        let (newTools, updatedTools, deletedTools) = changes
        print("📊 新增: \(newTools.count), 更新: \(updatedTools.count), 删除: \(deletedTools.count)")

        try await syncNewAndUpdatedTools(newTools: newTools, updatedTools: updatedTools)
        deleteRemovedTools(deletedTools)
    }

    /// 更新同步成功状态
    private func updateSyncSuccess() {
        lastSyncTime = Date()
        lastSyncError = nil
        syncStatus = .success
    }

    /// 处理同步错误
    private func handleSyncError(_ error: Error) {
        print("❌ Langfuse 同步失败: \(error)")
        lastSyncError = error.localizedDescription
        syncStatus = .failed(error.localizedDescription)
    }

    /// 从缓存获取 prompt（三层缓存策略）
    func getPrompt(name: String, label: String = "production") async throws -> PromptTool? {
        let cacheKey = "\(name):\(label)"

        // 1. 检查内存缓存
        if let cached = cacheQueue.sync(execute: { memoryCache[cacheKey] }),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            print("📦 [Cache Hit] 内存缓存: \(name)")
            return cached.tool
        }

        // 2. 检查数据库缓存
        if let tool = databaseManager.fetchToolByLangfuseName(name) {
            print("📦 [Cache Hit] 数据库缓存: \(name)")
            updateMemoryCache(tool, key: cacheKey)
            return tool
        }

        // 3. 从 Langfuse API 获取
        print("🌐 [Cache Miss] 从 Langfuse 获取: \(name)")
        let langfusePrompt = try await promptService.getPrompt(name: name, label: label)
        let tool = convertToPromptTool(langfusePrompt)

        // 保存到数据库
        _ = databaseManager.insertOrUpdatePromptTool(tool)

        // 更新内存缓存
        updateMemoryCache(tool, key: cacheKey)

        return tool
    }

    /// 清除所有缓存
    func clearAllCaches() {
        clearMemoryCache()
        promptService.clearCache()
        print("🧹 已清除所有缓存")
    }

    /// 获取当前配置
    /// - Parameters:
    ///   - preloadedPublicKey: 预加载的 Public Key（可选，避免重复读取 Keychain）
    ///   - preloadedSecretKey: 预加载的 Secret Key（可选，避免重复读取 Keychain）
    /// - Returns: 配置元组
    func getConfiguration(
        preloadedPublicKey: String? = nil,
        preloadedSecretKey: String? = nil
    ) -> (
        enabled: Bool,
        publicKey: String,
        secretKey: String,
        syncInterval: TimeInterval,
        activeLabel: String,
        lastSyncTime: Date?
    ) {
        // 读取顺序：预加载参数 → UserDefaults
        let publicKey = preloadedPublicKey ?? UserDefaults.standard.string(forKey: "langfusePublicKey") ?? ""
        let secretKey = preloadedSecretKey ?? UserDefaults.standard.string(forKey: "langfuseSecretKey") ?? ""

        return (
            enabled: isSyncEnabled,
            publicKey: publicKey,
            secretKey: secretKey,
            syncInterval: syncInterval,
            activeLabel: activeLabel,
            lastSyncTime: lastSyncTime
        )
    }

    /// 更新配置
    func updateConfiguration(
        enabled: Bool,
        publicKey: String,
        secretKey: String,
        syncInterval: TimeInterval,
        activeLabel: String
    ) {
        // 保存密钥到 UserDefaults（不用 Keychain，避免授权提示）
        if !publicKey.isEmpty && !secretKey.isEmpty {
            UserDefaults.standard.set(publicKey, forKey: "langfusePublicKey")
            UserDefaults.standard.set(secretKey, forKey: "langfuseSecretKey")
        }

        // 更新配置
        self.isSyncEnabled = enabled
        self.syncInterval = syncInterval
        self.activeLabel = activeLabel

        print("✅ Langfuse 配置已更新")
    }

    // MARK: - Private Methods

    /// 比对远程和本地 prompts
    private func comparePrompts(
        remote: [LangfusePromptMeta],
        local: [PromptTool]
    ) -> (newTools: [LangfusePromptMeta], updatedTools: [LangfusePromptMeta], deletedTools: [PromptTool]) {
        var newTools: [LangfusePromptMeta] = []
        var updatedTools: [LangfusePromptMeta] = []

        // 找出新增和更新的工具
        for remoteMeta in remote {
            // 只同步指定标签的工具
            guard remoteMeta.labels.contains(activeLabel) else {
                continue
            }

            if let localTool = local.first(where: { $0.langfuseName == remoteMeta.name }) {
                // 检查是否需要更新
                if shouldUpdatePrompt(remote: remoteMeta, local: localTool) {
                    updatedTools.append(remoteMeta)
                }
            } else {
                newTools.append(remoteMeta)
            }
        }

        // 找出已删除的工具
        let remoteNames = Set(remote.map { $0.name })
        let deletedTools = local.filter { tool in
            guard let name = tool.langfuseName else { return false }
            return !remoteNames.contains(name)
        }

        return (newTools, updatedTools, deletedTools)
    }

    /// 判断是否应该更新 prompt
    private func shouldUpdatePrompt(remote: LangfusePromptMeta, local: PromptTool) -> Bool {
        return hasNewerVersion(remote: remote, local: local) ||
               hasNewerTimestamp(remote: remote, local: local)
    }

    /// 检查远程版本是否更新
    private func hasNewerVersion(remote: LangfusePromptMeta, local: PromptTool) -> Bool {
        let remoteVersion = remote.latestVersion ?? 0
        let localVersion = local.langfuseVersion ?? 0
        return remoteVersion > localVersion
    }

    /// 检查远程时间戳是否更新
    private func hasNewerTimestamp(remote: LangfusePromptMeta, local: PromptTool) -> Bool {
        let localTimestamp = local.lastSyncedAt ?? Date.distantPast
        return remote.lastUpdatedAt > localTimestamp
    }

    /// 同步新增和更新的工具
    private func syncNewAndUpdatedTools(
        newTools: [LangfusePromptMeta],
        updatedTools: [LangfusePromptMeta]
    ) async throws {
        let allTools = newTools + updatedTools

        for meta in allTools {
            do {
                // 获取完整的 prompt 内容
                let langfusePrompt = try await promptService.getPrompt(
                    name: meta.name,
                    label: activeLabel
                )

                // 转换为 PromptTool
                let tool = convertToPromptTool(langfusePrompt)

                // 保存到数据库
                _ = databaseManager.insertOrUpdatePromptTool(tool)

                let versionStr = meta.latestVersion.map { "v\($0)" } ?? "unknown"
                print("✅ 同步工具: \(meta.name) (\(versionStr))")

            } catch {
                print("❌ 同步工具失败: \(meta.name) - \(error)")
            }
        }
    }

    /// 删除已移除的工具
    private func deleteRemovedTools(_ tools: [PromptTool]) {
        for tool in tools {
            _ = databaseManager.deletePromptTool(id: tool.id)
            print("🗑️ 删除工具: \(tool.name)")
        }
    }

    /// 将 LangfusePrompt 转换为 PromptTool
    private func convertToPromptTool(_ langfusePrompt: LangfusePrompt) -> PromptTool {
        return PromptTool(
            name: langfusePrompt.name,
            prompt: langfusePrompt.prompt,
            capabilities: PromptToolCapability.infer(fromName: langfusePrompt.name, prompt: langfusePrompt.prompt),
            shortcutKeyCode: 0,
            shortcutModifiers: 0,
            isDefault: false,
            source: .langfuse,
            langfuseName: langfusePrompt.name,
            langfuseVersion: langfusePrompt.version,
            langfuseLabels: langfusePrompt.labels,
            lastSyncedAt: Date()
        )
    }

    /// 更新内存缓存
    private func updateMemoryCache(_ tool: PromptTool, key: String) {
        cacheQueue.sync {
            memoryCache[key] = CachedPromptTool(tool: tool, timestamp: Date())
        }
    }

    /// 清除内存缓存
    private func clearMemoryCache() {
        cacheQueue.sync {
            memoryCache.removeAll()
        }
    }
}

// MARK: - Models

/// 同步状态
enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case failed(String)

    var displayText: String {
        switch self {
        case .idle:
            return "待同步"
        case .syncing:
            return "同步中..."
        case .success:
            return "同步成功"
        case .failed(let error):
            return "同步失败: \(error)"
        }
    }
}

/// 缓存的 PromptTool
struct CachedPromptTool {
    let tool: PromptTool
    let timestamp: Date
}

// MARK: - Extensions

extension Double {
    var nonZero: Double? {
        self > 0 ? self : nil
    }
}
