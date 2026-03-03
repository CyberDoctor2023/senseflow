//
//  OpenClawUITreeLiveOverlayPresenter.swift
//  SenseFlow
//

import AppKit

final class OpenClawUITreeLiveOverlayPresenter: SystemContextCollector.UITreeLiveOverlayPresenting, SmartAILiveOverlaySessionControlling, @unchecked Sendable {
    private let overlayRenderer: any SystemContextCollector.UITreeOverlayRendering
    private var overlayPanel: NSPanel?
    private let imageView = NSImageView(frame: .zero)
    private var hideTask: Task<Void, Never>?
    private var activeSessionCount = 0

    init(
        overlayRenderer: any SystemContextCollector.UITreeOverlayRendering = OpenClawUITreeOverlayRenderer()
    ) {
        self.overlayRenderer = overlayRenderer
    }

    deinit {
        hideTask?.cancel()
    }

    @MainActor
    func present(
        displayFrame: CGRect,
        cursorLocation: CGPoint?,
        annotations: [SystemContextCollector.UITreeOverlayAnnotation]
    ) {
        guard displayFrame.width > 0, displayFrame.height > 0 else {
            return
        }

        let overlayDisplayFrame = resolveOverlayDisplayFrame(containing: displayFrame) ?? displayFrame
        guard let overlayImage = makeOverlayImage(
            displayFrame: overlayDisplayFrame,
            cursorLocation: cursorLocation,
            annotations: annotations
        ) else {
            return
        }

        ensureOverlayPanel(frame: overlayDisplayFrame)
        imageView.image = NSImage(
            cgImage: overlayImage,
            size: NSSize(width: overlayDisplayFrame.width, height: overlayDisplayFrame.height)
        )

        showOverlayPanel()
        if !isSessionActive {
            scheduleHide(after: BusinessRules.Animation.overlayVisibleDuration)
        }
    }

    @MainActor
    func beginSession() {
        activeSessionCount += 1
        hideTask?.cancel()
    }

    @MainActor
    func endSession() {
        activeSessionCount = max(0, activeSessionCount - 1)
        if activeSessionCount == 0 {
            scheduleHide(after: BusinessRules.Animation.overlayPostSessionHoldDuration)
        }
    }

    @MainActor
    private func makeOverlayImage(
        displayFrame: CGRect,
        cursorLocation: CGPoint?,
        annotations: [SystemContextCollector.UITreeOverlayAnnotation]
    ) -> CGImage? {
        let width = max(Int(displayFrame.width.rounded()), 1)
        let height = max(Int(displayFrame.height.rounded()), 1)

        guard let transparentBase = makeTransparentBaseImage(width: width, height: height) else {
            return nil
        }

        return overlayRenderer.render(
            baseImage: transparentBase,
            displayFrame: displayFrame,
            cursorLocation: cursorLocation,
            annotations: annotations
        )
    }

    @MainActor
    private func resolveOverlayDisplayFrame(containing frame: CGRect) -> CGRect? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) })?.frame
    }

    private func makeTransparentBaseImage(width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    @MainActor
    private func ensureOverlayPanel(frame: CGRect) {
        if overlayPanel == nil {
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.level = .statusBar
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]

            imageView.imageScaling = .scaleAxesIndependently
            imageView.wantsLayer = true
            imageView.layer?.backgroundColor = NSColor.clear.cgColor
            imageView.autoresizingMask = [.width, .height]
            panel.contentView = imageView
            overlayPanel = panel
        }

        overlayPanel?.setFrame(frame, display: false)
        imageView.frame = NSRect(origin: .zero, size: frame.size)
    }

    @MainActor
    private func showOverlayPanel() {
        guard let panel = overlayPanel else {
            return
        }

        hideTask?.cancel()
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { _ in
                panel.animator().alphaValue = 1
            }
            return
        }

        panel.orderFrontRegardless()
        panel.alphaValue = 1
    }

    @MainActor
    private func scheduleHide(after duration: UInt64) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !self.isSessionActive else { return }
                self.hideOverlayPanel()
            }
        }
    }

    @MainActor
    private var isSessionActive: Bool {
        activeSessionCount > 0
    }

    @MainActor
    private func hideOverlayPanel() {
        guard let panel = overlayPanel else {
            return
        }

        NSAnimationContext.runAnimationGroup({ _ in
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}
