import Foundation
import AppKit
import SwiftUI
import CryptoKit
@testable import SenseFlow

/// Focused verification uses production storage/editor code and a private database.
/// No application launch, clipboard capture, provider request or user history access.
@main struct DocumentWorkflowVerification {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        Task { @MainActor in
            do { try await verify(); exit(0) }
            catch { fputs("FAIL document verification: \(error)\n", stderr); exit(1) }
        }
        app.run()
    }

    @MainActor private static func verify() async throws {
        if let index = CommandLine.arguments.firstIndex(of: "--log-file"), index + 1 < CommandLine.arguments.count {
            let path = CommandLine.arguments[index + 1]
            guard freopen(path, "w", stdout) != nil, freopen(path + ".stderr", "w", stderr) != nil else {
                throw Failure("verification log could not be opened")
            }
        }
        setbuf(stdout, nil)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let run = output.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: run, withIntermediateDirectories: true)
        let store = DatabaseManager(databaseURL: run.appendingPathComponent("history.sqlite"))
        let repository = DocumentRepository(store: store)
        let original = String(repeating: "原始段落：emoji 👩🏽‍💻，换行保持。\r\n", count: 4200)
        let inserted = try await store.performStoreOperation {
            store.insertItem(.init(type: .text, textContent: original, appName: "Verification", appPath: nil))
        }
        try require(inserted, "source inserted")
        let summaries = try await store.fetchRecentItemsAsync()
        try require(summaries.count == 1 && summaries[0].isSummary, "summary-only list")
        guard let excerpt = summaries[0].textContent else { throw Failure("summary missing") }
        try require(excerpt.count <= 1025 && excerpt.count > 100 && original.utf8.starts(with: excerpt.utf8), "summary bounded and contains actual source prefix")
        let sourceItem = summaries[0]
        let detail = try await repository.loadDetail(itemID: sourceItem.id, revision: sourceItem.uniqueId)
        try require(detail.textContent == original, "full text and mixed line endings preserved")
        let source = DocumentSnapshot(itemID: detail.id, revision: detail.uniqueId, text: original, appName: detail.appName, appPath: nil, timestamp: detail.timestamp)
        let duplicate = try await store.performStoreOperation {
            store.insertItem(.init(type: .text, textContent: original, appName: "Verification", appPath: nil))
        }
        let repeated = try await store.fetchRecentItemsAsync()
        try require(duplicate && repeated.first?.id == sourceItem.id, "capture dedup preserves identity")
        let edited = original + "\n编辑后的版本"
        let requestID = UUID()
        let newID = try await repository.saveDerived(text: edited, source: source, requestID: requestID)
        let retryID = try await repository.saveDerived(text: edited, source: source, requestID: requestID)
        let sameTextID = try await repository.saveDerived(text: edited, source: source, requestID: UUID())
        let unchanged = try await repository.loadDetail(itemID: sourceItem.id, revision: sourceItem.uniqueId)
        try require(newID != sourceItem.id && retryID == newID && sameTextID == newID && unchanged.textContent == original, "derived save idempotent and source immutable")
        let sessionID = UUID()
        try await repository.checkpoint(DocumentDraft(sessionID: sessionID, source: source, generation: 8, text: edited))
        do {
            try await repository.checkpoint(DocumentDraft(sessionID: sessionID, source: source, generation: 7, text: "older"))
            throw Failure("older checkpoint accepted")
        } catch DocumentStoreError.stale { print("PASS stale checkpoint rejected") }
        let reopened = DatabaseManager(databaseURL: run.appendingPathComponent("history.sqlite"))
        let recovered = try await DocumentRepository(store: reopened).recover(sourceID: sourceItem.id)
        try require(recovered?.text == edited && recovered?.generation == 8, "durable draft recovered from reopened store")
        do {
            try await repository.discard(sessionID: sessionID, generation: 7)
            throw Failure("stale discard accepted")
        } catch DocumentStoreError.stale { print("PASS stale discard rejected") }
        try await repository.discard(sessionID: sessionID, generation: 8)
        let discarded = try await repository.recover(sourceID: sourceItem.id)
        try require(discarded == nil, "explicit discard removes only draft")

        // Initialize AppKit without starting SenseFlow's app delegate or global services.
        let writer = RecordingWriter()
        let workspace = WorkspaceWindowCoordinator()
        let host = DocumentWindowHost(workspace: workspace)
        let coordinator = DocumentPreviewCoordinator(repository: repository, writer: writer, host: host)
        let (nativeWindow, model) = await makeSurface(store: store, repository: repository, coordinator: coordinator, workspace: workspace, writer: writer)
        try await Task.sleep(nanoseconds: 100_000_000)
        if CommandLine.arguments.contains("--scroll-only") {
            for index in 0..<202 {
                _ = try await store.performStoreOperation { store.insertItem(.init(type: .text, textContent: "滚动记录 \(index)", appName: "Scroll", appPath: nil)) }
            }
            await model.loadItems()
            nativeWindow.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 150_000_000)
            try await verifyHistoryWheel(nativeWindow)
            try require(model.items.count == 204, "scroll geometry automatically appends the second history page")
            print("PASS scroll verification completed")
            nativeWindow.close()
            return
        }
        let searchBefore = screenBounds(findTextField(nativeWindow.contentView))
        let baseFrame = nativeWindow.frame
        let windowCount = NSApp.windows.count
        let frozenIDs = model.items.map(\.id)
        model.isWindowPinned = true
        _ = try await store.performStoreOperation { store.insertItem(.init(type: .text, textContent: "锁定之后的新内容", appName: "LockedCapture", appPath: nil)) }
        await model.loadItems()
        try require(model.items.map(\.id) == frozenIDs, "pin freezes displayed records while new capture is stored")
        let beforeDragText = writer.text
        let dragText = try await model.actions.makeDragPasteboardItem(sourceItem)
        try require(dragText.string(forType: .string) == original && writer.text == beforeDragText, "drag carries full original text without changing the clipboard writer")
        model.isWindowPinned = false
        await model.loadItems()
        try require(model.items.contains { $0.appName == "LockedCapture" }, "unpin resumes newly captured history")

        let retentionStore = DatabaseManager(databaseURL: run.appendingPathComponent("locked-retention.sqlite"))
        _ = try await retentionStore.performStoreOperation { retentionStore.insertItem(.init(type: .text, textContent: "保留的锁定原文", appName: "Retained", appPath: nil)) }
        guard let retained = try await retentionStore.fetchRecentItemsAsync().first else { throw Failure("retained source missing") }
        for index in 0..<202 {
            _ = try await retentionStore.performStoreOperation { retentionStore.insertItem(.init(type: .text, textContent: "分页记录 \(index)", appName: "New", appPath: nil)) }
        }
        let firstPage = try await retentionStore.fetchRecentItemsAsync(limit: 200)
        let secondPage = try await retentionStore.fetchRecentItemsAsync(limit: 200, offset: 200)
        try require(firstPage.count == 200 && secondPage.count == 3 && Set((firstPage + secondPage).map(\.id)).count == 203,
            "history beyond 200 records survives and pages contain distinct summaries")
        try require((firstPage + secondPage).contains { $0.id == retained.id }, "old original survives automatic capture without a retention cap")
        let pagedModel = ClipboardListViewModel(repository: DatabaseClipboardRepository(databaseManager: retentionStore),
                                                actions: model.actions, thumbnails: model.thumbnails)
        await pagedModel.loadItems()
        try require(pagedModel.items.count == 200, "history model initially loads one bounded page")
        pagedModel.isWindowPinned = true
        await pagedModel.loadMoreIfNeeded(after: pagedModel.items.last?.id)
        try require(pagedModel.items.count == 200, "pinned history does not append older pages")
        pagedModel.isWindowPinned = false
        await pagedModel.loadItems()
        await pagedModel.loadMoreIfNeeded(after: pagedModel.items.last?.id)
        try require(pagedModel.items.count == 203 && Set(pagedModel.items.map(\.id)).count == 203,
            "reaching the last card appends the next page without duplicates")
        for width in [CGFloat(600), 1280, 2560] {
            nativeWindow.setFrame(CGRect(x: -width / 3, y: 80, width: width, height: baseFrame.height), display: true)
            nativeWindow.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 100_000_000)
            guard let cardView = cardTrackingViews(nativeWindow.contentView).min(by: { (screenBounds($0)?.minX ?? .infinity) < (screenBounds($1)?.minX ?? .infinity) }),
                  let card = screenBounds(cardView), let viewport = screenBounds(cardView.enclosingScrollView?.contentView) else { throw Failure("card or scroll viewport missing") }
            let backgroundLeft = nativeWindow.frame.minX + Constants.ClipboardWindow.shadowBleedHorizontal
            let backgroundBottom = nativeWindow.frame.minY + Constants.ClipboardWindow.shadowBleedBottom
            let backgroundTop = backgroundBottom + MainContainerLayoutConfig.default.windowHeight(cardConfig: .default)
            try require(abs(card.minX - backgroundLeft - 28) < 1 && abs(card.minY - backgroundBottom - 28) < 1 && abs(backgroundTop - card.maxY - 28) < 1 && abs(nativeWindow.frame.maxX - Constants.ClipboardWindow.shadowBleedHorizontal - viewport.maxX) < 1 && abs(nativeWindow.frame.width - width) < 1 && nativeWindow.frame.minX < 0, "production card insets and full-width viewport match at viewport width \(Int(width)) with negative screen origin")
        }
        nativeWindow.setFrame(baseFrame, display: true)
        nativeWindow.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        let anchor = CGRect(x: baseFrame.minX + 220, y: baseFrame.minY + 40, width: 180, height: 180)
        coordinator.pointerEntered(sourceItem, anchor: anchor)
        try await Task.sleep(nanoseconds: 400_000_000)
        try require(coordinator.source == nil && !coordinator.isLoading && host.frame == nil, "brief hover only highlights without loading or preview")
        try await Task.sleep(nanoseconds: 1_200_000_000)
        try require(coordinator.source == nil && !coordinator.isLoading && host.frame == nil, "sustained hover never loads or opens preview")
        let stalePress = coordinator.beginPointerPreviewIntent()
        let latestPress = coordinator.beginPointerPreviewIntent()
        coordinator.preview(sourceItem, anchor: anchor, pinOnOpen: false, expectedRequest: stalePress)
        try await Task.sleep(nanoseconds: 50_000_000)
        try require(coordinator.source == nil && !coordinator.isLoading, "older card press cannot override a newer right-click intent")
        coordinator.preview(sourceItem, anchor: anchor, pinOnOpen: false, expectedRequest: latestPress)
        coordinator.pointerLeft(sourceItem.id)
        try await waitUntil { coordinator.source != nil && findTextView(previewWindow(host)?.contentView) != nil }
        let transitionEditor = findTextView(previewWindow(host)?.contentView)
        try await waitUntil { !host.isTransitioning }
        try require(transitionEditor != nil && transitionEditor === findTextView(previewWindow(host)?.contentView), "same native text view survives expansion without placeholder replacement")
        coordinator.preview(sourceItem, anchor: anchor, pinOnOpen: false)
        try require(!coordinator.isPinned && transitionEditor === findTextView(previewWindow(host)?.contentView), "pointer preview reuses current surface without pinning or rebuilding")
        print("MEASURE initial preview: original=\(coordinator.source?.text == original), editing=\(coordinator.isEditing), key=\(previewWindow(host)?.isKeyWindow == true), editable=\(transitionEditor?.isEditable == true), applicationActive=\(NSApp.isActive), keyWindow=\(NSApp.keyWindow?.windowNumber ?? -1), previewWindow=\(coordinator.previewWindowNumber ?? -1)")
        try require(coordinator.source?.text == original && !coordinator.isEditing && previewWindow(host)?.isKeyWindow == true && transitionEditor?.isEditable == false, "first reading preview has stable key appearance while its native editor remains read-only")
        try require(NSApp.windows.count == windowCount + 1 && nativeWindow.frame == baseFrame, "separate preview leaves history window geometry unchanged")
        let searchAfter = screenBounds(findTextField(nativeWindow.contentView))
        try require(searchBefore != nil && searchAfter != nil && abs((searchBefore?.minY ?? 0) - (searchAfter?.minY ?? 1)) < 1, "production search baseline remains fixed while card grows above backdrop")
        let longHeight = coordinator.previewSize.height
        let closeIntent = coordinator.beginPointerPreviewIntent()
        coordinator.togglePointerPreview(sourceItem, anchor: anchor, expectedRequest: closeIntent)
        try require(coordinator.source == nil, "second right-click dismisses current reading preview")
        try await waitUntil { !host.isTransitioning }
        let reopenIntent = coordinator.beginPointerPreviewIntent()
        coordinator.togglePointerPreview(sourceItem, anchor: anchor, expectedRequest: reopenIntent)
        do {
            try await waitUntil { coordinator.source != nil && !host.isTransitioning }
        } catch {
            print("DIAGNOSTIC reopen: source=\(coordinator.source != nil), loading=\(coordinator.isLoading), transition=\(host.isTransitioning), visible=\(host.frame != nil), error=\(coordinator.errorMessage ?? "none"), status=\(coordinator.status)")
            throw error
        }
        try require(coordinator.source?.itemID == sourceItem.id, "next right-click reopens the same card")
        try require(previewWindow(host)?.isKeyWindow == true, "reopened preview uses the same key appearance as the first opening")
        guard let backgroundClick = NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 4, y: 4), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: nativeWindow.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        ) else { throw Failure("background left-click construction failed") }
        NSApp.sendEvent(backgroundClick)
        try require(coordinator.source == nil && host.isTransitioning,
            "real AppKit background left-click starts animated dismissal")
        try await waitUntil { !host.isTransitioning }
        try require(!coordinator.dismissPointerPreview(), "dismissed preview cannot consume the next opening press")
        coordinator.preview(sourceItem, anchor: anchor, pinOnOpen: false)
        try await waitUntil { coordinator.source != nil && !host.isTransitioning }
        guard let textView = findTextView(previewWindow(host)?.contentView) else { throw Failure("native editor missing") }
        try require(textView.textLayoutManager != nil && textView.string == original, "TextKit 2 renders full 100k document")
        try require(textView.bounds.width > 300, "native document has valid width before full text layout")
        if let scroll = textView.enclosingScrollView {
            let before = scroll.contentView.bounds.origin.y
            scroll.contentView.scroll(to: NSPoint(x: scroll.contentView.bounds.origin.x, y: before + 160))
            scroll.reflectScrolledClipView(scroll.contentView)
            try require(scroll.contentView.bounds.origin.y > before && scroll.hasVerticalScroller, "floating document exposes vertical scroll viewport")
        } else { throw Failure("document scroll view missing") }
        coordinator.beginEditing()
        try require(coordinator.isPinned && coordinator.isEditing && textView.isEditable, "editing pins same native buffer")
        coordinator.historyHidden()
        try require(host.frame == nil && coordinator.isEditing && textView.string == original, "workspace hide preserves editing buffer")
        coordinator.historyShown()
        try require(host.frame != nil && findTextView(previewWindow(host)?.contentView) === textView, "workspace restore retains native editor identity")
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
        textView.insertText("🧪编辑", replacementRange: textView.selectedRange())
        try require(textView.string.hasSuffix("🧪编辑"), "native unicode input")
        textView.undoManager?.undo()
        try require(textView.string == original, "native undo restores original")
        textView.undoManager?.redo()
        try require(textView.string.hasSuffix("🧪编辑"), "native redo restores edit")
        textView.setMarkedText("中文组合", selectedRange: NSRange(location: 0, length: 4), replacementRange: textView.selectedRange())
        try require(textView.hasMarkedText(), "marked text tracked")
        coordinator.save()
        try await waitUntil { coordinator.errorMessage != nil }
        try require(coordinator.errorMessage != nil, "save blocked while composing")
        textView.unmarkText()
        coordinator.pointerEntered(repeated[0], anchor: anchor)
        try require(coordinator.source?.itemID == sourceItem.id && coordinator.isPinned, "hover cannot replace editing session")
        let countBeforeCopy = try await store.fetchRecentItemsAsync().count
        coordinator.copyAll()
        try await waitUntil { writer.text != nil }
        try require(writer.text == textView.string, "copy takes current native buffer")
        let beforeCopyCount = try await store.fetchRecentItemsAsync().count
        try require(beforeCopyCount == countBeforeCopy, "copy does not create history")
        // Render owned document content, not the user's desktop.
        if let view = nativeWindow.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("document-preview.png"))
        }
        coordinator.historyCleared()
        try await waitUntil { host.frame == nil }

        // A deliberately delayed save exposes edit-versus-ack races in the real session.
        let delayed = DelayedSaveRepository(base: repository)
        nativeWindow.orderOut(nil)
        let raceHost = DocumentWindowHost(workspace: workspace)
        let race = DocumentPreviewCoordinator(repository: delayed, writer: writer, host: raceHost)
        let (raceWindow, _) = await makeSurface(store: store, repository: repository, coordinator: race, workspace: workspace, writer: writer)
        race.preview(sourceItem, anchor: anchor)
        try await waitUntil { race.source != nil && !raceHost.isTransitioning && findTextView(previewWindow(raceHost)?.contentView) != nil }
        race.beginEditing()
        guard let raceEditor = findTextView(previewWindow(raceHost)?.contentView) else { throw Failure("race editor missing") }
        raceEditor.setSelectedRange(NSRange(location: raceEditor.string.utf16.count, length: 0))
        raceEditor.insertText("第一版", replacementRange: raceEditor.selectedRange())
        race.save()
        try await waitUntil { delayed.saveStarted }
        raceEditor.insertText("继续输入", replacementRange: raceEditor.selectedRange())
        let newestBuffer = raceEditor.string
        let newestGeneration = race.generation
        delayed.release()
        try await waitUntil { race.savedGeneration > 0 }
        try require(race.generation == newestGeneration && race.savedGeneration < newestGeneration && raceEditor.string == newestBuffer && race.isDirty, "late save acknowledgement preserves newer edit")
        race.historyCleared()
        try await waitUntil { !raceHost.isTransitioning && race.source == nil }
        try require(raceWindow.isVisible, "closing preview retains original history window")
        raceWindow.orderOut(nil)
        nativeWindow.orderFrontRegardless()

        // Real store measurements compare old full-payload and new summary APIs on one DB.
        // Debug measurements are diagnostic, not Release acceptance or end-to-end key latency.
        let baselineCountBeforeFixtures = try await store.fetchRecentItemsAsync().count
        for index in 0..<40 {
            _ = try await store.performStoreOperation {
                store.insertItem(.init(type: .text, textContent: original + String(index), appName: "Verification", appPath: nil))
            }
        }
        var fullTimes: [Double] = [], summaryTimes: [Double] = []
        for _ in 0..<12 {
            var start = Date()
            let full = try await store.performStoreOperation { store.fetchRecentItems(limit: 200) }
            fullTimes.append(Date().timeIntervalSince(start) * 1000)
            try require(full.count == baselineCountBeforeFixtures + 40, "baseline rows present")
            start = Date()
            let lightweight = try await store.fetchRecentItemsAsync()
            summaryTimes.append(Date().timeIntervalSince(start) * 1000)
            try require(lightweight.count == full.count, "summary rows match baseline")
        }
        let million = String(repeating: "长文压力：保留 emoji 👩🏽‍💻 和换行。\n", count: 50000)
        await model.loadItems()
        nativeWindow.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        try await verifyHistoryWheel(nativeWindow)
        _ = try await store.performStoreOperation { store.insertItem(.init(type: .text, textContent: million, appName: "Stress", appPath: nil)) }
        let stressSummary = try await store.fetchRecentItemsAsync().first { $0.appName == "Stress" }
        guard let stressSummary else { throw Failure("stress summary missing") }
        await model.loadItems()
        let stressStart = Date()
        coordinator.preview(stressSummary, anchor: anchor)
        try await waitUntil { coordinator.source != nil }
        coordinator.pin()
        let stressTime = Date().timeIntervalSince(stressStart) * 1000
        try require(coordinator.source?.text == million, "million-character document not truncated")
        coordinator.historyCleared()
        try await waitUntil { host.frame == nil }
        let metrics: [String: Any] = [
            "configuration": "Debug", "iterations": 12,
            "fullPayloadFetchMilliseconds": fullTimes,
            "summaryFetchMilliseconds": summaryTimes,
            "sourceUTF16Length": original.utf16.count,
            "stressUTF16Length": million.utf16.count,
            "stressExplicitOpenMilliseconds": stressTime,
            "limits": "Warm same-process store comparison. Explicit open polling interval 20ms. Not mouse/key/Release p95 acceptance."
        ]
        try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("metrics.json"))

        let picture = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 800, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        picture?.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        picture?.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        guard let cgPicture = picture?.makeImage(),
              let png = NSBitmapImageRep(cgImage: cgPicture).representation(using: .png, properties: [:]) else { throw Failure("image fixture creation") }
        _ = try await store.performStoreOperation { store.insertItem(.init(type: .image, imageData: png, appName: "Image", appPath: nil)) }
        guard let imageSummary = try await store.fetchRecentItemsAsync().first(where: { $0.type == .image }) else { throw Failure("image summary missing") }
        await model.loadItems()
        coordinator.pointerEntered(imageSummary, anchor: anchor)
        let beforeDragImageWriter = writer.text
        let dragImage = try await model.actions.makeDragPasteboardItem(imageSummary)
        try require(dragImage.data(forType: .png) == png && writer.text == beforeDragImageWriter, "image drag carries source pixels without changing the clipboard writer")
        try await Task.sleep(nanoseconds: 1_200_000_000)
        try require(coordinator.source == nil && !coordinator.isLoading && host.frame == nil, "sustained image hover never loads or opens preview")
        let imageIntent = coordinator.beginPointerPreviewIntent()
        coordinator.togglePointerPreview(imageSummary, anchor: anchor, expectedRequest: imageIntent)
        try await waitUntil { coordinator.imagePreview != nil && !host.isTransitioning }
        try require(coordinator.imagePreview?.width == 200 && coordinator.imagePreview?.height == 100, "image right-click opens preview with source aspect ratio")
        try require(!nativeWindow.styleMask.contains(.titled) && !nativeWindow.isOpaque && coordinator.previewWindowNumber == previewWindow(host)?.windowNumber && nativeWindow.frame == baseFrame, "image floating preview leaves borderless history geometry unchanged")
        coordinator.beginEditing()
        try require(!coordinator.isEditing, "image preview cannot enter text editing")
        let imageClosed = await coordinator.prepareToClose()
        try require(imageClosed, "image closes without text draft dialog")

        try await waitUntil { host.frame == nil }
        _ = try await store.performStoreOperation { store.insertItem(.init(type: .text, textContent: "短文本。\n第二行。", appName: "Short", appPath: nil)) }
        await model.loadItems()
        guard let short = try await store.fetchRecentItemsAsync().first(where: { $0.appName == "Short" }) else { throw Failure("short summary missing") }
        coordinator.preview(short, anchor: anchor)
        try await waitUntil { coordinator.source?.itemID == short.id && !host.isTransitioning }
        try require(coordinator.previewSize.height < longHeight && nativeWindow.frame.minY == baseFrame.minY, "short text uses less height while preserving bottom edge")
        let switchingWindow = coordinator.previewWindowNumber
        guard let otherCard = cardTrackingViews(nativeWindow.contentView)
            .compactMap({ $0 as? CardPointerRegion.PointerView }).first(where: { !$0.isPreviewSource && !$0.visibleRect.isEmpty }),
              let otherPress = NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: otherCard.convert(NSPoint(x: otherCard.visibleRect.midX, y: otherCard.visibleRect.midY), to: nil),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: nativeWindow.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 1
              ) else { throw Failure("other-card right press setup missing") }
        try require(workspace.containsCard(in: nativeWindow, at: otherPress.locationInWindow),
            "visible card is recognized independently of preview window monitor order")
        NSApp.sendEvent(otherPress)
        try require(coordinator.source?.itemID == short.id && !host.isTransitioning,
            "right press on another card does not prematurely dismiss the existing preview")
        let switchIntent = coordinator.beginPointerPreviewIntent()
        coordinator.togglePointerPreview(imageSummary, anchor: anchor, expectedRequest: switchIntent)
        try await waitUntil { coordinator.source?.itemID == imageSummary.id && !host.isTransitioning }
        try require(coordinator.previewWindowNumber == switchingWindow && !coordinator.isPinned, "right-click replaces pinned reading preview in the same window")
        coordinator.preview(short, anchor: anchor)
        try await waitUntil { coordinator.source?.itemID == short.id && !host.isTransitioning }
        coordinator.beginEditing()
        guard let switchingEditor = findTextView(previewWindow(host)?.contentView) else { throw Failure("switching editor missing") }
        switchingEditor.setSelectedRange(NSRange(location: switchingEditor.string.utf16.count, length: 0))
        switchingEditor.insertText("切换前修改", replacementRange: switchingEditor.selectedRange())
        coordinator.preview(sourceItem, anchor: anchor, pinOnOpen: false)
        coordinator.preview(imageSummary, anchor: anchor, pinOnOpen: false)
        try await waitUntil { coordinator.source?.itemID == imageSummary.id && !host.isTransitioning }
        let switchingDraft = try await repository.recover(sourceID: short.id)
        try require(switchingDraft?.text.hasSuffix("切换前修改") == true && coordinator.previewWindowNumber == switchingWindow, "rapid preview replacement keeps dirty draft and latest target without closing window")
        let scrollingPreviewFrame = host.frame
        for _ in 0..<10 {
            coordinator.historyScrolled()
            try await Task.sleep(nanoseconds: 70_000_000)
            if let remainingFrame = host.frame {
                try require(remainingFrame == scrollingPreviewFrame, "scroll dismissal fades in place without returning to stale card coordinates")
            }
        }
        try require(host.frame == nil && coordinator.source == nil, "continuous scrolling completes dismissal without restarting close animation")
        coordinator.preview(short, anchor: anchor)
        try await waitUntil { coordinator.source?.itemID == short.id && !host.isTransitioning }
        coordinator.beginEditing()
        guard let toggleEditor = findTextView(previewWindow(host)?.contentView) else { throw Failure("toggle editor missing") }
        coordinator.continueDraft()
        try require(coordinator.isEditing && toggleEditor.isEditable, "toggle regression resumes the existing draft before editing")
        toggleEditor.setSelectedRange(NSRange(location: toggleEditor.string.utf16.count, length: 0))
        toggleEditor.insertText("收回前修改", replacementRange: toggleEditor.selectedRange())
        let dirtyCloseIntent = coordinator.beginPointerPreviewIntent()
        coordinator.togglePointerPreview(short, anchor: anchor, expectedRequest: dirtyCloseIntent)
        try await waitUntil { coordinator.source == nil && !host.isTransitioning }
        let toggleDraft = try await repository.recover(sourceID: short.id)
        try require(toggleDraft?.text.hasSuffix("收回前修改") == true, "right-click dismissal preserves dirty editor draft without a close dialog")
        nativeWindow.orderOut(nil)

        // OCR regression uses the actual Vision service on a blank image and invalid data.
        let blank = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let image = blank?.makeImage(),
              let imageData = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw Failure("blank image creation")
        }
        for _ in 0..<4 {
            let result = await OCRService.shared.recognizeText(from: imageData)
            try require(result == nil, "OCR empty result returns without continuation crash")
        }
        let invalidOCR = await OCRService.shared.recognizeText(from: Data([0, 1, 2]))
        try require(invalidOCR == nil, "invalid image failure remains recoverable")
        print("PASS document workflow verification completed; no user history modified")
    }
    @MainActor private static func verifyHistoryWheel(_ nativeWindow: KeyboardAcceptingPanel) async throws {
        let cpuStart = clock()
        let wallStart = ProcessInfo.processInfo.systemUptime
        func historyWheelRegion(_ view: NSView?) -> HorizontalWheelRegion.WheelView? {
            guard let view else { return nil }
            if let region = view as? HorizontalWheelRegion.WheelView { return region }
            return view.subviews.lazy.compactMap { historyWheelRegion($0) }.first
        }
        guard let wheelScroll = cardTrackingViews(nativeWindow.contentView).first?.enclosingScrollView,
              let wheelRegion = historyWheelRegion(nativeWindow.contentView),
              let wheelCG = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -3, wheel2: 0, wheel3: 0),
              nativeWindow.historyWheelRouter === wheelRegion else {
            throw Failure("native wheel verification setup missing")
        }
        let wheelPoint = wheelRegion.convert(NSPoint(x: wheelRegion.bounds.midX, y: wheelRegion.bounds.midY), to: nil)
        let wheelScreenPoint = nativeWindow.convertPoint(toScreen: wheelPoint)
        wheelCG.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(nativeWindow.windowNumber))
        wheelCG.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(nativeWindow.windowNumber))
        wheelCG.location = CGPoint(x: wheelScreenPoint.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - wheelScreenPoint.y)
        guard let wheelEvent = NSEvent(cgEvent: wheelCG) else { throw Failure("history wheel event missing") }
        print("MEASURE window wheel coordinates: \(wheelEvent.locationInWindow), expected: \(wheelPoint), event window: \(wheelEvent.windowNumber)")
        let routedPoint = wheelEvent.window === nativeWindow ? wheelEvent.locationInWindow : nativeWindow.convertPoint(fromScreen: wheelEvent.locationInWindow)
        try require(abs(routedPoint.x - wheelPoint.x) < 1 && abs(routedPoint.y - wheelPoint.y) < 1,
            "unassociated wheel screen coordinates resolve inside the history viewport")
        let wheelBefore = wheelScroll.contentView.bounds.origin.x
        nativeWindow.sendEvent(wheelEvent)
        try await Task.sleep(nanoseconds: 100_000_000)
        let wheelDistance = wheelScroll.contentView.bounds.origin.x - wheelBefore
        print("MEASURE native ordinary wheel movement: \(wheelDistance)pt")
        try require(wheelDistance > 20, "history panel event dispatch converts vertical wheel input into useful horizontal displacement")
        guard let preciseCG = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: -17, wheel3: 0) else {
            throw Failure("precise history wheel setup missing")
        }
        preciseCG.location = wheelCG.location
        guard let preciseEvent = NSEvent(cgEvent: preciseCG) else { throw Failure("precise history wheel event missing") }
        let preciseBefore = wheelScroll.contentView.bounds.origin.x
        nativeWindow.sendEvent(preciseEvent)
        try await Task.sleep(nanoseconds: 150_000_000)
        let preciseDistance = wheelScroll.contentView.bounds.origin.x - preciseBefore
        print("MEASURE precise native wheel movement: \(preciseDistance)pt")
        try require(abs(preciseDistance - 17) < 1, "precise horizontal wheel moves history by pixel distance without line multiplication")
        guard let pixelWheel = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                      wheel1: -48, wheel2: 0, wheel3: 0) else { throw Failure("pixel vertical wheel setup missing") }
        pixelWheel.location = wheelCG.location
        guard let pixelEvent = NSEvent(cgEvent: pixelWheel) else { throw Failure("pixel wheel event missing") }
        try require(pixelEvent.hasPreciseScrollingDeltas && pixelEvent.phase.isEmpty,
                    "high-resolution wheel delivers precise deltas without a gesture phase")
        let pixelBefore = wheelScroll.contentView.bounds.origin.x
        nativeWindow.sendEvent(pixelEvent)
        try await Task.sleep(nanoseconds: 80_000_000)
        try require(abs(wheelScroll.contentView.bounds.origin.x - pixelBefore - 48) < 1,
                    "unphased precise vertical wheel scrolls history horizontally by pixel distance")
        pixelWheel.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.began.rawValue))
        guard let gestureEvent = NSEvent(cgEvent: pixelWheel) else { throw Failure("vertical gesture event missing") }
        wheelRegion.trackpadContactsPresent = { false }
        let smoothMouseBefore = wheelScroll.contentView.bounds.origin.x
        nativeWindow.sendEvent(gestureEvent)
        try await Task.sleep(nanoseconds: 80_000_000)
        try require(abs(wheelScroll.contentView.bounds.origin.x - smoothMouseBefore - 48) < 1,
                    "phased precise mouse wheel still scrolls without physical trackpad contacts")
        let releasePosition = wheelScroll.contentView.bounds.origin.x
        try await Task.sleep(nanoseconds: 250_000_000)
        let momentumPosition = wheelScroll.contentView.bounds.origin.x
        print("MEASURE release momentum distance: \(momentumPosition - releasePosition)pt")
        print("MEASURE release scenario: processCPU=\(Double(clock() - cpuStart) / Double(CLOCKS_PER_SEC))s wall=\(ProcessInfo.processInfo.systemUptime - wallStart)s")
        try require(momentumPosition > releasePosition + 2, "ordinary mouse release continues moving with the platform spring")
        guard let reverseCG = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                      wheel1: 48, wheel2: 0, wheel3: 0) else { throw Failure("reverse wheel missing") }
        reverseCG.location = wheelCG.location
        guard let reverseEvent = NSEvent(cgEvent: reverseCG) else { throw Failure("reverse event missing") }
        nativeWindow.sendEvent(reverseEvent)
        try await Task.sleep(nanoseconds: 25_000_000)
        print("MEASURE reverse wheel displacement after 25ms: \(wheelScroll.contentView.bounds.origin.x - momentumPosition)pt")
        try require(wheelScroll.contentView.bounds.origin.x < momentumPosition - 20,
                    "reverse wheel input interrupts ongoing momentum on the next rendered frame")
        wheelRegion.trackpadContactsPresent = { true }
        let gestureBefore = wheelScroll.contentView.bounds.origin.x
        nativeWindow.sendEvent(gestureEvent)
        try await Task.sleep(nanoseconds: 180_000_000)
        try require(abs(wheelScroll.contentView.bounds.origin.x - gestureBefore) < 1,
                    "physical two-finger vertical gesture cannot navigate history horizontally")
        wheelRegion.trackpadContactsPresent = { false }
        pixelWheel.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
        pixelWheel.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
        guard let touchMomentum = NSEvent(cgEvent: pixelWheel) else { throw Failure("touch momentum event missing") }
        nativeWindow.sendEvent(touchMomentum)
        try await Task.sleep(nanoseconds: 180_000_000)
        try require(abs(wheelScroll.contentView.bounds.origin.x - gestureBefore) < 1,
                    "trackpad vertical momentum remains excluded after fingers lift")
        pixelWheel.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 3)
        if let endMomentum = NSEvent(cgEvent: pixelWheel) { nativeWindow.sendEvent(endMomentum) }
        // Exercise the same window route through the actual trailing boundary, including release.
        var greatestStretch: CGFloat = 0
        for _ in 0..<80 {
            guard let endCG = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                                      wheel1: -1600, wheel2: 0, wheel3: 0) else { throw Failure("edge wheel missing") }
            endCG.location = wheelCG.location
            guard let endEvent = NSEvent(cgEvent: endCG) else { throw Failure("edge event missing") }
            nativeWindow.sendEvent(endEvent)
            let current = wheelScroll.contentView.bounds
            greatestStretch = max(greatestStretch, abs(current.minX - wheelScroll.contentView.constrainBoundsRect(current).minX))
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
        nativeWindow.contentView?.layoutSubtreeIfNeeded()
        let clip = wheelScroll.contentView
        let constrained = clip.constrainBoundsRect(clip.bounds)
        let cardsAtEnd = cardTrackingViews(nativeWindow.contentView)
        let lastCardRight = cardsAtEnd.map { $0.convert($0.bounds, to: clip).maxX }.max() ?? .infinity
        print("MEASURE trailing edge: offset=\(clip.bounds.minX), constrained=\(constrained.minX), lastCard=\(lastCardRight), viewport=\(clip.bounds.maxX), peak elastic stretch=\(greatestStretch)")
        try require(greatestStretch > 2, "native wheel gesture stretches beyond the trailing edge before release")
        try require(abs(clip.bounds.minX - constrained.minX) <= 1.1,
                    "native elasticity settles inside the scroll boundary after wheel release")
        try require(lastCardRight <= clip.bounds.maxX - 27 && lastCardRight >= clip.bounds.maxX - 29,
                    "last history card is fully reachable with the same trailing content margin")
        let cpuSeconds = Double(clock() - cpuStart) / Double(CLOCKS_PER_SEC)
        print("MEASURE native scroll scenario: processCPU=\(cpuSeconds)s wall=\(ProcessInfo.processInfo.systemUptime - wallStart)s; includes native rendering, not frame latency")
    }
    @MainActor private static func makeSurface(store: DatabaseManager, repository: DocumentRepository, coordinator: DocumentPreviewCoordinator, workspace: WorkspaceWindowCoordinator, writer: RecordingWriter) async -> (KeyboardAcceptingPanel, ClipboardListViewModel) {
        let actions = HistoryActionCoordinator(documents: coordinator, repository: repository, writer: writer, onPaste: {})
        let model = ClipboardListViewModel(repository: DatabaseClipboardRepository(databaseManager: store), actions: actions, thumbnails: ClipboardThumbnailLoader(repository: repository))
        await model.loadItems()
        let window = KeyboardAcceptingPanel(contentRect: CGRect(x: 120, y: 80, width: 800, height: WindowLayoutConfig.default.unifiedWindowHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: UnifiedPanelView(viewModel: model, mainContainerConfig: .default, cardConfig: .default, topConfig: .default))
        workspace.register(window)
        window.orderFrontRegardless()
        return (window, model)
    }
    struct Failure: Error { let reason: String; init(_ reason: String) { self.reason = reason } }
    static func require(_ value: @autoclosure () -> Bool, _ name: String) throws {
        guard value() else { throw Failure(name) }
        print("PASS \(name)")
    }
    @MainActor static func waitUntil(file: StaticString = #fileID, line: UInt = #line, _ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw Failure("condition timed out at \(file):\(line)")
    }
    @MainActor static func previewWindow(_ host: DocumentWindowHost) -> NSWindow? {
        guard let frame = host.frame else { return nil }
        return NSApp.windows.first { $0.isVisible && $0.frame == frame }
    }
    @MainActor static func screenBounds(_ view: NSView?) -> CGRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
    @MainActor static func findTextField(_ view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField { return field }
        for child in view.subviews { if let field = findTextField(child) { return field } }
        return nil
    }
    @MainActor static func cardTrackingViews(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        // Measure actual native tracking surfaces in the production SwiftUI hierarchy.
        if String(describing: type(of: view)).contains("PointerView") { return [view] }
        return view.subviews.flatMap { cardTrackingViews($0) }
    }
    @MainActor static func findTextView(_ view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let text = view as? NSTextView { return text }
        for child in view.subviews { if let text = findTextView(child) { return text } }
        return nil
    }
}

private final class RecordingWriter: ClipboardWriter, @unchecked Sendable {
    @MainActor var text: String?
    func write(_ value: String) async { await MainActor.run { text = value } }
    func write(_ content: ClipboardContent) async {
        if case .text(let value) = content { await write(value) }
    }
}

/// Holds only a save acknowledgement, while actual writes still use the production store.
@MainActor private final class DelayedSaveRepository: HistoryContentRepository {
    private let base: HistoryContentRepository
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var saveStarted = false
    init(base: HistoryContentRepository) { self.base = base }
    func loadDetail(itemID: Int64, revision: String) async throws -> ClipboardItem { try await base.loadDetail(itemID: itemID, revision: revision) }
    func saveDerived(text: String, source: DocumentSnapshot, requestID: UUID) async throws -> Int64 {
        saveStarted = true
        await withCheckedContinuation { continuation = $0 }
        return try await base.saveDerived(text: text, source: source, requestID: requestID)
    }
    func release() { let pending = continuation; continuation = nil; pending?.resume() }
    func recover(sourceID: Int64) async throws -> DocumentDraft? { try await base.recover(sourceID: sourceID) }
    func checkpoint(_ draft: DocumentDraft) async throws { try await base.checkpoint(draft) }
    func discard(sessionID: UUID, generation: Int) async throws { try await base.discard(sessionID: sessionID, generation: generation) }
}
