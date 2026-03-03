//
//  SystemContextCollector.swift
//  SenseFlow
//
//  Created on 2026-02-02.
//

import AppKit

/// 系统上下文收集器（Adapter）
/// 职责：收集当前应用、剪贴板、截图等上下文信息
final class SystemContextCollector: ContextCollector {
    private let clipboardReader: ClipboardReader
    private let frontmostApplicationResolver: any FrontmostApplicationResolving
    private let clipboardSnapshotCollector: any ClipboardSnapshotCollecting
    private let screenCapture: (any ScreenCaptureManaging)?
    private let screenshotCollector: any ScreenshotCollecting

    init(
        clipboardReader: ClipboardReader,
        frontmostApplicationResolver: (any FrontmostApplicationResolving)? = nil,
        clipboardSnapshotCollector: (any ClipboardSnapshotCollecting)? = nil,
        screenCapture: (any ScreenCaptureManaging)? = nil,
        overlayAnnotationProvider: any UITreeOverlayAnnotationProviding = OpenClawUITreeOverlayAnnotationProvider(),
        overlayRenderer: any UITreeOverlayRendering = OpenClawUITreeOverlayRenderer(),
        liveOverlayPresenter: (any UITreeLiveOverlayPresenting)? = nil,
        screenshotCollector: (any ScreenshotCollecting)? = nil
    ) {
        self.clipboardReader = clipboardReader
        self.frontmostApplicationResolver = frontmostApplicationResolver ?? DefaultFrontmostApplicationResolver()
        self.clipboardSnapshotCollector = clipboardSnapshotCollector ?? DefaultClipboardSnapshotCollector()
        self.screenCapture = screenCapture
        let resolvedLiveOverlayPresenter = liveOverlayPresenter ?? OpenClawUITreeLiveOverlayPresenter(
            overlayRenderer: overlayRenderer
        )
        self.screenshotCollector = screenshotCollector ?? DefaultScreenshotCollector(
            overlayAnnotationProvider: overlayAnnotationProvider,
            overlayRenderer: overlayRenderer,
            liveOverlayPresenter: resolvedLiveOverlayPresenter
        )
    }

    func collect() async throws -> SmartContext {
        let appSnapshot = try frontmostApplicationResolver.resolve()
        let focusedElementContext: SmartFocusedElementContext? = nil

        let clipboardSnapshot = clipboardSnapshotCollector.collect(from: clipboardReader)

        let lightweightModeEnabled = UserDefaults.standard.bool(forKey: "smartAILightweightMode")
        var screenshotResult = ScreenshotCollectionResult.empty
        if !lightweightModeEnabled, let capture = screenCapture {
            if #available(macOS 14, *) {
                screenshotResult = await screenshotCollector.collect(using: capture)
            }
        }

        return SmartContext(
            applicationName: appSnapshot.applicationName,
            bundleID: appSnapshot.bundleID,
            clipboardText: clipboardSnapshot.text,
            clipboardHasImage: clipboardSnapshot.hasImage,
            cursorNeighborhoodOCRText: nil,
            focusedElement: focusedElementContext,
            screenshot: screenshotResult.annotatedTreeScreenshot,
            fullScreenScreenshot: screenshotResult.fullScreenScreenshot,
            isLightweightMode: lightweightModeEnabled
        )
    }
}

// MARK: - Errors

enum ContextError: LocalizedError {
    case noActiveApplication

    var errorDescription: String? {
        switch self {
        case .noActiveApplication:
            return "没有活动的应用程序"
        }
    }
}
