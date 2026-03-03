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

    func fetchRecent(limit: Int) async -> [ClipboardItem] {
        return await databaseManager.fetchRecentItemsAsync(limit: limit)
    }

    func search(query: String, limit: Int) async -> [ClipboardItem] {
        return await databaseManager.searchItemsAsync(query: query, limit: limit)
    }
}
