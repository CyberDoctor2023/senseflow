import AppKit

/// Attributes an automatic paste to a known input method and the clipboard version it used.
/// All state and pasteboard access belong to the main run loop.
final class VoiceInputSourceObserver {
    static let shared = VoiceInputSourceObserver()
    static let supportedBundleIDs: Set<String> = ["com.tencent.inputmethod.wetype"]

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var versions: [Int] = []
    var isObserving: Bool { tap.map(CGEvent.tapIsEnabled(tap:)) ?? false }

    /// Starts a passive event observer only while the preference is enabled.
    func setEnabled(_ enabled: Bool) {
        if !enabled {
            if let tap { CFMachPortInvalidate(tap) }
            if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
            tap = nil
            runLoopSource = nil
            versions.removeAll()
            return
        }
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let observer = Unmanaged<VoiceInputSourceObserver>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = observer.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                } else if type == .keyDown {
                    observer.observePaste(event)
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        tap = created
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
    }

    /// Explicit source markers and attributed automatic pastes are independent evidence paths.
    func shouldFilter(changeCount: Int, sourceBundleID: String?) -> Bool {
        if let sourceBundleID, Self.supportedBundleIDs.contains(sourceBundleID) { return true }
        return versions.contains(changeCount)
    }

    private func observePaste(_ event: CGEvent) {
        guard event.getIntegerValueField(.keyboardEventKeycode) == 9,
              event.flags.contains(.maskCommand) else { return }
        let pid = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
        guard let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
              Self.supportedBundleIDs.contains(bundleID) else { return }
        versions.append(NSPasteboard.general.changeCount)
        if versions.count > 64 { versions.removeFirst(versions.count - 64) }
    }
}
