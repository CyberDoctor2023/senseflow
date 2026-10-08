//
//  OCRService.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-16.
//  Based on Context7 Vision framework documentation
//

import Foundation
import Vision
import AppKit

/// OCR 服务（使用 Vision 框架识别图片中的文字）
/// 使用 VNRecognizeTextRequest（macOS 12+ 兼容）
actor OCRService {

    // MARK: - Singleton

    static let shared = OCRService()

    private init() {}

    // MARK: - OCR Methods

    /// 识别图片中的文字（从 Data，推荐使用此方法）
    /// - Parameter imageData: 图片数据
    /// - Returns: 识别出的文本，失败返回 nil
    func recognizeText(from imageData: Data) async -> String? {
        guard let cgImage = NSImage(data: imageData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ OCR: 无法从 Data 创建 CGImage")
            return nil
        }

        return await recognizeText(from: cgImage)
    }

    /// 识别图片中的文字（从 NSImage）
    /// - Parameter image: 要识别的图片
    /// - Returns: 识别出的文本，失败返回 nil
    func recognizeText(from image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ OCR: 无法转换为 CGImage")
            return nil
        }

        return await recognizeText(from: cgImage)
    }

    /// 识别图片中的文字（从 CGImage）
    /// - Parameter cgImage: CGImage
    /// - Returns: 识别出的文本，失败返回 nil
    func recognizeText(from cgImage: CGImage) async -> String? {
        return await performRecognition(from: cgImage)
    }

    /// 识别图片中的文字（核心方法）
    /// - Parameter cgImage: CGImage
    /// - Returns: 识别出的文本，失败返回 nil
    private func performRecognition(from cgImage: CGImage) async -> String? {
        // Vision's perform is synchronous. A single return path owns completion;
        // no callback and catch can resume the same continuation twice.
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            guard !Task.isCancelled else { return nil }
            let text = (request.results ?? []).compactMap {
                $0.topCandidates(1).first?.string
            }.joined(separator: " ")
            return text.isEmpty ? nil : text
        } catch {
            // Preserve failure evidence without logging captured text, image bytes, or paths.
            let failure = error as NSError
            print("OCR failed: domain=\(failure.domain), code=\(failure.code)")
            return nil
        }
    }
}
