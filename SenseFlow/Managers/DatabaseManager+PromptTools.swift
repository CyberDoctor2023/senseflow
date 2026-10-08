//
//  DatabaseManager+PromptTools.swift
//  SenseFlow
//
//  Created on 2026-01-26.
//

import Foundation
import SQLite

extension DatabaseManager {

    // MARK: - Community Tools Methods

    /// 获取所有社区工具
    internal func fetchCommunityTools() -> [PromptTool] {
        return fetchAllPromptTools().filter { $0.source == .community }
    }

    /// 根据远程 ID 获取工具
    internal func fetchToolByRemoteId(_ remoteId: String) -> PromptTool? {
        if !onStoreQueue { return storeQueue.sync { self.fetchToolByRemoteId(remoteId) } }
        guard let db = db else { return nil }

        do {
            let query = promptToolsTable.filter(toolRemoteId == remoteId)
            if let row = try db.pluck(query) {
                return parsePromptToolFromRow(row)
            }
        } catch {
            print("❌ 查询工具失败: \(error)")
        }

        return nil
    }

    // MARK: - Langfuse Tools Methods

    /// 获取所有 Langfuse 工具
    internal func fetchLangfuseTools() -> [PromptTool] {
        return fetchAllPromptTools().filter { $0.source == .langfuse }
    }

    /// 根据 Langfuse 名称获取工具
    internal func fetchToolByLangfuseName(_ name: String) -> PromptTool? {
        if !onStoreQueue { return storeQueue.sync { self.fetchToolByLangfuseName(name) } }
        guard let db = db else { return nil }

        do {
            let query = promptToolsTable.filter(toolLangfuseName == name)
            if let row = try db.pluck(query) {
                return parsePromptToolFromRow(row)
            }
        } catch {
            print("❌ 查询 Langfuse 工具失败: \(error)")
        }

        return nil
    }

    /// 批量插入或更新 Langfuse 工具
    internal func syncLangfuseTools(_ tools: [PromptTool]) -> (success: Int, failed: Int) {
        var successCount = 0
        var failedCount = 0

        for tool in tools {
            if insertOrUpdatePromptTool(tool) {
                successCount += 1
            } else {
                failedCount += 1
            }
        }

        return (successCount, failedCount)
    }

    /// 删除所有 Langfuse 工具（用于清理已删除的远程工具）
    internal func deleteLangfuseToolsNotIn(names: [String]) -> Int {
        if !onStoreQueue { return storeQueue.sync { self.deleteLangfuseToolsNotIn(names: names) } }
        guard let db = db else { return 0 }

        do {
            let placeholders = names.map { _ in "?" }.joined(separator: ",")
            let sql = """
                DELETE FROM prompt_tools
                WHERE source = 'langfuse'
                AND langfuse_name NOT IN (\(placeholders))
            """

            let statement = try db.prepare(sql)
            try statement.run(names)

            let deletedCount = db.changes
            print("🗑️ 删除了 \(deletedCount) 个已不存在的 Langfuse 工具")
            return deletedCount
        } catch {
            print("❌ 删除 Langfuse 工具失败: \(error)")
            return 0
        }
    }

    /// 插入或更新工具（支持远程字段）
    internal func insertOrUpdatePromptTool(_ tool: PromptTool) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.insertOrUpdatePromptTool(tool) } }
        // 如果有远程 ID，先检查是否已存在
        if let remoteId = tool.remoteId, let existing = fetchToolByRemoteId(remoteId) {
            // 更新现有工具（保持原有 ID）
            let updatedTool = PromptTool(
                id: existing.id,
                name: tool.name,
                prompt: tool.prompt,
                capabilities: tool.capabilities,
                shortcutKeyCode: tool.shortcutKeyCode,
                shortcutModifiers: tool.shortcutModifiers,
                isDefault: tool.isDefault,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                source: tool.source,
                remoteId: tool.remoteId,
                remoteAuthor: tool.remoteAuthor,
                remoteVotes: tool.remoteVotes,
                remoteUpdatedAt: tool.remoteUpdatedAt
            )
            return updatePromptTool(updatedTool)
        } else {
            // 插入新工具
            return insertPromptTool(tool)
        }
    }
    /// Retrieves one tool by its primary key without loading all tool prompts.
    func fetchPromptTool(id: UUID) throws -> PromptTool? {
        if !onStoreQueue { return try storeQueue.sync { try self.fetchPromptTool(id: id) } }
        guard let db else { throw DocumentStoreError.unavailable }
        return try db.pluck(promptToolsTable.filter(toolId == id.uuidString)).map(parsePromptToolFromRow)
    }

    // MARK: - Prompt Tools CRUD Operations

    /// 获取所有 Prompt Tools
    func fetchAllPromptTools() -> [PromptTool] {
        if !onStoreQueue { return storeQueue.sync { self.fetchAllPromptTools() } }
        guard let db = db else { return [] }

        do {
            var tools: [PromptTool] = []
            for row in try db.prepare(promptToolsTable.order(toolCreatedAt.asc)) {
                // 使用扩展中的 parsePromptTool 方法来正确解析所有字段
                let tool = parsePromptToolFromRow(row)
                tools.append(tool)
            }
            return tools
        } catch {
            handleDatabaseError("获取 Prompt Tools 失败", error: error)
            return []
        }
    }

    /// 从数据库行解析 PromptTool（包含所有字段）
    internal func parsePromptToolFromRow(_ row: Row) -> PromptTool {
        let id = UUID(uuidString: try! row.get(toolId)) ?? UUID()
        let name = try! row.get(toolName)
        let prompt = try! row.get(toolPrompt)
        let shortcutKeyCode = UInt16(try! row.get(toolShortcutKeyCode))
        let shortcutModifiers = UInt32(try! row.get(toolShortcutModifiers))
        let isDefault = try! row.get(toolIsDefault)
        let createdAt = Date(timeIntervalSince1970: try! row.get(toolCreatedAt))
        let updatedAt = Date(timeIntervalSince1970: try! row.get(toolUpdatedAt))

        // v0.4 字段（可能不存在）
        let sourceString = (try? row.get(toolSource)) ?? "custom"
        let source = ToolSource(rawValue: sourceString) ?? .custom
        let remoteId = try? row.get(toolRemoteId)
        let remoteAuthor = try? row.get(toolRemoteAuthor)
        let remoteVotes = (try? row.get(toolRemoteVotes)) ?? 0
        let remoteUpdatedAtTimestamp = try? row.get(toolRemoteUpdatedAt)
        let remoteUpdatedAt = remoteUpdatedAtTimestamp.map { Date(timeIntervalSince1970: $0) }

        // v0.5 Langfuse 字段（可能不存在）
        let langfuseName = try? row.get(toolLangfuseName)
        let langfuseVersion = try? row.get(toolLangfuseVersion)
        let langfuseLabelsJson = try? row.get(toolLangfuseLabels)
        let langfuseLabels = parseLangfuseLabelsJson(langfuseLabelsJson)
        let lastSyncedAtTimestamp = try? row.get(toolLastSyncedAt)
        let lastSyncedAt = lastSyncedAtTimestamp.map { Date(timeIntervalSince1970: $0) }
        let capabilitiesJSON = try? row.get(toolCapabilities)
        let parsedCapabilities = parseCapabilitiesJson(capabilitiesJSON)
        let effectiveCapabilities = parsedCapabilities.isEmpty
            ? PromptToolCapability.infer(fromName: name, prompt: prompt)
            : parsedCapabilities

        return PromptTool(
            id: id,
            name: name,
            prompt: prompt,
            capabilities: effectiveCapabilities,
            shortcutKeyCode: shortcutKeyCode,
            shortcutModifiers: shortcutModifiers,
            isDefault: isDefault,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: source,
            remoteId: remoteId,
            remoteAuthor: remoteAuthor,
            remoteVotes: remoteVotes,
            remoteUpdatedAt: remoteUpdatedAt,
            langfuseName: langfuseName,
            langfuseVersion: langfuseVersion,
            langfuseLabels: langfuseLabels,
            lastSyncedAt: lastSyncedAt
        )
    }

    /// 解析 Langfuse labels JSON 字符串
    private func parseLangfuseLabelsJson(_ json: String?) -> [String] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let labels = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return labels
    }

    /// 解析 capabilities JSON 字符串
    private func parseCapabilitiesJson(_ json: String?) -> [PromptToolCapability] {
        guard let json,
              let data = json.data(using: .utf8),
              let capabilities = try? JSONDecoder().decode([PromptToolCapability].self, from: data) else {
            return []
        }
        return Array(Set(capabilities)).sorted(by: { $0.rawValue < $1.rawValue })
    }

    /// 将 Langfuse labels 编码为 JSON 字符串
    private func encodeLangfuseLabels(_ labels: [String]) -> String? {
        guard !labels.isEmpty,
              let data = try? JSONEncoder().encode(labels),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// 将 capabilities 编码为 JSON 字符串
    private func encodeCapabilities(_ capabilities: [PromptToolCapability]) -> String? {
        let normalized = Array(Set(capabilities)).sorted(by: { $0.rawValue < $1.rawValue })
        guard !normalized.isEmpty,
              let data = try? JSONEncoder().encode(normalized),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// 插入新的 Prompt Tool
    @discardableResult
    func insertPromptTool(_ tool: PromptTool) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.insertPromptTool(tool) } }
        guard let db = db else { return false }

        do {
            // 准备 Langfuse labels JSON
            let labelsJson = encodeLangfuseLabels(tool.langfuseLabels)
            let capabilitiesJson = encodeCapabilities(tool.capabilities)

            try db.run(promptToolsTable.insert(
                toolId <- tool.id.uuidString,
                toolName <- tool.name,
                toolPrompt <- tool.prompt,
                toolShortcutKeyCode <- Int(tool.shortcutKeyCode),
                toolShortcutModifiers <- Int(tool.shortcutModifiers),
                toolIsDefault <- tool.isDefault,
                toolCreatedAt <- tool.createdAt.timeIntervalSince1970,
                toolUpdatedAt <- tool.updatedAt.timeIntervalSince1970,
                toolSource <- tool.source.rawValue,
                toolRemoteId <- tool.remoteId,
                toolRemoteAuthor <- tool.remoteAuthor,
                toolRemoteVotes <- tool.remoteVotes,
                toolRemoteUpdatedAt <- tool.remoteUpdatedAt?.timeIntervalSince1970,
                toolLangfuseName <- tool.langfuseName,
                toolLangfuseVersion <- tool.langfuseVersion,
                toolLangfuseLabels <- labelsJson,
                toolLastSyncedAt <- tool.lastSyncedAt?.timeIntervalSince1970,
                toolCapabilities <- capabilitiesJson
            ))
            print("✅ Prompt Tool 插入成功: \(tool.name)")
            NotificationCenter.default.post(name: .promptToolsDidUpdate, object: nil)
            return true
        } catch {
            handleDatabaseError("Prompt Tool 插入失败", error: error)
            return false
        }
    }

    /// 更新 Prompt Tool
    @discardableResult
    func updatePromptTool(_ tool: PromptTool) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.updatePromptTool(tool) } }
        guard let db = db else { return false }

        do {
            // 准备 Langfuse labels JSON
            let labelsJson = encodeLangfuseLabels(tool.langfuseLabels)
            let capabilitiesJson = encodeCapabilities(tool.capabilities)

            let query = promptToolsTable.filter(toolId == tool.id.uuidString)
            try db.run(query.update(
                toolName <- tool.name,
                toolPrompt <- tool.prompt,
                toolShortcutKeyCode <- Int(tool.shortcutKeyCode),
                toolShortcutModifiers <- Int(tool.shortcutModifiers),
                toolUpdatedAt <- Date().timeIntervalSince1970,
                toolSource <- tool.source.rawValue,
                toolRemoteId <- tool.remoteId,
                toolRemoteAuthor <- tool.remoteAuthor,
                toolRemoteVotes <- tool.remoteVotes,
                toolRemoteUpdatedAt <- tool.remoteUpdatedAt?.timeIntervalSince1970,
                toolLangfuseName <- tool.langfuseName,
                toolLangfuseVersion <- tool.langfuseVersion,
                toolLangfuseLabels <- labelsJson,
                toolLastSyncedAt <- tool.lastSyncedAt?.timeIntervalSince1970,
                toolCapabilities <- capabilitiesJson
            ))
            print("✅ Prompt Tool 更新成功: \(tool.name)")
            NotificationCenter.default.post(name: .promptToolsDidUpdate, object: nil)
            return true
        } catch {
            handleDatabaseError("Prompt Tool 更新失败", error: error)
            return false
        }
    }

    /// 删除 Prompt Tool
    @discardableResult
    func deletePromptTool(id: UUID) -> Bool {
        if !onStoreQueue { return storeQueue.sync { self.deletePromptTool(id: id) } }
        guard let db = db else { return false }

        do {
            let query = promptToolsTable.filter(toolId == id.uuidString)
            try db.run(query.delete())
            print("✅ Prompt Tool 删除成功: \(id)")
            NotificationCenter.default.post(name: .promptToolsDidUpdate, object: nil)
            return true
        } catch {
            handleDatabaseError("Prompt Tool 删除失败", error: error)
            return false
        }
    }

    /// 初始化默认 Prompt Tools（首次启动时调用）
    func initializeDefaultToolsIfNeeded() {
        if !onStoreQueue { return storeQueue.sync { self.initializeDefaultToolsIfNeeded() } }
        let existingTools = fetchAllPromptTools()

        // 如果已有工具，不再初始化
        guard existingTools.isEmpty else {
            print("📋 已存在 \(existingTools.count) 个 Prompt Tools，跳过初始化")
            return
        }

        print("🆕 首次启动，初始化默认 Prompt Tools")
        for tool in PromptTool.defaultTools {
            insertPromptTool(tool)
        }
    }

    /// 恢复默认 Prompt Tools
    func restoreDefaultTools() {
        if !onStoreQueue { return storeQueue.sync { self.restoreDefaultTools() } }
        let existingTools = fetchAllPromptTools()
        let defaultTools = PromptTool.defaultTools

        for defaultTool in defaultTools {
            restoreOrCreateDefaultTool(defaultTool, existingTools: existingTools)
        }

        print("✅ 默认 Prompt Tools 已恢复")
    }

    /// 恢复或创建单个默认工具
    private func restoreOrCreateDefaultTool(_ defaultTool: PromptTool, existingTools: [PromptTool]) {
        if let existing = findExistingDefaultTool(defaultTool, in: existingTools) {
            resetToDefaultPrompt(existing, defaultPrompt: defaultTool.prompt)
        } else if !toolNameExists(defaultTool.name, in: existingTools) {
            insertPromptTool(defaultTool)
        }
    }

    /// 查找已存在的同名默认工具
    private func findExistingDefaultTool(_ defaultTool: PromptTool, in existingTools: [PromptTool]) -> PromptTool? {
        return existingTools.first(where: { $0.name == defaultTool.name && $0.isDefault })
    }

    /// 检查工具名称是否已存在
    private func toolNameExists(_ name: String, in existingTools: [PromptTool]) -> Bool {
        return existingTools.contains(where: { $0.name == name })
    }

    /// 重置为默认 prompt
    private func resetToDefaultPrompt(_ tool: PromptTool, defaultPrompt: String) {
        var updated = tool
        updated.prompt = defaultPrompt
        updatePromptTool(updated)
    }

}
