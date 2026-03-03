//
//  ClipboardRepositoryProtocol.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//

import Foundation

/// 剪贴板数据仓库协议（依赖倒置原则）
protocol ClipboardRepositoryProtocol {
    /// 获取最近的剪贴板项
    func fetchRecent(limit: Int) async -> [ClipboardItem]

    /// 搜索剪贴板项
    func search(query: String, limit: Int) async -> [ClipboardItem]
}
