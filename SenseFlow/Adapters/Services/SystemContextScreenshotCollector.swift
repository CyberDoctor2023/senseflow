//
//  SystemContextScreenshotCollector.swift
//  SenseFlow
//

import AppKit
import ApplicationServices

extension SystemContextCollector {
    struct UITreeOverlayAnnotation {
        let ref: String
        let frame: CGRect
        let role: String
        let name: String?
        let isFocused: Bool
        let isInteractive: Bool
        let isNearCursor: Bool
    }

    protocol UITreeOverlayAnnotationProviding: Sendable {
        func buildAnnotations(
            processID: pid_t,
            displayFrame: CGRect
        ) -> [UITreeOverlayAnnotation]
    }

    protocol UITreeOverlayRendering: Sendable {
        @MainActor
        func render(
            baseImage: CGImage,
            displayFrame: CGRect,
            cursorLocation: CGPoint?,
            annotations: [UITreeOverlayAnnotation]
        ) -> CGImage?
    }

    protocol UITreeLiveOverlayPresenting: Sendable {
        @MainActor
        func present(
            displayFrame: CGRect,
            cursorLocation: CGPoint?,
            annotations: [UITreeOverlayAnnotation]
        )
    }

    struct NoopUITreeLiveOverlayPresenter: UITreeLiveOverlayPresenting {
        @MainActor
        func present(
            displayFrame: CGRect,
            cursorLocation: CGPoint?,
            annotations: [UITreeOverlayAnnotation]
        ) {}
    }

    protocol CaretLocating: Sendable {
        func locateCaret(
            processID: pid_t,
            targetFrame: CGRect
        ) -> CGPoint?
    }

    protocol PointerLocating: Sendable {
        @MainActor
        func currentPointerLocation() -> CGPoint?
    }

    struct CGEventPointerLocator: PointerLocating {
        @MainActor
        func currentPointerLocation() -> CGPoint? {
            CGEvent(source: nil)?.location
        }
    }

    struct CursorLocationPolicy: Sendable {
        func resolve(
            caret: CGPoint?,
            before: CGPoint?,
            after: CGPoint?,
            targetFrame: CGRect
        ) -> CGPoint? {
            if let caret, targetFrame.contains(caret) {
                return caret
            }

            if let after, targetFrame.contains(after) {
                return after
            }

            if let before, targetFrame.contains(before) {
                return before
            }

            return nil
        }
    }

    struct ScreenshotCollectionResult {
        let annotatedTreeScreenshot: String?
        let fullScreenScreenshot: String?

        static let empty = ScreenshotCollectionResult(
            annotatedTreeScreenshot: nil,
            fullScreenScreenshot: nil
        )
    }

    protocol ScreenshotCollecting: Sendable {
        @available(macOS 14, *)
        func collect(using capture: any ScreenCaptureManaging) async -> ScreenshotCollectionResult
    }

    final class DefaultScreenshotCollector: ScreenshotCollecting, @unchecked Sendable {
        private enum ScreenshotCollectionError: Error {
            case overlayRenderFailed
            case focusedEncodeFailed
            case fullScreenEncodeFailed
        }

        private let overlayAnnotationProvider: any UITreeOverlayAnnotationProviding
        private let overlayRenderer: any UITreeOverlayRendering
        private let caretLocator: any CaretLocating
        private let pointerLocator: any PointerLocating
        private let cursorLocationPolicy: CursorLocationPolicy
        private let liveOverlayPresenter: any UITreeLiveOverlayPresenting

        init(
            overlayAnnotationProvider: any UITreeOverlayAnnotationProviding,
            overlayRenderer: any UITreeOverlayRendering,
            caretLocator: any CaretLocating = AXCaretLocator(),
            pointerLocator: any PointerLocating = CGEventPointerLocator(),
            cursorLocationPolicy: CursorLocationPolicy = CursorLocationPolicy(),
            liveOverlayPresenter: any UITreeLiveOverlayPresenting = NoopUITreeLiveOverlayPresenter()
        ) {
            self.overlayAnnotationProvider = overlayAnnotationProvider
            self.overlayRenderer = overlayRenderer
            self.caretLocator = caretLocator
            self.pointerLocator = pointerLocator
            self.cursorLocationPolicy = cursorLocationPolicy
            self.liveOverlayPresenter = liveOverlayPresenter
        }

        @available(macOS 14, *)
        func collect(using capture: any ScreenCaptureManaging) async -> ScreenshotCollectionResult {
            do {
                let fullScreenScreenshot = try await collectFullScreenScreenshot(using: capture)
                let annotatedTreeScreenshot = try await collectFocusedAnnotatedScreenshot(using: capture)

                return ScreenshotCollectionResult(
                    annotatedTreeScreenshot: annotatedTreeScreenshot,
                    fullScreenScreenshot: fullScreenScreenshot
                )
            } catch {
                print("⚠️ 截图采集失败（需焦点图+全屏图同时成功）: \(error)")
                return .empty
            }
        }

        @available(macOS 14, *)
        private func collectFocusedAnnotatedScreenshot(using capture: any ScreenCaptureManaging) async throws -> String {
            let focusedSample = try await captureWithPointerSamples {
                try await capture.captureCurrentWindowWithMetadata()
            }

            let focusedCursorLocation = resolveCursorLocation(
                processID: focusedSample.payload.processID,
                before: focusedSample.pointerBefore,
                after: focusedSample.pointerAfter,
                targetFrame: focusedSample.payload.windowFrame
            )
            let overlayAnnotations = overlayAnnotationProvider.buildAnnotations(
                processID: focusedSample.payload.processID,
                displayFrame: focusedSample.payload.windowFrame
            )

            await presentLiveOverlay(
                displayFrame: focusedSample.payload.windowFrame,
                cursorLocation: focusedCursorLocation,
                annotations: overlayAnnotations
            )

            let annotatedImage = await renderOverlay(
                baseImage: focusedSample.payload.image,
                displayFrame: focusedSample.payload.windowFrame,
                cursorLocation: focusedCursorLocation,
                annotations: overlayAnnotations
            )
            guard let annotatedImage else {
                throw ScreenshotCollectionError.overlayRenderFailed
            }

            guard let encoded = await encode(
                image: annotatedImage,
                using: capture
            ) else {
                throw ScreenshotCollectionError.focusedEncodeFailed
            }
            return encoded
        }

        @available(macOS 14, *)
        private func collectFullScreenScreenshot(using capture: any ScreenCaptureManaging) async throws -> String {
            let fullResult = try await capture.captureFullScreenWithMetadata()

            guard let encoded = await encode(
                image: fullResult.image,
                using: capture
            ) else {
                throw ScreenshotCollectionError.fullScreenEncodeFailed
            }
            return encoded
        }

        private struct PointerSample<T> {
            let payload: T
            let pointerBefore: CGPoint?
            let pointerAfter: CGPoint?
        }

        private func captureWithPointerSamples<T>(
            _ operation: () async throws -> T
        ) async throws -> PointerSample<T> {
            let pointerBefore = await currentPointerLocation()
            let payload = try await operation()
            let pointerAfter = await currentPointerLocation()
            return PointerSample(
                payload: payload,
                pointerBefore: pointerBefore,
                pointerAfter: pointerAfter
            )
        }

        private func currentPointerLocation() async -> CGPoint? {
            await MainActor.run {
                pointerLocator.currentPointerLocation()
            }
        }

        private func resolveCursorLocation(
            processID: pid_t?,
            before: CGPoint?,
            after: CGPoint?,
            targetFrame: CGRect
        ) -> CGPoint? {
            let caret = processID.flatMap {
                caretLocator.locateCaret(
                    processID: $0,
                    targetFrame: targetFrame
                )
            }

            return cursorLocationPolicy.resolve(
                caret: caret,
                before: before,
                after: after,
                targetFrame: targetFrame
            )
        }

        private func presentLiveOverlay(
            displayFrame: CGRect,
            cursorLocation: CGPoint?,
            annotations: [UITreeOverlayAnnotation]
        ) async {
            guard cursorLocation != nil || !annotations.isEmpty else {
                return
            }

            await MainActor.run {
                liveOverlayPresenter.present(
                    displayFrame: displayFrame,
                    cursorLocation: cursorLocation,
                    annotations: annotations
                )
            }
        }

        private func renderOverlay(
            baseImage: CGImage,
            displayFrame: CGRect,
            cursorLocation: CGPoint?,
            annotations: [UITreeOverlayAnnotation]
        ) async -> CGImage? {
            await MainActor.run {
                overlayRenderer.render(
                    baseImage: baseImage,
                    displayFrame: displayFrame,
                    cursorLocation: cursorLocation,
                    annotations: annotations
                )
            }
        }

        private func encode(
            image: CGImage,
            using capture: any ScreenCaptureManaging
        ) async -> String? {
            await MainActor.run {
                capture.imageToBase64(
                    image,
                    quality: BusinessRules.Encryption.defaultJPEGQuality
                )
            }
        }
    }

}
