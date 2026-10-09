import SwiftUI
import AppKit

/// TextKit 2 owns a single text storage; SwiftUI observes only session metadata.
struct NativeDocumentEditor: NSViewRepresentable {
    let session: DocumentPreviewCoordinator

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(frame: CGRect(origin: .zero, size: CGSize(width: max(1, session.previewSize.width - 28), height: max(1, session.previewSize.height - 52))))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.contentView.drawsBackground = false
        let text = DocumentTextView(usingTextLayoutManager: true)
        text.isRichText = false
        text.isEditable = false
        text.isSelectable = true
        text.allowsUndo = true
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.textContainerInset = .zero
        text.font = NSFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15)
        text.drawsBackground = false
        text.backgroundColor = .clear
        text.textColor = .textColor
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.frame = CGRect(origin: .zero, size: scroll.contentSize)
        text.textContainer?.containerSize = NSSize(width: max(1, scroll.contentSize.width), height: CGFloat.greatestFiniteMagnitude)
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.delegate = context.coordinator
        text.onBeginEditing = { [weak session] in session?.beginEditing() }
        scroll.documentView = text
        session.attachEditor(text)
        context.coordinator.itemID = session.source?.itemID
        context.coordinator.revision = session.source?.revision
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Loading is tied to document identity, never to keystrokes or geometry updates.
        guard context.coordinator.itemID != session.source?.itemID || context.coordinator.revision != session.source?.revision,
              let text = nsView.documentView as? DocumentTextView else { return }
        context.coordinator.itemID = session.source?.itemID
        context.coordinator.revision = session.source?.revision
        session.attachEditor(text)
    }

    func makeCoordinator() -> Delegate { Delegate(session: session) }

    final class Delegate: NSObject, NSTextViewDelegate {
        var itemID: Int64?
        var revision: String?
        weak var session: DocumentPreviewCoordinator?
        init(session: DocumentPreviewCoordinator) { self.session = session }
        func textDidChange(_ notification: Notification) { session?.textDidChange() }
    }
}

/// Keeps UTF-16 selection, marked text, undo and viewport layout inside AppKit.
final class DocumentTextView: NSTextView, DocumentEditor {
    var onBeginEditing: (() -> Void)?
    var isComposing: Bool { hasMarkedText() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        onBeginEditing?()
        super.mouseDown(with: event)
    }
    func textSnapshot() -> String { string }
    func load(text: String) {
        string = text
        undoManager?.removeAllActions()
        setSelectedRange(NSRange(location: 0, length: 0))
    }
    func setEditable(_ editable: Bool) { isEditable = editable }
    func focus() { window?.makeFirstResponder(self) }
}
