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
class OCRService {

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
        return await withCheckedContinuation { continuation in
            // Context7: 创建文字识别请求
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("❌ OCR 识别失败: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Context7: 提取识别到的文本
                let recognizedTexts = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedTexts.joined(separator: " ")

                if fullText.isEmpty {
                    print("⚠️ OCR: 图片中未识别到文字")
                    continuation.resume(returning: nil)
                } else {
                    print("✅ OCR: 识别到 \(recognizedTexts.count) 行文字")
                    continuation.resume(returning: fullText)
                }
            }

            // Context7: 配置识别选项
            request.recognitionLevel = .accurate  // 精确模式
            request.usesLanguageCorrection = true  // 启用语言校正

            // Context7: 支持多语言（中文 + 英文）
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            // Context7: 执行请求
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try requestHandler.perform([request])
            } catch {
                print("❌ OCR 请求执行失败: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
}
