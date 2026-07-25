import CoreGraphics
import Foundation

public struct TapStats: Sendable {
    public var ingest: Int
    public var emit: Int
    public var peakHz: Int
}

public enum TapState: Sendable, Equatable {
    case running
    case stopped
    case permissionMissing
}

final class EventThread: Thread {
    private let ready = DispatchSemaphore(value: 0)
    private(set) var runLoop: CFRunLoop?

    override func main() {
        runLoop = CFRunLoopGetCurrent()
        RunLoop.current.add(NSMachPort(), forMode: .default)
        ready.signal()
        CFRunLoopRun()
    }

    func waitUntilReady() {
        ready.wait()
    }

    func perform(_ block: @escaping () -> Void) {
        guard let runLoop else { return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }
}

public final class TapBridge: @unchecked Sendable {
    private static let motionMask: CGEventMask = [
        CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
    ].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

    private let core = ThrottleCore()
    private let thread = EventThread()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var statsTimer: Timer?
    private var tokens = 4.0
    private var lastRefill = CFAbsoluteTime(0)
    private let bucketCapacity = 4.0
    private var peakBuckets = [(slot: Int, count: Int)](repeating: (slot: -1, count: 0), count: 10)
    private var bypassValue = false
    private let bypassLock = NSLock()

    public private(set) var targetHz: Double = 250
    public var onStats: ((TapStats) -> Void)?

    public init() {
        thread.start()
        thread.waitUntilReady()
    }

    deinit {
        stop()
    }

    public var isRunning: Bool { tap != nil }

    public var bypass: Bool {
        get {
            bypassLock.lock()
            defer { bypassLock.unlock() }
            return bypassValue
        }
        set {
            thread.perform { [weak self] in
                guard let self else { return }
                self.bypassLock.lock()
                self.bypassValue = newValue
                self.bypassLock.unlock()
                self.core.reset()
            }
        }
    }

    @discardableResult
    public func start(hz: Double) -> TapState {
        stop()
        targetHz = hz
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: TapBridge.motionMask,
            callback: paceMouseTapCallback,
            userInfo: refcon
        ) else {
            return .permissionMissing
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        thread.perform { [weak self] in
            guard let self, let runLoop = self.thread.runLoop else { return }
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.resetThrottleState()
            self.startStatsTimer()
        }
        return .running
    }

    public func stop() {
        guard let oldTap = tap else { return }
        let oldSource = runLoopSource
        tap = nil
        runLoopSource = nil
        thread.perform { [weak self] in
            guard let self else { return }
            self.statsTimer?.invalidate()
            self.statsTimer = nil
            if let oldSource, let runLoop = self.thread.runLoop {
                CFRunLoopRemoveSource(runLoop, oldSource, .commonModes)
            }
            CGEvent.tapEnable(tap: oldTap, enable: false)
            self.core.reset()
        }
    }

    public func setTargetHz(_ hz: Double) {
        thread.perform { [weak self] in
            self?.targetHz = hz
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let now = CFAbsoluteTimeGetCurrent()
        trackPeak(now)
        if bypass {
            core.noteIngest()
            return Unmanaged.passUnretained(event)
        }
        core.store(MouseDelta(
            dx: event.getIntegerValueField(.mouseEventDeltaX),
            dy: event.getIntegerValueField(.mouseEventDeltaY)))
        tokens = min(bucketCapacity, tokens + (now - lastRefill) * targetHz)
        lastRefill = now
        guard tokens >= 1 else { return nil }
        tokens -= 1
        if let delta = core.drain() {
            event.setIntegerValueField(.mouseEventDeltaX, value: delta.dx)
            event.setIntegerValueField(.mouseEventDeltaY, value: delta.dy)
        }
        return Unmanaged.passUnretained(event)
    }

    private func resetThrottleState() {
        tokens = bucketCapacity
        lastRefill = CFAbsoluteTimeGetCurrent()
        core.reset()
    }

    private func trackPeak(_ now: CFAbsoluteTime) {
        let slot = Int(now * 10)
        let index = slot % peakBuckets.count
        if peakBuckets[index].slot != slot {
            peakBuckets[index] = (slot: slot, count: 0)
        }
        peakBuckets[index].count += 1
    }

    private func currentPeakHz(_ now: CFAbsoluteTime) -> Int {
        let nowSlot = Int(now * 10)
        return (peakBuckets.filter { nowSlot - $0.slot < 10 }.map(\.count).max() ?? 0) * 10
    }

    private func startStatsTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.healthCheck()
            let stats = self.core.resetStats()
            let peak = self.currentPeakHz(CFAbsoluteTimeGetCurrent())
            self.onStats?(TapStats(ingest: stats.ingest, emit: stats.emit, peakHz: peak))
        }
        timer.tolerance = 0.2
        RunLoop.current.add(timer, forMode: .common)
        statsTimer = timer
    }

    private func healthCheck() {
        guard let tap else { return }
        if !CFMachPortIsValid(tap) {
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            guard let newTap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: TapBridge.motionMask,
                callback: paceMouseTapCallback,
                userInfo: refcon
            ) else {
                self.tap = nil
                return
            }
            if let oldSource = runLoopSource, let runLoop = thread.runLoop {
                CFRunLoopRemoveSource(runLoop, oldSource, .commonModes)
            }
            self.tap = newTap
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
            if let runLoop = thread.runLoop {
                CFRunLoopAddSource(runLoop, source, .commonModes)
            }
            runLoopSource = source
            CGEvent.tapEnable(tap: newTap, enable: true)
        } else if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

private let paceMouseTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let bridge = Unmanaged<TapBridge>.fromOpaque(refcon).takeUnretainedValue()
    return bridge.handle(type: type, event: event)
}
