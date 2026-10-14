import SwiftUI
import AppKit
import Observation

/// Native tool surfaces expose geometry and one execution boundary to the drag coordinator.
@MainActor protocol CardToolDropSurface: AnyObject {
    var toolScreenFrame: CGRect? { get }
    var toolSymbol: String { get }
    var toolNumber: Int { get }
    func setCardTargeted(_ targeted: Bool)
    func acceptCardText(_ text: String) -> Bool
}

/// Presents the dragged card in the same glass container as its tool targets.
@MainActor @Observable final class CardDragPresentation {
    static let shared = CardDragPresentation()
    private(set) var surface: AnyView?
    private(set) var frame = CGRect.zero
    private(set) var ownerFrame = CGRect.zero
    private(set) var inside = false
    private(set) var opacity: Double = 1
    var targetFrame: CGRect?
    var targetSymbol = "wand.and.stars"
    var targetNumber = 1
    @ObservationIgnored private weak var owner: NSWindow?
    @ObservationIgnored private let tools = NSHashTable<NSView>.weakObjects()
    @ObservationIgnored private weak var selectedTool: (any CardToolDropSurface)?
    @ObservationIgnored private var delivered = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var origin = CGRect.zero
    @ObservationIgnored private var offset = CGPoint.zero
    @ObservationIgnored private var nativeComponents: [NSDraggingImageComponent] = []

    func begin(surface: AnyView, frame: CGRect, window: NSWindow?, nativeItem: NSDraggingItem) {
        generation = UUID()
        clearTarget()
        delivered = false
        self.surface = surface
        self.frame = frame
        origin = frame
        owner = window
        ownerFrame = window?.frame ?? .zero
        let pointer = NSEvent.mouseLocation
        offset = CGPoint(x: pointer.x - frame.minX, y: pointer.y - frame.minY)
        inside = canPresentWholeCard
        opacity = 1
        nativeComponents = nativeItem.imageComponents ?? []
        if inside { nativeItem.imageComponentsProvider = { [] } }
    }
    func move(to point: CGPoint, session: NSDraggingSession) {
        ownerFrame = owner?.frame ?? ownerFrame
        frame.origin = CGPoint(x: point.x - offset.x, y: point.y - offset.y)
        selectTool(at: point)
        let nextInside = canPresentWholeCard
        guard nextInside != inside else { return }
        inside = nextInside
        let components = nativeComponents
        session.enumerateDraggingItems(options: [], for: nil, classes: [NSPasteboardItem.self], searchOptions: [:]) { item, _, _ in
            item.imageComponentsProvider = nextInside ? { [] } : { components }
        }
    }
    func registerTool(_ view: NSView) { tools.add(view) }
    func unregisterTool(_ view: NSView) {
        tools.remove(view)
        if let selected = selectedTool, (selected as AnyObject) === view { clearTarget() }
    }

    private func clearTarget() {
        selectedTool?.setCardTargeted(false)
        selectedTool = nil
        targetFrame = nil
    }

    private func selectTool(at pointer: CGPoint) {
        guard surface != nil, ownerFrame.contains(pointer), !delivered else { clearTarget(); return }
        let candidates = tools.allObjects.compactMap { view -> (any CardToolDropSurface, CGRect, CGFloat)? in
            guard view.window === owner, let tool = view as? any CardToolDropSurface,
                  let rect = tool.toolScreenFrame else { return nil }
            // The card's top edge, rather than its grip point, approaches one circular target.
            guard let score = CardToolGeometry.connectionScore(card: frame, tool: rect) else { return nil }
            return (tool, rect, score)
        }
        guard let best = candidates.min(by: {
            $0.2 == $1.2 ? $0.0.toolNumber < $1.0.toolNumber : $0.2 < $1.2
        }) else { clearTarget(); return }
        if selectedTool !== best.0 {
            clearTarget()
            selectedTool = best.0
            best.0.setCardTargeted(true)
        }
        if targetFrame != best.1 { targetFrame = best.1 }
        if targetSymbol != best.0.toolSymbol { targetSymbol = best.0.toolSymbol }
        if targetNumber != best.0.toolNumber { targetNumber = best.0.toolNumber }
    }

    /// Both native destination and source-release callbacks deliver at most once.
    func deliver(_ text: String, to tool: any CardToolDropSurface) -> Bool {
        guard !delivered, selectedTool === tool else { return false }
        delivered = true
        guard tool.acceptCardText(text) else { delivered = false; return false }
        return true
    }

    func deliverOnRelease(at point: CGPoint, text: String?) -> Bool {
        selectTool(at: point)
        guard let text, let selectedTool else { return false }
        return deliver(text, to: selectedTool)
    }

    /// Window-local glass must never replace a native image that extends beyond the window.
    private var canPresentWholeCard: Bool {
        ownerFrame.contains(frame.insetBy(dx: -12, dy: -12))
    }

    func finish(cancelled: Bool, returnFrame: CGRect? = nil, completion: @escaping () -> Void) {
        let finishingGeneration = generation
        clearTarget()
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        withAnimation(reduced ? nil : .easeInOut(duration: 0.22), completionCriteria: .removed) {
            if cancelled { frame = returnFrame ?? origin }
            if !cancelled { opacity = 0 }
        } completion: { [weak self] in
            if self?.generation == finishingGeneration {
                self?.surface = nil
                self?.owner = nil
            }
            completion()
        }
    }
}

/// Renders the same card content above history, sharing native glass merging with the toolbar.
struct CardDragOverlay: View {
    @Namespace private var namespace
    private let drag = CardDragPresentation.shared
    @ViewBuilder private func identifiedSurface(_ surface: AnyView) -> some View {
        if #available(macOS 26.0, *) {
            surface
                .glassEffect(.regular, in: DragToolCardShape(
                    radius: Constants.Card.cornerRadius,
                    connectionX: drag.targetFrame.map { $0.midX - drag.frame.minX } ?? drag.frame.width / 2,
                    connectionHeight: drag.targetFrame == nil ? 0 : 18))
                .glassEffectID("dragged-card", in: namespace)
                .animation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeInOut(duration: 0.18),
                           value: drag.targetFrame)
        } else { surface.compatibleGlassEffect(cornerRadius: Constants.Card.cornerRadius, interactive: false) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if drag.inside, let surface = drag.surface {
                identifiedSurface(surface)
                    .frame(width: drag.frame.width, height: drag.frame.height)
                    .position(x: drag.frame.midX - drag.ownerFrame.minX,
                              y: drag.ownerFrame.maxY - drag.frame.midY)
                    .opacity(drag.opacity)
                if let target = drag.targetFrame {
                    targetSurface
                        .frame(width: target.width, height: target.height)
                        .position(x: target.midX - drag.ownerFrame.minX,
                                  y: drag.ownerFrame.maxY - target.midY)
                }
            }
        }
        .compatibleGlassGroup(spacing: 26)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var targetSurface: some View {
        if #available(macOS 26.0, *) {
            Image(systemName: drag.targetSymbol)
                .font(.pingFang(size: SearchBarConfig.default.iconSize))
                .overlay(alignment: .bottomTrailing) {
                    Text("\(drag.targetNumber)").font(.pingFang(size: 8)).offset(x: 8, y: 7)
                }
                .frame(width: SearchBarConfig.default.buttonSize, height: SearchBarConfig.default.buttonSize)
                .foregroundStyle(.primary)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("selected-tool", in: namespace)
                .scaleEffect(1.16)
        }
    }

}

/// A small top-edge lobe points toward the single native drop destination.
private struct DragToolCardShape: Shape {
    let radius: CGFloat
    var connectionX: CGFloat
    var connectionHeight: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(connectionX, connectionHeight) }
        set { connectionX = newValue.first; connectionHeight = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: radius)
        if connectionX > radius, connectionX < rect.width - radius, connectionHeight > 0 {
            path.addEllipse(in: CGRect(x: connectionX - 20, y: -connectionHeight, width: 40,
                                       height: connectionHeight + 12))
        }
        return path
    }
}

/// Scores a local top-edge connection independently of the mouse grip or window focus.
enum CardToolGeometry {
    static func connectionScore(card: CGRect, tool: CGRect) -> CGFloat? {
        guard !card.isEmpty, !tool.isEmpty else { return nil }
        let vertical = abs(card.maxY - tool.minY)
        let horizontal = abs(card.midX - tool.midX)
        guard vertical <= 30, tool.midX >= card.minX + 20, tool.midX <= card.maxX - 20,
              horizontal <= tool.width / 2 + 36 else { return nil }
        return horizontal + vertical * 0.25
    }
}
