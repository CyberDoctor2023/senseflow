import SwiftUI
import AppKit
import QuartzCore

/// A bounded summary with an explicit full-document affordance.
struct ClipboardCardView: View {
    let item: ClipboardItem
    let actions: HistoryActionCoordinator
    let thumbnails: ClipboardThumbnailLoader
    var onPointerPresenceChanged: ((Bool) -> Void)? = nil
    @Environment(\.clipboardOnboarding) private var onboarding
    @Environment(\.displayScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: CGImage?
    @State private var hovered = false
    @State private var pressed = false
    @State private var dragging = false

    private var isPreviewSource: Bool { actions.documents.source?.itemID == item.id }
    private var isRaised: Bool { hovered || isPreviewSource }
    private var cardScale: CGFloat { reduceMotion ? 1 : pressed ? 1.10 : isRaised ? Constants.SelectionFeedback.scale : 1 }
    var body: some View {
        cardContent
        .padding(14)
        .frame(width: Constants.Card.width, height: Constants.Card.height)
        .scaleEffect(cardScale, anchor: .center)
        // Size the native glass shell around the scaled contents, then keep its
        // center inside an unchanged history slot. Do not transform the glass layer.
        .frame(width: Constants.Card.width * cardScale, height: Constants.Card.height * cardScale)
        .compatibleGlassEffect(cornerRadius: Constants.Card.cornerRadius * cardScale, interactive: false)
        .clipShape(.rect(cornerRadius: Constants.Card.cornerRadius * cardScale))
        .frame(width: Constants.Card.width, height: Constants.Card.height, alignment: .center)
        .environment(\.appearsActive, true)
        .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: hovered)
        .animation(reduceMotion ? nil : .smooth(duration: Constants.SelectionFeedback.duration), value: isPreviewSource)
        .animation(reduceMotion ? nil : .easeInOut(duration: pressed ? 0.45 : 0.2), value: pressed)
        .opacity(dragging ? 0.25 : 1)
        .background(CardPointerRegion(isPreviewSource: isPreviewSource, dragSurface: AnyView(dragSurface), loadDragItem: {
            try await actions.makeDragPasteboardItem(item)
        }, onDragStateChanged: { active in
            dragging = active
            actions.setDragging(active)
        }, onEnter: { bounds in
            hovered = true
            onPointerPresenceChanged?(true)
            actions.documents.pointerEntered(item, anchor: bounds)
        }, onLeave: {
            hovered = false
            onPointerPresenceChanged?(false)
            actions.documents.pointerLeft(item.id)
        }, onPressChanged: {
            pressed = $0
            actions.setPressed($0, itemID: item.id)
        }, onSelect: {
            actions.select(item)
        }, onPreview: { bounds in
            if item.type == .video {
                pressed = false
                actions.previewRecording(item)
                return
            }
            let intent = actions.documents.beginPointerPreviewIntent()
            // The native pointer region retains the unscaled layout slot. Match
            // the expanded press surface so the window does not restart at 100%.
            let start = reduceMotion ? bounds : bounds.insetBy(dx: -bounds.width * 0.05,
                                                              dy: -bounds.height * 0.05)
            actions.documents.togglePointerPreview(item, anchor: start, expectedRequest: intent)
        }))
        .contentShape(RoundedRectangle(cornerRadius: Constants.Card.cornerRadius))
        .focusable()
        .focusEffectDisabled()
        .onDisappear { pressed = false; actions.setPressed(false, itemID: item.id); onPointerPresenceChanged?(false) }
        .onChange(of: actions.documents.isLoading) { _, loading in
            if !loading { pressed = false }
        }
        .task(id: item.uniqueId) {
            if item.type != .text {
                let result = await thumbnails.thumbnail(for: item, pixels: Int(180 * scale))
                guard !Task.isCancelled else { return }
                image = result
            }
        }
    }
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            contentPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            sourceFooter
        }
    }
    private var dragSurface: some View {
        cardContent.padding(14)
            .frame(width: Constants.Card.width, height: Constants.Card.height)
            .compatibleGlassEffect(cornerRadius: Constants.Card.cornerRadius, interactive: false)
            .environment(\.appearsActive, true)
    }

    private var sourceFooter: some View {
        HStack(spacing: 6) {
            Image(nsImage: item.appIcon).resizable().frame(width: 14, height: 14)
            Text(item.appName.lowercased() == "senseflow" ? "senseflow" : item.appName).lineLimit(1)
            Spacer(minLength: 4)
            Text(item.relativeTimeString)
        }.font(.pingFang(size: 10)).foregroundStyle(.secondary)
    }

    @ViewBuilder private var contentPreview: some View {
        if item.type == .text {
            Text(item.previewText)
                .font(.pingFang(size: 13))
                .lineLimit(nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let displayImage = image {
            Image(decorative: displayImage, scale: scale).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if item.type == .video {
                        Image(systemName: "video.fill").font(.pingFang(size: 22))
                            .foregroundStyle(.white).shadow(radius: 3)
                    }
                }
        } else {
            Image(systemName: item.type.iconName).font(.pingFang(.largeTitle)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Converts real card bounds to screen coordinates without geometry work in the body.
struct CardPointerRegion: NSViewRepresentable {
    let isPreviewSource: Bool
    let dragSurface: AnyView
    var isEnabled: Bool = true
    let loadDragItem: () async throws -> NSPasteboardItem
    let onDragStateChanged: (Bool) -> Void
    let onEnter: (CGRect) -> Void
    let onLeave: () -> Void
    let onPressChanged: (Bool) -> Void
    let onSelect: () -> Void
    let onPreview: (CGRect) -> Void
    func makeNSView(context: Context) -> PointerView {
        let view = PointerView()
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ view: PointerView, context: Context) {
        view.onEnter = onEnter; view.onLeave = onLeave; view.onPreview = onPreview
        view.onPressChanged = onPressChanged; view.onSelect = onSelect
        view.isEnabled = isEnabled
        view.isPreviewSource = isPreviewSource
        view.loadDragItem = loadDragItem
        view.onDragStateChanged = onDragStateChanged
        view.dragSurface = dragSurface
    }
    static func dismantleNSView(_ view: PointerView, coordinator: ()) { view.stopMonitoring() }
    final class PointerView: NSView, NSDraggingSource, HistoryCardSurface {
        var isEnabled = true {
            didSet { if !isEnabled { cancelHold() } }
        }
        var isPreviewSource = false
        var loadDragItem: (() async throws -> NSPasteboardItem)?
        var onDragStateChanged: ((Bool) -> Void)?
        var dragSurface: AnyView?
        private var dragTask: Task<Void, Never>?
        private var dragSessionActive = false
        private var pressOrigin: NSPoint?
        var onEnter: ((CGRect) -> Void)?
        var onLeave: (() -> Void)?
        var onPreview: ((CGRect) -> Void)?
        var onPressChanged: ((Bool) -> Void)?
        var onSelect: (() -> Void)?
        private var holdTimer: Timer?
        private var heldButton: Int?
        private var holdTriggered = false
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown, .rightMouseUp, .leftMouseUp, .rightMouseDragged, .leftMouseDragged, .scrollWheel]) { [weak self] event in
                guard let self, self.isEnabled else { return event }
                if event.type == .scrollWheel { self.cancelHold(); return event }
                if event.type == .leftMouseUp || event.type == .rightMouseUp {
                    guard self.heldButton == event.buttonNumber else { return event }
                    let selectOnRelease = !self.holdTriggered
                    let releasedInside = self.window.map { window in
                        event.window === window && self.bounds.contains(self.convert(event.locationInWindow, from: nil))
                    } ?? false
                    self.cancelHold()
                    if selectOnRelease && releasedInside { self.onSelect?() }
                    return nil
                }
                guard let window = self.window, event.window === window else { return event }
                let inside = self.bounds.contains(self.convert(event.locationInWindow, from: nil))
                if event.type == .leftMouseDragged || event.type == .rightMouseDragged {
                    guard self.heldButton == event.buttonNumber else { return event }
                    if event.type == .leftMouseDragged, !self.holdTriggered, let origin = self.pressOrigin,
                       hypot(event.locationInWindow.x - origin.x, event.locationInWindow.y - origin.y) > 6 {
                        self.holdTimer?.invalidate(); self.holdTimer = nil
                        self.holdTriggered = true
                        self.beginCardDrag(event)
                        return nil
                    }
                    if !inside { self.cancelHold() }
                    return nil
                }
                guard inside else { return event }
                self.cancelHold()
                self.heldButton = event.buttonNumber
                self.pressOrigin = event.locationInWindow
                self.onPressChanged?(true)
                let timer = Timer(timeInterval: 0.45, repeats: false) { [weak self] _ in
                    guard let self, let window = self.window, let button = self.heldButton,
                          window.isVisible, NSEvent.pressedMouseButtons & (1 << button) != 0,
                          self.bounds.contains(self.convert(window.mouseLocationOutsideOfEventStream, from: nil)) else {
                        self?.cancelHold()
                        return
                    }
                    self.holdTimer = nil
                    self.holdTriggered = true
                    self.onPreview?(window.convertToScreen(self.convert(self.bounds, to: nil)))
                }
                self.holdTimer = timer
                RunLoop.main.add(timer, forMode: .common)
                return nil
            }
        }
        func stopMonitoring() {
            cancelHold()
            cancelPendingDrag()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
        private func cancelHold() {
            holdTimer?.invalidate(); holdTimer = nil
            heldButton = nil
            pressOrigin = nil
            holdTriggered = false
            onPressChanged?(false)
        }
        func cancelPendingDrag() { dragTask?.cancel(); dragTask = nil }
        private func beginCardDrag(_ event: NSEvent) {
            guard dragTask == nil, !dragSessionActive, let loader = loadDragItem,
                  let root = window?.contentView else { return }
            let rect = convert(bounds, to: root)
            let sourceFrame = window?.convertToScreen(root.convert(rect, to: nil)) ?? .zero
            let image = NSImage(size: bounds.size) // The native session carries payload; the live panel renders the card.
            dragTask = Task { @MainActor [weak self] in
                guard let self else { return }
                defer { if !Task.isCancelled { self.dragTask = nil } }
                do {
                    let payload = try await loader()
                    guard !Task.isCancelled else { return }
                    guard self.window?.isVisible == true,
                          NSEvent.pressedMouseButtons & 1 != 0 else { self.cancelHold(); return }
                    let item = NSDraggingItem(pasteboardWriter: payload)
                    item.setDraggingFrame(self.bounds, contents: image)
                    if let surface = self.dragSurface {
                        CardDragPresentation.shared.begin(surface: surface, frame: sourceFrame)
                    }
                    self.dragSessionActive = true
                    self.onDragStateChanged?(true)
                    let session = self.beginDraggingSession(with: [item], event: event, source: self)
                    session.animatesToStartingPositionsOnCancelOrFail = true
                } catch { if !Task.isCancelled { self.cancelHold() } }
            }
        }
        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
        func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
            CardDragPresentation.shared.move(to: screenPoint)
        }
        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            CardDragPresentation.shared.finish(cancelled: operation.isEmpty)
            dragSessionActive = false
            cancelHold()
            onDragStateChanged?(false)
        }
        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
        private var tracking: NSTrackingArea?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
            addTrackingArea(area); tracking = area
        }
        override func mouseEntered(with event: NSEvent) {
            guard let window else { return }
            onEnter?(window.convertToScreen(convert(bounds, to: nil)))
        }
        override func mouseExited(with event: NSEvent) { cancelHold(); onLeave?() }
    }
}

/// A live native glass surface follows the drag; the drag-local pasteboard remains independent.
@MainActor final class CardDragPresentation {
    static let shared = CardDragPresentation()
    private var panel: NSPanel?
    private var origin = CGRect.zero
    private var offset = CGPoint.zero
    private var target: CGRect?
    private var pointer = CGPoint.zero

    func begin(surface: AnyView, frame: CGRect) {
        panel?.orderOut(nil)
        origin = frame
        pointer = NSEvent.mouseLocation
        offset = CGPoint(x: pointer.x - frame.minX, y: pointer.y - frame.minY)
        target = nil
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.contentView = NSHostingView(rootView: GeometryReader { geometry in
            surface
                .frame(width: frame.width, height: frame.height)
                .scaleEffect(min(geometry.size.width / max(frame.width, 1), geometry.size.height / max(frame.height, 1)))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        })
        self.panel = panel
        panel.orderFrontRegardless()
    }
    func move(to point: CGPoint) {
        pointer = point
        guard target == nil else { return }
        panel?.setFrameOrigin(CGPoint(x: point.x - offset.x, y: point.y - offset.y))
    }
    func attract(to frame: CGRect) {
        guard let panel else { return }
        target = frame
        var attracted = origin
        attracted.origin = CGPoint(x: frame.midX - origin.width / 2, y: frame.midY - origin.height / 2)
        animate(panel, frame: attracted, close: false)
    }
    func releaseTarget() {
        target = nil
        move(to: pointer)
    }
    func finish(cancelled: Bool) {
        guard let panel else { return }
        let destination: CGRect
        if cancelled { destination = origin }
        else if let target { destination = target }
        else { destination = panel.frame }
        self.panel = nil
        target = nil
        animate(panel, frame: destination, close: true)
    }
    private func animate(_ panel: NSPanel, frame: CGRect, close: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
            if close { panel.animator().alphaValue = 0 }
        } completionHandler: {
            if close { panel.orderOut(nil); panel.contentView = nil }
        }
    }
}
