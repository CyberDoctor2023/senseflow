//
//  MockExecutePromptTool.swift
//  SenseFlowTests
//
//  Created on 2026-02-03.
//

import Foundation
@testable import SenseFlow

final class MockExecutePromptTool {

    // MARK: - Tracking Properties

    var executeCallCount = 0
    var lastExecutedTool: PromptTool?

    // MARK: - Return Values

    var resultToReturn = "Mock execution result"

    // MARK: - Error Simulation

    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic

    // MARK: - Execute Method

    func execute(tool: PromptTool) async throws -> String {
        executeCallCount += 1
        lastExecutedTool = tool

        if shouldThrowError {
            throw errorToThrow
        }

        return resultToReturn
    }
}
