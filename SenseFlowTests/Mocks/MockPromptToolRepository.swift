//
//  MockPromptToolRepository.swift
//  SenseFlowTests
//
//  Created on 2026-02-03.
//

import Foundation
@testable import SenseFlow

final class MockPromptToolRepository: PromptToolRepository {

    // MARK: - Tracking Properties

    var findAllCallCount = 0
    var findByIdCallCount = 0
    var saveCallCount = 0
    var deleteCallCount = 0
    var findDefaultsCallCount = 0

    var lastSavedTool: PromptTool?
    var lastDeletedId: ToolID?
    var lastQueriedId: ToolID?

    // MARK: - Return Values

    var toolsToReturn: [PromptTool] = []
    var toolToReturn: PromptTool?

    // MARK: - Error Simulation

    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic

    // MARK: - PromptToolRepository Implementation

    func findAll() async throws -> [PromptTool] {
        findAllCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        return toolsToReturn
    }

    func find(by id: ToolID) async throws -> PromptTool? {
        findByIdCallCount += 1
        lastQueriedId = id

        if shouldThrowError {
            throw errorToThrow
        }

        // 从 toolsToReturn 中查找
        return toolsToReturn.first { $0.toolID == id } ?? toolToReturn
    }

    func save(_ tool: PromptTool) async throws {
        saveCallCount += 1
        lastSavedTool = tool

        if shouldThrowError {
            throw errorToThrow
        }

        // 更新或添加到 toolsToReturn
        if let index = toolsToReturn.firstIndex(where: { $0.id == tool.id }) {
            toolsToReturn[index] = tool
        } else {
            toolsToReturn.append(tool)
        }
    }

    func delete(id: ToolID) async throws {
        deleteCallCount += 1
        lastDeletedId = id

        if shouldThrowError {
            throw errorToThrow
        }

        toolsToReturn.removeAll { $0.toolID == id }
    }

    func findDefaults() async throws -> [PromptTool] {
        findDefaultsCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        return toolsToReturn.filter { $0.isDefault }
    }
}
