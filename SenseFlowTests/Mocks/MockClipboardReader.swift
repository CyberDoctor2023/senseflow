//
//  MockClipboardReader.swift
//  SenseFlowTests
//
//  Created on 2026-02-02.
//

import Foundation
@testable import SenseFlow

final class MockClipboardReader: ClipboardReader {
    // 配置返回值
    var textToReturn: String?
    var contentToReturn: ClipboardContent = .empty

    // 记录调用
    var readTextCallCount = 0
    var readContentCallCount = 0

    func readText() -> String? {
        readTextCallCount += 1
        return textToReturn
    }

    func readContent() -> ClipboardContent {
        readContentCallCount += 1

        // 如果配置了 textToReturn，自动返回 text content
        if let text = textToReturn {
            return .text(text)
        }

        return contentToReturn
    }
}
