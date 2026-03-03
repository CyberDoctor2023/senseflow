//
//  BlobFileManager.swift
//  SenseFlow
//
//  Created by Refactoring on 2026-01-26.
//  负责大文件（blob）的文件系统存储管理
//

import Foundation

/// 大文件存储管理器（单例）
class BlobFileManager {

    // MARK: - Singleton

    static let shared = BlobFileManager()

    // MARK: - Properties

    private let largeFileSizeThreshold = BusinessRules.FileStorage.largeFileThreshold

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 判断是否应该外部存储大文件
    func shouldStoreLargeFileExternally(_ data: Data) -> Bool {
        return data.count > largeFileSizeThreshold
    }

    /// 保存大文件到文件系统
    /// - Parameters:
    ///   - data: 文件数据
    ///   - uniqueId: 唯一标识符
    /// - Returns: 文件路径
    func saveLargeFile(data: Data, uniqueId: String) throws -> String {
        let blobsDirectory = try getBlobsDirectory()

        let fileName = "\(uniqueId).blob"
        let fileURL = blobsDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        return fileURL.path
    }

    /// 删除单个 blob 文件
    /// - Parameter path: 文件路径
    func deleteBlobFile(at path: String) {
        do {
            try FileManager.default.removeItem(atPath: path)
            print("🗑️ 已删除 blob 文件: \(path)")
        } catch {
            print("⚠️ 删除 blob 文件失败: \(path) - \(error.localizedDescription)")
        }
    }

    /// 清理所有 blob 文件
    func cleanupAllBlobFiles() throws {
        let blobsDirectory = try getBlobsDirectory()

        if FileManager.default.fileExists(atPath: blobsDirectory.path) {
            try FileManager.default.removeItem(at: blobsDirectory)
            print("🧹 已清理所有 blob 文件")
        }
    }

    // MARK: - Private Methods

    /// 获取 blobs 目录
    private func getBlobsDirectory() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let blobsDirectory = appSupportURL
            .appendingPathComponent(AppConstants.appSupportDirectoryName, isDirectory: true)
            .appendingPathComponent("blobs", isDirectory: true)

        try fileManager.createDirectory(at: blobsDirectory, withIntermediateDirectories: true)

        return blobsDirectory
    }
}
