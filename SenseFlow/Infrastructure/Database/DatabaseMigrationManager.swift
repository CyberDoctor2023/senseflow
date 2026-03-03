//
//  DatabaseMigrationManager.swift
//  SenseFlow
//
//  Created by Refactoring on 2026-02-14.
//  负责数据库版本迁移
//

import Foundation
import SQLite

/// 数据库迁移管理器
/// 职责：处理数据库版本升级和表结构变更
class DatabaseMigrationManager {

    // MARK: - Properties

    private let db: Connection

    // MARK: - Initialization

    init(db: Connection) {
        self.db = db
    }

    // MARK: - Public Methods

    /// 执行数据库迁移
    func migrateIfNeeded() throws {
        let currentVersion = Int(db.userVersion ?? 0)
        print("📊 当前数据库版本: \(currentVersion)")

        let tableExists = try checkPromptToolsTableExists()
        print("📊 prompt_tools 表存在: \(tableExists)")

        if tableExists {
            try checkAndMigratePromptToolsFields()
        }

        try handleVersionBasedMigration(currentVersion: currentVersion, tableExists: tableExists)
    }

    // MARK: - Private Methods

    /// 检查 prompt_tools 表是否存在
    private func checkPromptToolsTableExists() throws -> Bool {
        let count = try db.scalar(
            "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='prompt_tools'"
        ) as! Int64

        return count > 0
    }

    /// 检查并迁移 prompt_tools 表字段
    private func checkAndMigratePromptToolsFields() throws {
        // 打印当前表结构
        print("📊 当前 prompt_tools 表结构:")
        let columns = try db.prepare("PRAGMA table_info(prompt_tools)")
        for column in columns {
            print("  - \(column[1] ?? "unknown")")
        }

        try checkAndMigrateV04Fields()
        try checkAndMigrateV05Fields()
        try checkAndMigrateV06Fields()
    }

    /// 检查并迁移 v0.4 字段
    private func checkAndMigrateV04Fields() throws {
        let sourceColumnExists = try db.scalar(
            "SELECT COUNT(*) FROM pragma_table_info('prompt_tools') WHERE name='source'"
        ) as! Int64 > 0

        print("📊 source 列存在: \(sourceColumnExists)")

        if !sourceColumnExists {
            print("⚠️ 检测到 prompt_tools 表缺少 v0.4 字段，强制执行迁移...")
            try migrateToV04()
            print("✅ v0.4 迁移执行成功")
        }
    }

    /// 检查并迁移 v0.5 字段
    private func checkAndMigrateV05Fields() throws {
        let langfuseColumnExists = try db.scalar(
            "SELECT COUNT(*) FROM pragma_table_info('prompt_tools') WHERE name='langfuse_name'"
        ) as! Int64 > 0

        print("📊 langfuse_name 列存在: \(langfuseColumnExists)")

        if !langfuseColumnExists {
            print("⚠️ 检测到 prompt_tools 表缺少 v0.5 字段，强制执行迁移...")
            try migrateToV05()
            print("✅ v0.5 迁移执行成功")
        }
    }

    /// 检查并迁移 v0.6 字段
    private func checkAndMigrateV06Fields() throws {
        let capabilitiesColumnExists = try db.scalar(
            "SELECT COUNT(*) FROM pragma_table_info('prompt_tools') WHERE name='capabilities'"
        ) as! Int64 > 0

        print("📊 capabilities 列存在: \(capabilitiesColumnExists)")

        if !capabilitiesColumnExists {
            print("⚠️ 检测到 prompt_tools 表缺少 v0.6 字段，强制执行迁移...")
            try migrateToV06()
            print("✅ v0.6 迁移执行成功")
        }
    }

    /// 处理基于版本号的迁移
    private func handleVersionBasedMigration(currentVersion: Int, tableExists: Bool) throws {
        // 全新数据库：createTable 已包含所有最新列，直接设置为最新版本
        if currentVersion == 0 {
            handleFreshDatabase(tableExists: tableExists)
            return
        }

        // 逐步迁移旧版本
        try migrateFromV1ToV2(currentVersion: currentVersion)
        try migrateFromV2ToV3(currentVersion: currentVersion)
        try migrateFromV3ToV4(currentVersion: currentVersion)
        try migrateFromV4ToV5(currentVersion: currentVersion)
        try migrateFromV5ToV6(currentVersion: currentVersion)
    }

    /// 处理全新数据库
    private func handleFreshDatabase(tableExists: Bool) {
        if tableExists {
            print("⚠️ 检测到旧数据库（版本 0 但表已存在），已执行字段检查")
        } else {
            print("🆕 全新数据库，设置为最新版本 v6")
        }
        db.userVersion = 6
    }

    /// v1 -> v2 迁移
    private func migrateFromV1ToV2(currentVersion: Int) throws {
        guard currentVersion == 1 else { return }

        print("🔄 数据库迁移: v1 -> v2（添加 app_path 列）")
        try db.run("ALTER TABLE clipboard_history ADD COLUMN app_path TEXT")
        db.userVersion = 2
        print("✅ 迁移完成，当前版本: 2")
    }

    /// v2 -> v3 迁移
    private func migrateFromV2ToV3(currentVersion: Int) throws {
        guard currentVersion == 2 else { return }

        print("🔄 数据库迁移: v2 -> v3（添加 ocr_text 列）")
        try db.run("ALTER TABLE clipboard_history ADD COLUMN ocr_text TEXT")
        db.userVersion = 3
        print("✅ 迁移完成，当前版本: 3")
    }

    /// v3 -> v4 迁移
    private func migrateFromV3ToV4(currentVersion: Int) throws {
        guard currentVersion == 3 else { return }
        try migrateToV04()
    }

    /// v4 -> v5 迁移
    private func migrateFromV4ToV5(currentVersion: Int) throws {
        guard currentVersion == 4 else { return }
        try migrateToV05()
    }

    /// v5 -> v6 迁移
    private func migrateFromV5ToV6(currentVersion: Int) throws {
        guard currentVersion == 5 else { return }
        try migrateToV06()
    }

    /// 迁移数据库到 v0.4（添加远程工具字段）
    private func migrateToV04() throws {
        print("🔍 [Migration] 开始检查 v0.4 迁移...")

        // 检查 source 列是否已存在
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
    private func migrateToV05() throws {
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

    /// 迁移数据库到 v0.6（添加 capabilities 字段）
    private func migrateToV06() throws {
        let userVersion = try db.scalar("PRAGMA user_version") as! Int64
        if userVersion >= 6 {
            print("✅ 数据库已是 v0.6 或更高版本")
            return
        }

        print("🔄 开始迁移数据库到 v0.6...")

        try db.run("ALTER TABLE prompt_tools ADD COLUMN capabilities TEXT")
        try db.run("PRAGMA user_version = 6")

        print("✅ 数据库迁移到 v0.6 完成")
    }
}
