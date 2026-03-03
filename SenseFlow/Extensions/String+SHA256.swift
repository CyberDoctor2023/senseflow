//
//  String+SHA256.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//

import Foundation

extension String {
    /// 计算字符串的 SHA256 哈希值
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        return data.sha256()
    }
}
