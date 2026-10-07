//
//  ScreenCaptureManager.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-22.
//

import ScreenCaptureKit
import CoreGraphics
import AppKit

@MainActor
protocol ScreenCaptureManaging: AnyObject, Sendable {
    @available(macOS 14, *)
    func captureCurrentWindowWithMetadata() async throws -> ScreenCaptureManager.CurrentWindowCaptureResult

    @available(macOS 14, *)
    func captureFullScreenWithMetadata() async throws -> ScreenCaptureManager.FullScreenCaptureResult

    func imageToBase64(_ image: CGImage, quality: CGFloat) -> String?
}

/// Screen capture manager for Smart feature
/// Handles screenshot capture using ScreenCaptureKit
@MainActor
class ScreenCaptureManager: ScreenCaptureManaging {
    static let shared = ScreenCaptureManager()

    struct CurrentWindowCaptureResult {
        let image: CGImage
        let windowFrame: CGRect
        let windowID: UInt32
        let processID: pid_t
    }

    struct FullScreenCaptureResult {
        let image: CGImage
        let displayFrame: CGRect
    }

    private init() {}

    // MARK: - Permission Check

    /// Check if Screen Recording permission is granted
    func checkPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /// Request Screen Recording permission
    /// This will show the system permission dialog if not already granted
    /// - Returns: true if permission is granted, false otherwise
    func requestPermission() -> Bool {
        // First check if already granted
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        // Request permission - this will show system dialog
        let granted = CGRequestScreenCaptureAccess()

        if granted {
            print("✅ Screen Recording permission granted")
        } else {
            print("⚠️ Screen Recording permission denied")
        }

        return granted
    }

    /// Request permission with async/await
    @MainActor
    func requestPermissionAsync() async -> Bool {
        return requestPermission()
    }

    // MARK: - Screenshot Capture

    /// Capture screenshot of current window
    /// Automatically requests permission if not granted
    /// - Returns: CGImage of the captured window
    /// - Throws: ScreenCaptureError if capture fails
    @available(macOS 14, *)
    func captureCurrentWindow() async throws -> CGImage {
        let result = try await captureCurrentWindowWithMetadata()
        return result.image
    }

    /// Capture screenshot of current frontmost window with its global frame metadata.
    /// Used to align UI-tree overlays directly on focused-app image.
    @available(macOS 14, *)
    func captureCurrentWindowWithMetadata() async throws -> CurrentWindowCaptureResult {
        // Request permission if not granted
        if !checkPermission() {
            let granted = await requestPermissionAsync()
            if !granted {
                throw ScreenCaptureError.permissionDenied
            }
        }

        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)

        // 精准选择前台应用的前置窗口，而不是 windows.first
        guard let frontWindow = selectFrontmostWindow(from: content.windows) else {
            throw ScreenCaptureError.noWindowAvailable
        }

        let windowImage = try await captureWindowImage(for: frontWindow)

        let captureProcessID =
            frontWindow.owningApplication?.processID ??
            selectTargetProcessID(from: content.windows) ??
            NSWorkspace.shared.frontmostApplication?.processIdentifier ??
            ProcessInfo.processInfo.processIdentifier

        return CurrentWindowCaptureResult(
            image: windowImage,
            windowFrame: frontWindow.frame,
            windowID: frontWindow.windowID,
            processID: captureProcessID
        )
    }

    /// Capture full screen screenshot (fallback)
    /// Automatically requests permission if not granted
    /// - Returns: CGImage of the entire screen
    /// - Throws: ScreenCaptureError if capture fails
    @available(macOS 14, *)
    func captureFullScreen() async throws -> CGImage {
        let result = try await captureFullScreenWithMetadata()
        return result.image
    }

    /// Capture full screen screenshot with the selected display frame metadata.
    /// Used by overlay renderer to map global AX coordinates to screenshot pixels.
    @available(macOS 14, *)
    func captureFullScreenWithMetadata() async throws -> FullScreenCaptureResult {
        // Request permission if not granted
        if !checkPermission() {
            let granted = await requestPermissionAsync()
            if !granted {
                throw ScreenCaptureError.permissionDenied
            }
        }

        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)

        guard let display = selectPreferredDisplay(from: content) else {
            throw ScreenCaptureError.noDisplayAvailable
        }

        let image = try await captureDisplayImage(for: display)

        return FullScreenCaptureResult(
            image: image,
            displayFrame: display.frame
        )
    }

    /// Capture screenshot around current mouse cursor position.
    /// Uses ScreenCaptureKit region API to provide local visual intent evidence.
    @available(macOS 15.2, *)
    func captureCursorNeighborhood(width: CGFloat = 900, height: CGFloat = 520) async throws -> CGImage {
        if !checkPermission() {
            let granted = await requestPermissionAsync()
            if !granted {
                throw ScreenCaptureError.permissionDenied
            }
        }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })?.frame
        let rawRect = CGRect(
            x: mouseLocation.x - width / 2,
            y: mouseLocation.y - height / 2,
            width: width,
            height: height
        )
        let captureRect = screenFrame?.intersection(rawRect) ?? rawRect
        guard !captureRect.isNull, captureRect.width > 0, captureRect.height > 0 else {
            throw ScreenCaptureError.captureFailedUnknown
        }

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: captureRect) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenCaptureError.captureFailedUnknown)
                }
            }
        }
    }

    // MARK: - Target Selection

    /// 选择前台应用的前置窗口（优先 CGWindowList 前置顺序，回退最大窗口）
    @available(macOS 14, *)
    private func selectFrontmostWindow(from windows: [SCWindow]) -> SCWindow? {
        guard let frontAppPID = selectTargetProcessID(from: windows) else {
            return windows.first
        }

        let appWindows = windows.filter { window in
            guard let owningPID = window.owningApplication?.processID else { return false }
            return owningPID == frontAppPID
        }

        guard !appWindows.isEmpty else {
            return selectLargestWindow(from: windows)
        }

        // 1) 优先使用辅助功能焦点窗口信息（最接近用户“当前焦点窗口”语义）
        if let focusedAXWindow = getFocusedAXWindowContext(processID: frontAppPID),
           let matchedWindow = matchSCWindow(appWindows, with: focusedAXWindow) {
            return matchedWindow
        }

        // 2) 使用 CGWindowList 的最前窗口 ID
        if let frontWindowID = findTopWindowID(for: frontAppPID),
           let exactWindow = appWindows.first(where: { $0.windowID == frontWindowID }) {
            if isTinyWindow(exactWindow, comparedWith: appWindows) {
                // 最前窗口过小（菜单/浮层），回退主窗口策略
                return selectLargestWindow(from: appWindows)
            }
            return exactWindow
        }

        // 3) 回退：选面积最大的窗口，避免拿到小图标/浮窗
        return selectLargestWindow(from: appWindows)
    }

    /// 选择真正需要截图的目标进程（避免 SenseFlow 自己成为前台时截到自身窗口）
    @available(macOS 14, *)
    private func selectTargetProcessID(from windows: [SCWindow]) -> pid_t? {
        let selfPID = ProcessInfo.processInfo.processIdentifier

        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.processIdentifier != selfPID {
            return frontApp.processIdentifier
        }

        if let topWindowOwnerPID = findTopWindowOwnerPID(excluding: selfPID) {
            return topWindowOwnerPID
        }

        return windows
            .compactMap { $0.owningApplication?.processID }
            .first(where: { $0 != selfPID })
    }

    /// 选择优先显示器（前台窗口所在屏 > 鼠标所在屏 > 首屏）
    @available(macOS 14, *)
    private func selectPreferredDisplay(from content: SCShareableContent) -> SCDisplay? {
        guard !content.displays.isEmpty else {
            return nil
        }

        if let targetDisplayID = preferredDisplayID(from: content.windows),
           let targetDisplay = content.displays.first(where: { $0.displayID == targetDisplayID }) {
            return targetDisplay
        }

        return content.displays.first
    }

    /// 计算期望显示器 ID
    @available(macOS 14, *)
    private func preferredDisplayID(from windows: [SCWindow]) -> CGDirectDisplayID? {
        if let frontWindow = selectFrontmostWindow(from: windows) {
            let centerPoint = CGPoint(x: frontWindow.frame.midX, y: frontWindow.frame.midY)
            if let displayID = displayID(containing: centerPoint) {
                return displayID
            }
        }

        // 回退：鼠标所在屏
        let mouseLocation = NSEvent.mouseLocation
        return displayID(containing: mouseLocation)
    }

    private func displayID(containing point: CGPoint) -> CGDirectDisplayID? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else {
            return nil
        }

        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    /// 从 CGWindowList 获取指定进程最前层窗口 ID（层级 0）
    private func findTopWindowID(for processID: pid_t) -> UInt32? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in rawWindowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == processID else {
                continue
            }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else {
                continue
            }

            if let windowNumber = windowInfo[kCGWindowNumber as String] as? NSNumber {
                return windowNumber.uint32Value
            }
        }

        return nil
    }

    /// 从 CGWindowList 获取最前层窗口的拥有者进程（排除当前应用）
    private func findTopWindowOwnerPID(excluding excludedPID: pid_t) -> pid_t? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in rawWindowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != excludedPID else {
                continue
            }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else {
                continue
            }

            return ownerPID
        }

        return nil
    }

    private func selectLargestWindow(from windows: [SCWindow]) -> SCWindow? {
        windows.max { lhs, rhs in
            (lhs.frame.width * lhs.frame.height) < (rhs.frame.width * rhs.frame.height)
        }
    }

    @available(macOS 14, *)
    private func captureDisplayImage(for display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.showsCursor = true

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenCaptureError.captureFailedUnknown)
                }
            }
        }
    }

    @available(macOS 14, *)
    private func captureWindowImage(for window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scaleFactor = preferredScaleFactor(for: window.frame)
        config.width = max(1, Int((window.frame.width * scaleFactor).rounded()))
        config.height = max(1, Int((window.frame.height * scaleFactor).rounded()))
        config.ignoreShadowsSingleWindow = true
        config.showsCursor = true
        if #available(macOS 14.2, *) {
            config.includeChildWindows = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenCaptureError.captureFailedUnknown)
                }
            }
        }
    }

    private func preferredScaleFactor(for windowFrame: CGRect) -> CGFloat {
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return max(1, screen.backingScaleFactor)
        }
        if let main = NSScreen.main {
            return max(1, main.backingScaleFactor)
        }
        return 2.0
    }

    /// 判断是否是异常小窗口（例如 App 图标窗、面板）
    private func isTinyWindow(_ target: SCWindow, comparedWith allWindows: [SCWindow]) -> Bool {
        let targetArea = target.frame.width * target.frame.height
        guard let maxArea = allWindows
            .map({ $0.frame.width * $0.frame.height })
            .max(),
              maxArea > 0 else {
            return false
        }

        // 小于最大窗口面积 12% 视为可疑小窗
        return targetArea / maxArea < 0.12
    }

    // MARK: - AX Focus Window Matching

    private struct AXWindowContext {
        let title: String?
        let size: CGSize?
    }

    /// 获取前台应用的辅助功能焦点窗口信息
    private func getFocusedAXWindowContext(processID: pid_t) -> AXWindowContext? {
        let appElement = AXUIElementCreateApplication(processID)

        var focusedWindowValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )
        guard status == .success,
              let focusedWindowValue,
              CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID() else {
            return nil
        }

        let focusedWindowElement = focusedWindowValue as! AXUIElement

        var titleValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(
            focusedWindowElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        var sizeValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(
            focusedWindowElement,
            kAXSizeAttribute as CFString,
            &sizeValue
        )

        let title = titleValue as? String
        let size = decodeAXSize(from: sizeValue)

        if title == nil && size == nil {
            return nil
        }

        return AXWindowContext(title: title, size: size)
    }

    /// 将 AX 焦点窗口映射为 SCWindow
    private func matchSCWindow(_ windows: [SCWindow], with axWindow: AXWindowContext) -> SCWindow? {
        if let title = axWindow.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty,
           let titleMatch = windows.first(where: { ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == title }) {
            return titleMatch
        }

        if let axSize = axWindow.size {
            let scored = windows.map { window -> (window: SCWindow, score: CGFloat) in
                let score = abs(window.frame.width - axSize.width) + abs(window.frame.height - axSize.height)
                return (window, score)
            }
            if let best = scored.min(by: { $0.score < $1.score }),
               best.score < 140 {
                return best.window
            }
        }

        return nil
    }

    private func decodeAXSize(from value: CFTypeRef?) -> CGSize? {
        guard let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }
        return size
    }

    // MARK: - Image Conversion

    /// Convert CGImage to Base64 encoded JPEG string
    /// - Parameters:
    ///   - image: The CGImage to convert
    ///   - quality: JPEG compression quality (0.0-1.0), default 0.7
    /// - Returns: Base64 encoded string or nil if conversion fails
    func imageToBase64(_ image: CGImage, quality: CGFloat = BusinessRules.Encryption.defaultJPEGQuality) -> String? {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        guard let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            return nil
        }

        return jpegData.base64EncodedString()
    }
}

// MARK: - Error Types

enum ScreenCaptureError: LocalizedError {
    case noWindowAvailable
    case noDisplayAvailable
    case captureFailedUnknown
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noWindowAvailable:
            return "No window available for capture"
        case .noDisplayAvailable:
            return "No display available for capture"
        case .captureFailedUnknown:
            return "Screenshot capture failed"
        case .permissionDenied:
            return "Screen Recording permission denied"
        }
    }
}
