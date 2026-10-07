//
//  DatabaseClipboardRepository.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//

import Foundation

/// 数据库实现的剪贴板仓库
class DatabaseClipboardRepository: ClipboardRepositoryProtocol {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func fetchRecent(limit: Int, offset: Int) async throws -> [ClipboardItem] {
        return try await databaseManager.fetchRecentItemsAsync(limit: limit, offset: offset)
    }

    func search(query: String, limit: Int, offset: Int) async throws -> [ClipboardItem] {
        return try await databaseManager.searchItemsAsync(query: query, limit: limit, offset: offset)
    }
}
