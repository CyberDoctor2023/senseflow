import AppKit
import SwiftUI
import QuartzCore

enum DocumentCloseChoice { case save, keepDraft, discard, cancel }

/// Window layout and close dialogs contain no persistence logic.
@MainActor final class DocumentWindowHost: NSObject, NSWindowDelegate {
    private var panel: DocumentPanel?
    private var preparedView: NSHostingView<FloatingPreviewView>?
    private var didPrepare = false
    private var soundPreparation: Task<Void, Never>?
    private let previewSound: NSSound? = {
        let sound = NSSound(named: NSSound.Name("Pop"))
        sound?.volume = 0.22
        return sound
    }()
    private let workspace: WorkspaceWindowCoordinator
    var onClose: (() -> Void)?
    var onPin: (() -> Void)?
    var onSave: (() -> Void)?
    var onPointerDismiss: (() -> Bool)?
    private var localDismissMonitor: Any?
    private var globalDismissMonitor: Any?
    private var transitionID = UUID()
    private var isClosing = false
    private var cardFrame = CGRect.zero
    private weak var session: DocumentPreviewCoordinator?
    private(set) var isTransitioning = false
    var frame: CGRect? { panel?.isVisible == true ? panel?.frame : nil }

    private let onboarding: ClipboardOnboardingCoordinator?
    init(workspace: WorkspaceWindowCoordinator, onboarding: ClipboardOnboardingCoordinator? = nil) {
        self.workspace = workspace
        self.onboarding = onboarding
    }

    /// Prepares the real native surface once, without reading content or showing a window.
    func prepare(session: DocumentPreviewCoordinator) {
        guard !didPrepare, panel == nil, session.source == nil else { return }
        didPrepare = true
        // Prepare audio output away from the first hold threshold, without an audible cue.
        previewSound?.volume = 0
        previewSound?.play()
        soundPreparation = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, !Task.isCancelled else { return }
            self.previewSound?.stop()
            self.previewSound?.volume = 0.22
            self.soundPreparation = nil
        }
        let size = session.previewSize
        let window = DocumentPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        let view = NSHostingView(rootView: FloatingPreviewView(session: session, snapshot: nil, image: nil, contentSize: size, onboarding: onboarding))
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        preparedView = view
        panel = window
    }

    /// Confirms the accepted hold at its threshold, before asynchronous content loading.
    func playPressConfirmation() {
        soundPreparation?.cancel()
        soundPreparation = nil
        previewSound?.stop()
        previewSound?.volume = 0.22
        previewSound?.play()
    }

    func present(session: DocumentPreviewCoordinator, anchor: CGRect, sample: String, imageAspectRatio: CGFloat? = nil, hasMoreText: Bool = false) throws {
        // Initialize glass in the same application state used after clicking the editor.
        NSApp.activate(ignoringOtherApps: true)
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: anchor.midX, y: anchor.midY)) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { throw DocumentStoreError.unavailable }
        let width = min(760, visible.width * 0.82)
        let sampleHeight = (sample as NSString).boundingRect(with: NSSize(width: max(width - 64, 1), height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: [.font: (NSFont(name: "PingFangSC-Regular", size: 15) ?? NSFont.systemFont(ofSize: 15))]).height
        let contentHeight = imageAspectRatio.map { width / max($0, 0.1) } ?? (hasMoreText ? visible.height * 0.7 : sampleHeight)
        let historyTop = NSApp.windows.first(where: { workspace.contains($0) && $0.isVisible && $0.frame.contains(CGPoint(x: anchor.midX, y: anchor.midY)) })?.frame.maxY ?? anchor.maxY
        let remaining = max(180, visible.maxY - historyTop - 16)
        let height = min(max(220, contentHeight + 100), visible.height * 0.78, remaining)
        let targetY = min(visible.maxY - height, historyTop + 16)
        let target = CGRect(x: visible.midX - width / 2, y: max(visible.minY, targetY), width: width, height: height)
        let sourceFrame = anchor.width > 0 && anchor.height > 0 ? anchor : target
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let start = sourceFrame
        let window = panel ?? DocumentPanel(contentRect: start, styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        transitionID = UUID()
        let token = transitionID
        isClosing = false
        cardFrame = sourceFrame
        self.session = session
        session.previewSize = target.size
        session.previewContentVisible = false
        session.previewWindowNumber = window.windowNumber
        isTransitioning = true
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.allowsInput = true
        window.appearance = NSApp.effectiveAppearance
        window.level = .popUpMenu
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.alphaValue = 1
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: min(180, visible.width), height: min(180, visible.height))
        window.title = String(sample.split(whereSeparator: { $0.isNewline }).first?.prefix(48) ?? "文本预览")
        window.onSave = { [weak self] in self?.onSave?() }
        window.onClose = { [weak self] in self?.onClose?() }
        let content = FloatingPreviewView(session: session, snapshot: session.source, image: session.imagePreview, contentSize: target.size, onboarding: onboarding)
        let view: NSHostingView<FloatingPreviewView>
        if let preparedView {
            view = preparedView
            view.rootView = content
            self.preparedView = nil
        } else {
            view = NSHostingView(rootView: content)
        }
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = view
        window.setFrame(start, display: false)
        view.layoutSubtreeIfNeeded()
        panel = window
        workspace.register(window)
        window.makeKeyAndOrderFront(nil)
        startDismissMonitoring()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reducedMotion ? 0 : 0.32
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.8, 0.22, 1)
            window.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            guard let self, self.transitionID == token else { return }
            self.isTransitioning = false
            self.session?.previewContentVisible = true
        }
    }

    func hideRetainingSession() {
        stopDismissMonitoring()
        transitionID = UUID()
        isTransitioning = false
        isClosing = false
        panel?.orderOut(nil)
    }
    func showRetainedSession() {
        panel?.alphaValue = 1
        panel?.hasShadow = true
        panel?.orderFrontRegardless()
        startDismissMonitoring()
    }

    func activateEditor() {
        panel?.allowsInput = true
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }
    /// Moving history cards cannot be targeted with the cached opening frame.
    func close(returnToCard: Bool = true) {
        guard let panel, panel.isVisible, !isClosing else { return }
        stopDismissMonitoring()
        isClosing = true
        transitionID = UUID()
        let token = transitionID
        panel.allowsInput = false
        panel.resignKey()
        session?.previewContentVisible = false
        isTransitioning = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : returnToCard ? 0.48 : 0.16
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.8, 0.22, 1)
            if returnToCard { panel.animator().setFrame(cardFrame, display: true) }
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.transitionID == token else { return }
            panel.orderOut(nil)
            panel.contentView = nil
            self.isClosing = false
            self.isTransitioning = false
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { onClose?(); return false }

    private func startDismissMonitoring() {
        guard localDismissMonitor == nil, panel?.isVisible == true else { return }
        localDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel?.isVisible == true, !self.isClosing else { return event }
            guard event.window !== self.panel else { return event }
            if let window = event.window, self.workspace.contains(window),
               self.workspace.containsCard(in: window, at: event.locationInWindow) { return event }
            _ = self.onPointerDismiss?()
            return event
        }
        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.panel?.isVisible == true, !self.isClosing else { return }
                _ = self.onPointerDismiss?()
            }
        }
    }

    private func stopDismissMonitoring() {
        if let localDismissMonitor { NSEvent.removeMonitor(localDismissMonitor) }
        if let globalDismissMonitor { NSEvent.removeMonitor(globalDismissMonitor) }
        localDismissMonitor = nil
        globalDismissMonitor = nil
    }

    deinit {
        if let localDismissMonitor { NSEvent.removeMonitor(localDismissMonitor) }
        if let globalDismissMonitor { NSEvent.removeMonitor(globalDismissMonitor) }
    }
    func windowWillMove(_ notification: Notification) { if !isTransitioning { onPin?() } }
    func windowWillStartLiveResize(_ notification: Notification) { if !isTransitioning { onPin?() } }

    func fitRemainingScreen() {
        guard let panel, panel.isVisible,
              !NSScreen.screens.contains(where: { $0.visibleFrame.contains(panel.frame) }),
              let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.size.width = min(frame.width, visible.width)
        frame.size.height = min(frame.height, visible.height)
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        panel.setFrame(frame, display: true)
    }

    func closeChoice() -> DocumentCloseChoice {
        let alert = NSAlert()
        alert.messageText = "保留这次修改？"
        alert.informativeText = "原始记录不会被修改。可以保存新记录、保留草稿，或放弃当前修改。"
        ["保存为新记录", "保留草稿", "放弃修改", "取消"].forEach { alert.addButton(withTitle: $0) }
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .keepDraft
        case .alertThirdButtonReturn: return .discard
        default: return .cancel
        }
    }
}

private final class DocumentPanel: NSPanel {
    var allowsInput = false
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?
    override var canBecomeKey: Bool { allowsInput }
    override var canBecomeMain: Bool { false }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            switch event.charactersIgnoringModifiers {
            case "s": onSave?(); return true
            case "w": onClose?(); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    override func cancelOperation(_ sender: Any?) { onClose?() }
}

/// Preview owns its geometry; the history view never consumes this surface's size.
private struct FloatingPreviewView: View {
    let session: DocumentPreviewCoordinator
    let snapshot: DocumentSnapshot?
    let image: CGImage?
    let contentSize: CGSize
    let onboarding: ClipboardOnboardingCoordinator?
    var body: some View {
        GeometryReader { geometry in
            previewContent
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .compatibleGlassEffect(cornerRadius: Constants.Card.cornerRadius, interactive: false)
        .clipShape(.rect(cornerRadius: Constants.Card.cornerRadius))
        .onboardingTarget(.preview)
        .contextualOnboarding(onboarding, inPreview: true)
        .overlay(alignment: .topTrailing) {
            if session.previewContentVisible {
                Button { session.requestClose() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                    .buttonStyle(.plain).padding(8)
            }
        }
        .containerBackground(.clear, for: .window)
        .environment(\.appearsActive, true)
        .environment(\.clipboardOnboarding, onboarding)
        .onChange(of: session.previewContentVisible) { _, visible in
            if visible { onboarding?.previewOpened() }
        }
        .onChange(of: session.source?.itemID) { _, sourceID in
            if sourceID == nil { onboarding?.previewClosed() }
        }
        .onDisappear {
            if session.source == nil { onboarding?.previewClosed() }
        }
    }
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                } else {
                    DocumentPreviewView(session: session)
                        .frame(width: max(1, contentSize.width - 28), height: max(1, contentSize.height - 52))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .clipped()
                        .allowsHitTesting(session.previewContentVisible)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 6) {
                Image(nsImage: AppIconCache.shared.icon(forPath: snapshot?.appPath ?? ""))
                    .resizable().frame(width: 14, height: 14)
                Text(snapshot?.appName.lowercased() == "senseflow" ? "senseflow" : snapshot?.appName ?? "预览").lineLimit(1)
                Spacer()
                if let snapshot { Text(ClipboardItem.relativeTimeString(timestamp: snapshot.timestamp)) }
            }.font(.pingFang(size: 10)).foregroundStyle(.secondary)
        }
        .padding(14)
    }
}
