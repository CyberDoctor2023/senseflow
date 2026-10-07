//
//  Data+SHA256.swift
//  SenseFlow
//
//  Created on 2026-02-05.
//

import Foundation
import CryptoKit

extension Data {
    /// 计算数据的 SHA256 哈希值
    func sha256() -> String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
