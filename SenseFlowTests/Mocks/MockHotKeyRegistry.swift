//
//  MockHotKeyRegistry.swift
//  SenseFlowTests
//
//  Created on 2026-02-03.
//

import Foundation
@testable import SenseFlow

final class MockHotKeyRegistry: HotKeyRegistry {

    // MARK: - Tracking Properties

    var registerCallCount = 0
    var unregisterCallCount = 0
    var unregisterAllCallCount = 0

    var lastRegisteredToolID: ToolID?
    var lastRegisteredCombo: KeyCombo?
    var lastRegisteredHandler: (@Sendable () -> Void)?

    var lastUnregisteredToolID: ToolID?

    // MARK: - Error Simulation

    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic

    // MARK: - HotKeyRegistry Implementation

    func register(
        toolID: ToolID,
        combo: KeyCombo,
        handler: @escaping @Sendable () -> Void
    ) throws {
        registerCallCount += 1
        lastRegisteredToolID = toolID
        lastRegisteredCombo = combo
        lastRegisteredHandler = handler

        if shouldThrowError {
            throw errorToThrow
        }
    }

    func unregister(toolID: ToolID) {
        unregisterCallCount += 1
        lastUnregisteredToolID = toolID
    }

    func unregisterAll() {
        unregisterAllCallCount += 1
    }
}
