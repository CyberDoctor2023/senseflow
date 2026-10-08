//
//  OCRService.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-16.
//  Based on Context7 Vision framework documentation
//

import Foundation
import Vision

/// OCR 服务（使用 Vision 框架识别图片中的文字）
/// 使用 macOS 15 起的原生异步识别请求。
actor OCRService {

    // MARK: - Singleton

    static let shared = OCRService()

    private init() {}

    // MARK: - OCR Methods

    /// 识别图片中的文字（从 Data，推荐使用此方法）
    /// - Parameter imageData: 图片数据
    /// - Returns: 识别出的文本，失败返回 nil
    func recognizeText(from imageData: Data) async -> String? {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"].map {
            Locale.Language(identifier: $0)
        }
        do {
            let observations = try await request.perform(on: imageData)
            guard !Task.isCancelled else { return nil }
            let text = observations.compactMap {
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
