//
//  DatabaseManager+PromptTools.swift
//  SenseFlow
//
//  Created on 2026-01-26.
//

import Foundation
import SQLite

extension DatabaseManager {

    // MARK: - Migration

    /// 迁移数据库到 v0.4（添加远程工具字段）
    internal func migrateToV04() throws {
        guard let db = db else { return }

        print("🔍 [Migration] 开始检查 v0.4 迁移...")

        // 检查 source 列是否已存在（不再依赖 user_version）
        let columnExists = try db.scalar(
            "SELECT COUNT(*) FROM pragma_table_info('prompt_tools') WHERE name='source'"
        ) as! Int64 > 0

        if columnExists {
            print("✅ source 列已存在，跳过 v0.4 迁移")
            return
        }

        print("🔄 开始迁移数据库到 v0.4...")

        // 添加新字段
        try db.run("ALTER TABLE prompt_tools ADD COLUMN source TEXT DEFAULT 'custom'")
        try db.run("ALTER TABLE prompt_tools ADD COLUMN remote_id TEXT")
        try db.run("ALTER TABLE prompt_tools ADD COLUMN remote_author TEXT")
        try db.run("ALTER TABLE prompt_tools ADD COLUMN remote_votes INTEGER DEFAULT 0")
        try db.run("ALTER TABLE prompt_tools ADD COLUMN remote_updated_at REAL")

        // 更新现有的默认工具为 builtin
        try db.run("""
            UPDATE prompt_tools
            SET source = 'builtin'
            WHERE is_default = 1
        """)

        print("✅ 数据库迁移到 v0.4 完成")
    }

    /// 迁移数据库到 v0.5（添加 Langfuse 字段）
    internal func migrateToV05() throws {
        guard let db = db else { return }

        // 检查是否已经迁移
        let userVersion = try db.scalar("PRAGMA user_version") as! Int64
        if userVersion >= 5 {
            print("✅ 数据库已是 v0.5 或更高版本")
            return
        }

        print("🔄 开始迁移数据库到 v0.5...")

        // 添加 Langfuse 字段
        try db.run("ALTER TABLE prompt_tools ADD COLUMN langfuse_name TEXT")
        try db.run("ALTER TABLE prompt_tools ADD COLUMN langfuse_version INTEGER")
        try db.run("ALTER TABLE prompt_tools ADD COLUMN langfuse_labels TEXT")  // JSON array
        try db.run("ALTER TABLE prompt_tools ADD COLUMN last_synced_at REAL")

        // 更新版本号
        try db.run("PRAGMA user_version = 5")

        print("✅ 数据库迁移到 v0.5 完成")
    }

    // MARK: - Community Tools Methods

    /// 获取所有社区工具
    internal func fetchCommunityTools() -> [PromptTool] {
        return fetchAllPromptTools().filter { $0.source == .community }
    }

    /// 根据远程 ID 获取工具
    internal func fetchToolByRemoteId(_ remoteId: String) -> PromptTool? {
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
}
