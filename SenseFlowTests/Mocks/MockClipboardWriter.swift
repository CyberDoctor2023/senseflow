//
//  MockClipboardWriter.swift
//  SenseFlowTests
//
//  Created on 2026-02-02.
//

import Foundation
@testable import SenseFlow

final class MockClipboardWriter: ClipboardWriter {
    // 记录调用
    var writeTextCallCount = 0
    var writeContentCallCount = 0

    var writtenText: String?
    var writtenContent: ClipboardContent?

    func write(_ text: String) async {
        writeTextCallCount += 1
        writtenText = text
    }

    func write(_ content: ClipboardContent) async {
        writeContentCallCount += 1
        writtenContent = content
    }

    // 便捷属性
    var didWrite: Bool {
        return writeTextCallCount > 0 || writeContentCallCount > 0
    }
}
