//
//  MockContextCollector.swift
//  SenseFlowTests
//
//  Created on 2026-02-03.
//

import Foundation
@testable import SenseFlow

final class MockContextCollector: ContextCollector {

    // MARK: - Tracking Properties

    var collectCallCount = 0

    // MARK: - Return Values

    var contextToReturn: SmartContext?

    // MARK: - Error Simulation

    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic

    // MARK: - ContextCollector Implementation

    func collect() async throws -> SmartContext {
        collectCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }

        guard let context = contextToReturn else {
            // 返回默认上下文
            return SmartContext(
                applicationName: "Test App",
                bundleID: "com.test.app",
                clipboardText: "Test clipboard content",
                clipboardHasImage: false,
                screenshot: nil,
                isLightweightMode: true
            )
        }

        return context
    }
}
