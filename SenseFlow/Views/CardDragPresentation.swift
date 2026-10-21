import SwiftUI
import AppKit

/// Native tool surfaces expose geometry and one execution boundary to the drag coordinator.
@MainActor protocol CardToolDropSurface: AnyObject {
    var toolScreenFrame: CGRect? { get }
    var toolNumber: Int { get }
    func setCardTargeted(_ targeted: Bool)
    func acceptCardText(_ text: String) -> Bool
}

/// Coordinates tool highlighting; AppKit owns the single drag image and copy badge.
@MainActor final class CardDragPresentation {
    static let shared = CardDragPresentation()
    private weak var owner: NSWindow?
    private let tools = NSHashTable<NSView>.weakObjects()
    private weak var selectedTool: (any CardToolDropSurface)?
    private var delivered = false

    func begin(window: NSWindow?) {
        clearTarget()
        owner = window
        delivered = false
    }

    func move(to point: CGPoint) { selectTool(at: point) }
    func registerTool(_ view: NSView) { tools.add(view) }
    func unregisterTool(_ view: NSView) {
        tools.remove(view)
        if let selected = selectedTool, (selected as AnyObject) === view { clearTarget() }
    }

    private func clearTarget() {
        selectedTool?.setCardTargeted(false)
        selectedTool = nil
    }

    private func selectTool(at point: CGPoint) {
        guard let owner, !delivered else { clearTarget(); return }
        let target = tools.allObjects.first { view in
            guard view.window === owner || view.window?.parent === owner,
                  let tool = view as? any CardToolDropSurface,
                  let rect = tool.toolScreenFrame else { return false }
            return rect.contains(point)
        } as? any CardToolDropSurface
        if selectedTool !== target {
            clearTarget()
            selectedTool = target
            target?.setCardTargeted(true)
        }
    }

    /// Executes only after AppKit accepts a native drop, at most once per session.
    func deliver(_ text: String, to tool: any CardToolDropSurface, at point: CGPoint) -> Bool {
        selectTool(at: point)
        guard !delivered, selectedTool === tool else { return false }
        delivered = true
        guard tool.acceptCardText(text) else { delivered = false; return false }
        return true
    }

    func finish() {
        clearTarget()
        owner = nil
    }
}

/// Expands a visual shell around a stable layout slot without shifting its center.
enum CardVisualGeometry {
    static func frame(slot: CGRect, scale: CGFloat) -> CGRect {
        slot.insetBy(dx: -slot.width * (scale - 1) / 2,
                     dy: -slot.height * (scale - 1) / 2)
    }
}
