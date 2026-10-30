import AppKit
import Darwin
import os
import Observation

/// A copied, normalized trackpad contact; raw hardware buffers never leave their callback.
struct RevealContact: Sendable {
    let id: Int32
    let x: Double
    let y: Double
}

enum TrackpadEdgeAction: String, Sendable { case reveal, dismiss }

/// Recognizes a reveal and its reverse, including reversal before fingers lift.
struct TrackpadRevealRecognizer {
    private var origin: [RevealContact] = []
    private var startedAt = 0.0
    private var consumed = false
    private var direction: TrackpadEdgeAction = .reveal
    private var followsReveal = false

    mutating func reset() { origin = []; consumed = false; followsReveal = false }
    mutating func consume(_ contacts: [RevealContact], time: Double) -> TrackpadEdgeAction? {
        if contacts.isEmpty { reset(); return nil }
        if contacts.count == 1 && origin.isEmpty && !consumed { return nil }
        guard !consumed, contacts.count == 2, time.isFinite,
              contacts.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
            consumed = true
            return nil
        }
        let sorted = contacts.sorted { $0.id < $1.id }
        if origin.isEmpty {
            if sorted.allSatisfy({ $0.y >= 0.86 }) { direction = .dismiss }
            else if sorted.allSatisfy({ (0.50...0.86).contains($0.y) }) { direction = .reveal }
            else { consumed = true; return nil }
            origin = sorted
            startedAt = time
            return nil
        }
        guard zip(origin, sorted).allSatisfy({ $0.id == $1.id && abs($0.x - $1.x) <= 0.15 }), time >= startedAt else {
            consumed = true
            return nil
        }
        // Follow the final upward travel after revealing, so reverse starts at the real peak.
        if followsReveal && zip(origin, sorted).contains(where: { $1.y > $0.y }) {
            origin = zip(origin, sorted).map { previous, current in
                RevealContact(id: previous.id, x: previous.x, y: max(previous.y, current.y))
            }
            startedAt = time
            return nil
        }
        if followsReveal && zip(origin, sorted).allSatisfy({ $1.y == $0.y }) {
            startedAt = time
            return nil
        }
        guard time - startedAt <= 1.2,
              zip(origin, sorted).allSatisfy({ direction == .reveal ? $1.y >= $0.y - 0.035 : $1.y <= $0.y + 0.035 }) else {
            consumed = true
            return nil
        }
        guard time - startedAt >= 0.12 else { return nil }
        if direction == .reveal {
            guard zip(origin, sorted).allSatisfy({ $1.y >= 0.94 && $1.y - $0.y >= 0.12 }) else { return nil }
            origin = sorted
            startedAt = time
            direction = .dismiss
            followsReveal = true
            return .reveal
        }
        guard zip(origin, sorted).allSatisfy({ $0.y - $1.y >= 0.16 }) else { return nil }
        consumed = true
        return .dismiss
    }
}

/// Serializes callback state without creating a task for every hardware frame.
private final class RevealContactReceiver: @unchecked Sendable {
    static let shared = RevealContactReceiver()
    private let lock = NSLock()
    private var recognizer = TrackpadRevealRecognizer()
    private var action: (@Sendable (TrackpadEdgeAction) -> Void)?
    private var scrollingContacts = false
    var hasScrollingContacts: Bool {
        lock.lock()
        defer { lock.unlock() }
        return scrollingContacts
    }
    func configure(action: (@Sendable (TrackpadEdgeAction) -> Void)?) {
        lock.lock()
        self.action = action
        recognizer.reset()
        scrollingContacts = false
        lock.unlock()
    }
    func receive(_ contacts: [RevealContact], time: Double) {
        lock.lock()
        scrollingContacts = action != nil && contacts.count >= 2
        let result = action != nil ? recognizer.consume(contacts, time: time) : nil
        let callback = action
        lock.unlock()
        if let result { callback?(result) }
    }
}

// ABI pinned to OpenMultitouchSupport's OpenMTInternal.h (96-byte MTTouch).
// Only states 3/4 are active contacts. The framework owns this buffer until callback return.
private let revealFrameCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Void = { _, buffer, count, time, _ in
    guard (0...16).contains(count), time.isFinite else { return }
    var contacts: [RevealContact] = []
    if count > 0 {
        guard let buffer else { return }
        for index in 0..<Int(count) {
            let touch = buffer.advanced(by: index * 96)
            let state = touch.load(fromByteOffset: 20, as: Int32.self)
            guard state == 3 || state == 4 else { continue }
            contacts.append(RevealContact(id: touch.load(fromByteOffset: 16, as: Int32.self),
                x: Double(touch.load(fromByteOffset: 32, as: Float.self)),
                y: Double(touch.load(fromByteOffset: 36, as: Float.self))))
        }
    }
    RevealContactReceiver.shared.receive(contacts, time: time)
}

/// Optional private-framework boundary. Failure disables only edge gestures, never shortcuts.
@MainActor @Observable final class TrackpadRevealMonitor {
    static let shared = TrackpadRevealMonitor()
    enum Status: String { case stopped, unavailable, noDevice, failed, listening }
    private(set) var status: Status = .stopped
    /// Reads the selected physical trackpad's current two-finger contact state.
    var hasScrollingContacts: Bool { status == .listening && RevealContactReceiver.shared.hasScrollingContacts }
    private let logger = Logger(subsystem: "com.senseflow.SenseFlow", category: "TrackpadReveal")
    private typealias Device = UnsafeMutableRawPointer
    private typealias Callback = @convention(c) (Device?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Void
    private struct API {
        let createList: @convention(c) () -> Unmanaged<CFArray>?
        let dimensions: @convention(c) (Device, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
        let isRunning: @convention(c) (Device) -> Bool
        let start: @convention(c) (Device, Int32) -> Void
        let stop: @convention(c) (Device) -> Void
        let register: @convention(c) (Device, Callback) -> Void
        let unregister: @convention(c) (Device, Callback) -> Void
    }
    private var library: UnsafeMutableRawPointer?
    private var api: API?
    private var device: Device?
    private var deviceList: CFArray?
    private var observers: [NSObjectProtocol] = []
    private var action: (@MainActor @Sendable (TrackpadEdgeAction) -> Void)?
    private var generation = UUID()

    /// Starts one device listener and reinstalls it after sleep; no input is intercepted.
    func start(onGesture: @escaping @MainActor @Sendable (TrackpadEdgeAction) -> Void) {
        action = onGesture
        if observers.isEmpty {
            let center = NSWorkspace.shared.notificationCenter
            observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.stopDevice() }
            })
            observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.startDevice() }
            })
        }
        startDevice()
    }
    /// Removes callbacks before releasing the device, including during app termination.
    func stop() {
        stopDevice()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers = []
        action = nil
    }
    private func startDevice() {
        guard device == nil else { return }
        guard let api = api ?? loadAPI() else { setStatus(.unavailable); return }
        self.api = api
        guard let list = api.createList()?.takeRetainedValue() else { setStatus(.noDevice); return }
        var selected: Device?
        for index in 0..<CFArrayGetCount(list) {
            guard let value = CFArrayGetValueAtIndex(list, index) else { continue }
            let candidate = UnsafeMutableRawPointer(mutating: value)
            var rows: Int32 = 0
            var columns: Int32 = 0
            // Exclude auxiliary sensors (e.g. 60x2), not just devices with touch callbacks.
            if api.dimensions(candidate, &rows, &columns) == 0, rows >= 8, columns >= 8 {
                selected = candidate
                break
            }
        }
        guard let device = selected else { setStatus(.noDevice); return }
        deviceList = list
        self.device = device
        let token = generation
        RevealContactReceiver.shared.configure { [weak self] gesture in
            Task { @MainActor [weak self] in
                guard let self, self.status == .listening, self.generation == token else { return }
                self.logger.info("Physical top-edge gesture: \(gesture.rawValue, privacy: .public)")
                self.action?(gesture)
            }
        }
        api.register(device, revealFrameCallback)
        api.start(device, 0)
        guard api.isRunning(device) else {
            stopDevice()
            setStatus(.failed)
            return
        }
        setStatus(.listening)
    }
    private func stopDevice() {
        generation = UUID()
        RevealContactReceiver.shared.configure(action: nil)
        if let device, let api {
            api.unregister(device, revealFrameCallback)
            api.stop(device)
        }
        device = nil
        deviceList = nil
        setStatus(.stopped)
    }
    private func setStatus(_ status: Status) {
        self.status = status
        logger.info("Trackpad reveal: \(status.rawValue, privacy: .public)")
    }
    private func loadAPI() -> API? {
        // Keep the handle loaded for process lifetime: callbacks must never point into unloaded code.
        if library == nil { library = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW | RTLD_LOCAL) }
        guard let library,
              let create = dlsym(library, "MTDeviceCreateList"),
              let dimensions = dlsym(library, "MTDeviceGetSensorDimensions"),
              let isRunning = dlsym(library, "MTDeviceIsRunning"),
              let start = dlsym(library, "MTDeviceStart"),
              let stop = dlsym(library, "MTDeviceStop"),
              let register = dlsym(library, "MTRegisterContactFrameCallback"),
              let unregister = dlsym(library, "MTUnregisterContactFrameCallback") else { return nil }
        // Dynamic C entry points require typed function-pointer casts at this single ABI boundary.
        return API(createList: unsafeBitCast(create, to: (@convention(c) () -> Unmanaged<CFArray>?).self),
            dimensions: unsafeBitCast(dimensions, to: (@convention(c) (Device, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32).self),
            isRunning: unsafeBitCast(isRunning, to: (@convention(c) (Device) -> Bool).self),
            start: unsafeBitCast(start, to: (@convention(c) (Device, Int32) -> Void).self),
            stop: unsafeBitCast(stop, to: (@convention(c) (Device) -> Void).self),
            register: unsafeBitCast(register, to: (@convention(c) (Device, Callback) -> Void).self),
            unregister: unsafeBitCast(unregister, to: (@convention(c) (Device, Callback) -> Void).self))
    }
}
