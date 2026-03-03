//
//  ToolID.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import Foundation

/// 工具 ID 值对象
/// 类型安全的 ID，防止与其他 ID 类型混淆
struct ToolID: Hashable, Codable, Sendable {
    let value: UUID

    init(_ value: UUID = UUID()) {
        self.value = value
    }

    init?(string: String) {
        guard let uuid = UUID(uuidString: string) else { return nil }
        self.value = uuid
    }

    var uuidString: String {
        value.uuidString
    }
}

// MARK: - CustomStringConvertible

extension ToolID: CustomStringConvertible {
    var description: String {
        value.uuidString
    }
}

// MARK: - ExpressibleByStringLiteral (for testing)

extension ToolID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        guard let uuid = UUID(uuidString: value) else {
            fatalError("Invalid UUID string: \(value)")
        }
        self.value = uuid
    }
}
