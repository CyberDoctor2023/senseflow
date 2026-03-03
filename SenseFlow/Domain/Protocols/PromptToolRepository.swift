//
//  PromptToolRepository.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// Prompt Tool 数据仓库协议（Port）
/// 定义数据访问接口，不关心具体实现
protocol PromptToolRepository: Sendable {
    /// 查找所有工具
    func findAll() async throws -> [PromptTool]

    /// 根据 ID 查找工具
    func find(by id: ToolID) async throws -> PromptTool?

    /// 保存工具（新增或更新）
    func save(_ tool: PromptTool) async throws

    /// 删除工具
    func delete(id: ToolID) async throws

    /// 查找默认工具
    func findDefaults() async throws -> [PromptTool]
}
