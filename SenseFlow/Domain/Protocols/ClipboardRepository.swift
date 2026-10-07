//
//  ClipboardRepository.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// 剪贴板数据仓库协议（Port）
protocol ClipboardRepository: Sendable {
    /// 保存剪贴板项
    func save(_ item: ClipboardItem) async throws

    /// 查找所有项（带限制）
    func findAll(limit: Int) async throws -> [ClipboardItem]

    /// 搜索项
    func search(query: String) async throws -> [ClipboardItem]

    /// 删除项
    func delete(id: String) async throws

    /// 清空所有历史
    func deleteAll() async throws
}
