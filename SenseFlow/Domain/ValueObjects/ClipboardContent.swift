//
//  ClipboardContent.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// 剪贴板内容值对象
enum ClipboardContent: Equatable, Sendable {
    case text(String)
    case image(Data)
    case file(URL)
    case empty

    var isEmpty: Bool {
        if case .empty = self {
            return true
        }
        return false
    }

    var asText: String? {
        if case .text(let value) = self {
            return value
        }
        return nil
    }

    var asImage: Data? {
        if case .image(let data) = self {
            return data
        }
        return nil
    }
}
