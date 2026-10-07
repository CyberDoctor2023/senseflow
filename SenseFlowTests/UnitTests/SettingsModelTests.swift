//
//  SettingsModelTests.swift
//  SenseFlowTests
//
//  Created on 2026-02-27.
//

import XCTest
import AppKit
@testable import SenseFlow

@MainActor
final class SettingsModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled)
        super.tearDown()
    }

    func test_init_whenTextSelectionFlagMissing_defaultsToEnabledAndPersists() {
        XCTAssertNil(UserDefaults.standard.object(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled))

        let model = SettingsModel()

        XCTAssertTrue(model.textSelectionEnabled)
        XCTAssertEqual(
            UserDefaults.standard.object(forKey: UserDefaultsKeys.textSelectionAutoCopyEnabled) as? Bool,
            true
        )
    }
}

@MainActor
final class DefaultScreenshotCollectorTests: XCTestCase {
    private enum MockError: Error {
        case captureFailed
    }

    @available(macOS 14, *)
    func test_collect_usesCapturedProcessIDForOverlayProvider() async {
        let capture = MockScreenCaptureManager()
        let overlayProvider = MockOverlayProvider()
        let overlayRenderer = MockOverlayRenderer()
        let sut = SystemContextCollector.DefaultScreenshotCollector(
            overlayAnnotationProvider: overlayProvider,
            overlayRenderer: overlayRenderer
        )

        capture.focusedResult = ScreenCaptureManager.CurrentWindowCaptureResult(
            image: makeImage(),
            windowFrame: CGRect(x: 100, y: 100, width: 600, height: 400),
            windowID: 99,
            processID: 4242
        )
        capture.fullResult = ScreenCaptureManager.FullScreenCaptureResult(
            image: makeImage(),
            displayFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        capture.base64Results = ["focused-app-b64", "full-screen-b64"]

        let result = await sut.collect(using: capture)

        XCTAssertEqual(overlayProvider.lastProcessID, 4242)
        XCTAssertEqual(result.annotatedTreeScreenshot, "focused-app-b64")
        XCTAssertEqual(result.fullScreenScreenshot, "full-screen-b64")
    }

    @available(macOS 14, *)
    func test_collect_whenFocusedCaptureFails_returnsEmptyAndSkipsFullScreen() async {
        let capture = MockScreenCaptureManager()
        let overlayProvider = MockOverlayProvider()
        let overlayRenderer = MockOverlayRenderer()
        let sut = SystemContextCollector.DefaultScreenshotCollector(
            overlayAnnotationProvider: overlayProvider,
            overlayRenderer: overlayRenderer
        )

        capture.focusedError = MockError.captureFailed
        let result = await sut.collect(using: capture)

        XCTAssertNil(result.annotatedTreeScreenshot)
        XCTAssertNil(result.fullScreenScreenshot)
        XCTAssertNil(overlayProvider.lastProcessID)
        XCTAssertEqual(capture.fullCaptureCallCount, 0)
        XCTAssertEqual(capture.imageToBase64CallCount, 0)
    }

    @available(macOS 14, *)
    func test_collect_samplesPointerThroughInjectedLocator() async {
        let capture = MockScreenCaptureManager()
        let overlayProvider = MockOverlayProvider()
        let overlayRenderer = MockOverlayRenderer()
        let caretLocator = MockCaretLocator()
        let pointerLocator = MockPointerLocator(
            points: [
                CGPoint(x: 110, y: 110),
                CGPoint(x: 120, y: 120),
            ]
        )
        let sut = SystemContextCollector.DefaultScreenshotCollector(
            overlayAnnotationProvider: overlayProvider,
            overlayRenderer: overlayRenderer,
            caretLocator: caretLocator,
            pointerLocator: pointerLocator
        )

        capture.focusedResult = ScreenCaptureManager.CurrentWindowCaptureResult(
            image: makeImage(),
            windowFrame: CGRect(x: 100, y: 100, width: 600, height: 400),
            windowID: 777,
            processID: 5151
        )
        capture.fullResult = ScreenCaptureManager.FullScreenCaptureResult(
            image: makeImage(),
            displayFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        capture.base64Results = ["focused", "full"]

        _ = await sut.collect(using: capture)

        XCTAssertEqual(pointerLocator.callCount, 2)
        XCTAssertTrue(caretLocator.calls.contains(where: { $0.processID == 5151 }))
    }

    @available(macOS 14, *)
    func test_collect_presentsLiveOverlayUsingFocusedSignals() async {
        let capture = MockScreenCaptureManager()
        let overlayProvider = MockOverlayProvider()
        let overlayRenderer = MockOverlayRenderer()
        let liveOverlayPresenter = MockLiveOverlayPresenter()
        let pointerLocator = MockPointerLocator(
            points: [
                CGPoint(x: 120, y: 160),
                CGPoint(x: 126, y: 164),
                CGPoint(x: 220, y: 260),
                CGPoint(x: 224, y: 264),
            ]
        )
        let focusedFrame = CGRect(x: 100, y: 100, width: 600, height: 400)

        overlayProvider.annotationsToReturn = [
            SystemContextCollector.UITreeOverlayAnnotation(
                ref: "e1",
                frame: CGRect(x: 140, y: 170, width: 200, height: 40),
                role: "textbox",
                name: "输入标题",
                isFocused: true,
                isInteractive: true,
                isNearCursor: true
            )
        ]

        let sut = SystemContextCollector.DefaultScreenshotCollector(
            overlayAnnotationProvider: overlayProvider,
            overlayRenderer: overlayRenderer,
            pointerLocator: pointerLocator,
            liveOverlayPresenter: liveOverlayPresenter
        )

        capture.focusedResult = ScreenCaptureManager.CurrentWindowCaptureResult(
            image: makeImage(),
            windowFrame: focusedFrame,
            windowID: 777,
            processID: 5151
        )
        capture.fullResult = ScreenCaptureManager.FullScreenCaptureResult(
            image: makeImage(),
            displayFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        capture.base64Results = ["focused", "full"]

        _ = await sut.collect(using: capture)

        XCTAssertEqual(liveOverlayPresenter.callCount, 1)
        XCTAssertEqual(liveOverlayPresenter.lastDisplayFrame, focusedFrame)
        XCTAssertEqual(liveOverlayPresenter.lastAnnotationsCount, 1)
    }

    @available(macOS 14, *)
    func test_collect_capturesFullScreenBeforePresentingLiveOverlay() async {
        let capture = MockScreenCaptureManager()
        let overlayProvider = MockOverlayProvider()
        let overlayRenderer = MockOverlayRenderer()
        let liveOverlayPresenter = MockLiveOverlayPresenter()
        let pointerLocator = MockPointerLocator(
            points: [
                CGPoint(x: 120, y: 160),
                CGPoint(x: 126, y: 164),
            ]
        )

        overlayProvider.annotationsToReturn = [
            SystemContextCollector.UITreeOverlayAnnotation(
                ref: "e1",
                frame: CGRect(x: 140, y: 170, width: 200, height: 40),
                role: "textbox",
                name: "输入标题",
                isFocused: true,
                isInteractive: true,
                isNearCursor: true
            )
        ]

        let presentAfterFullCapture = expectation(description: "present occurs after full-screen capture")
        liveOverlayPresenter.onPresent = {
            if capture.fullCaptureCallCount == 1 {
                presentAfterFullCapture.fulfill()
            }
        }

        let sut = SystemContextCollector.DefaultScreenshotCollector(
            overlayAnnotationProvider: overlayProvider,
            overlayRenderer: overlayRenderer,
            pointerLocator: pointerLocator,
            liveOverlayPresenter: liveOverlayPresenter
        )

        capture.focusedResult = ScreenCaptureManager.CurrentWindowCaptureResult(
            image: makeImage(),
            windowFrame: CGRect(x: 100, y: 100, width: 600, height: 400),
            windowID: 777,
            processID: 5151
        )
        capture.fullResult = ScreenCaptureManager.FullScreenCaptureResult(
            image: makeImage(),
            displayFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        capture.base64Results = ["full", "focused"]

        _ = await sut.collect(using: capture)
        await fulfillment(of: [presentAfterFullCapture], timeout: 1.0)
    }

    private func makeImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            fatalError("Failed to create test CGContext")
        }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let image = context.makeImage() else {
            fatalError("Failed to create test CGImage")
        }
        return image
    }
}

@MainActor
private final class MockScreenCaptureManager: ScreenCaptureManaging {
    var focusedResult: ScreenCaptureManager.CurrentWindowCaptureResult?
    var fullResult: ScreenCaptureManager.FullScreenCaptureResult?
    var focusedError: Error?
    var fullError: Error?
    var base64Results: [String?] = []
    private(set) var imageToBase64CallCount = 0
    private(set) var focusedCaptureCallCount = 0
    private(set) var fullCaptureCallCount = 0

    @available(macOS 14, *)
    func captureCurrentWindowWithMetadata() async throws -> ScreenCaptureManager.CurrentWindowCaptureResult {
        focusedCaptureCallCount += 1
        if let focusedError {
            throw focusedError
        }
        guard let focusedResult else {
            fatalError("focusedResult must be set in test")
        }
        return focusedResult
    }

    @available(macOS 14, *)
    func captureFullScreenWithMetadata() async throws -> ScreenCaptureManager.FullScreenCaptureResult {
        fullCaptureCallCount += 1
        if let fullError {
            throw fullError
        }
        guard let fullResult else {
            fatalError("fullResult must be set in test")
        }
        return fullResult
    }

    func imageToBase64(_ image: CGImage, quality: CGFloat) -> String? {
        imageToBase64CallCount += 1
        guard !base64Results.isEmpty else {
            return nil
        }
        return base64Results.removeFirst()
    }
}

private final class MockOverlayProvider: SystemContextCollector.UITreeOverlayAnnotationProviding {
    private(set) var lastProcessID: pid_t?
    var annotationsToReturn: [SystemContextCollector.UITreeOverlayAnnotation] = []

    func buildAnnotations(
        processID: pid_t,
        displayFrame: CGRect
    ) -> [SystemContextCollector.UITreeOverlayAnnotation] {
        lastProcessID = processID
        return annotationsToReturn
    }
}

private final class MockCaretLocator: SystemContextCollector.CaretLocating {
    struct Call {
        let processID: pid_t
        let frame: CGRect
    }

    private(set) var calls: [Call] = []
    var result: CGPoint? = nil

    func locateCaret(processID: pid_t, targetFrame: CGRect) -> CGPoint? {
        calls.append(Call(processID: processID, frame: targetFrame))
        return result
    }
}

final class MockPointerLocator: SystemContextCollector.PointerLocating {
    private var points: [CGPoint?]
    private(set) var callCount = 0

    init(points: [CGPoint?]) {
        self.points = points
    }

    @MainActor
    func currentPointerLocation() -> CGPoint? {
        callCount += 1
        guard !points.isEmpty else {
            return nil
        }
        return points.removeFirst()
    }
}

@MainActor
private final class MockOverlayRenderer: SystemContextCollector.UITreeOverlayRendering {
    func render(
        baseImage: CGImage,
        displayFrame: CGRect,
        cursorLocation: CGPoint?,
        annotations: [SystemContextCollector.UITreeOverlayAnnotation]
    ) -> CGImage? {
        baseImage
    }
}

@MainActor
private final class MockLiveOverlayPresenter: SystemContextCollector.UITreeLiveOverlayPresenting {
    private(set) var callCount = 0
    private(set) var lastDisplayFrame: CGRect?
    private(set) var lastAnnotationsCount: Int?
    var onPresent: (() -> Void)?

    func present(
        displayFrame: CGRect,
        cursorLocation: CGPoint?,
        annotations: [SystemContextCollector.UITreeOverlayAnnotation]
    ) {
        callCount += 1
        lastDisplayFrame = displayFrame
        lastAnnotationsCount = annotations.count
        onPresent?()
    }
}

final class CursorLocationPolicyTests: XCTestCase {
    private let frame = CGRect(x: 100, y: 100, width: 600, height: 400)

    func test_resolve_whenCaretInsideFrame_returnsCaret() {
        let policy = SystemContextCollector.CursorLocationPolicy()

        let result = policy.resolve(
            caret: CGPoint(x: 200, y: 200),
            before: CGPoint(x: 300, y: 300),
            after: CGPoint(x: 400, y: 300),
            targetFrame: frame
        )

        XCTAssertEqual(result, CGPoint(x: 200, y: 200))
    }

    func test_resolve_whenCaretOutsideAndAfterInside_returnsAfter() {
        let policy = SystemContextCollector.CursorLocationPolicy()

        let result = policy.resolve(
            caret: CGPoint(x: 10, y: 10),
            before: CGPoint(x: 10, y: 10),
            after: CGPoint(x: 400, y: 300),
            targetFrame: frame
        )

        XCTAssertEqual(result, CGPoint(x: 400, y: 300))
    }

    func test_resolve_whenOnlyBeforeInside_returnsBefore() {
        let policy = SystemContextCollector.CursorLocationPolicy()

        let result = policy.resolve(
            caret: nil,
            before: CGPoint(x: 260, y: 180),
            after: CGPoint(x: 20, y: 20),
            targetFrame: frame
        )

        XCTAssertEqual(result, CGPoint(x: 260, y: 180))
    }

    func test_resolve_whenNoPointInside_returnsNil() {
        let policy = SystemContextCollector.CursorLocationPolicy()

        let result = policy.resolve(
            caret: CGPoint(x: 10, y: 10),
            before: CGPoint(x: 20, y: 20),
            after: CGPoint(x: 30, y: 30),
            targetFrame: frame
        )

        XCTAssertNil(result)
    }
}
