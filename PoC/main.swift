import Cocoa

setbuf(stdout, nil)
let targetHz: Double = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 250 : 250

final class Throttler {
    static let magic: Int64 = 0x4D464C4F57
    let interval: CFTimeInterval
    let queue = DispatchQueue(label: "pacemouse.throttle", qos: .userInteractive)
    let lock = NSLock()
    var pending: CGEvent?
    var dirty = false
    var timer: DispatchSourceTimer?
    var inCount = 0
    var outCount = 0
    var syntheticSeen = 0
    var statsTimer: DispatchSourceTimer?
    var tap: CFMachPort?

    init(hz: Double) {
        interval = 1.0 / hz
    }

    func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Throttler.magic {
            syntheticSeen += 1
            return Unmanaged.passUnretained(event)
        }
        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            lock.lock()
            pending = event
            dirty = true
            inCount += 1
            lock.unlock()
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            guard self.dirty, let ev = self.pending else { self.lock.unlock(); return }
            self.dirty = false
            self.pending = nil
            self.outCount += 1
            self.lock.unlock()
            if let copy = ev.copy() {
                copy.setIntegerValueField(.eventSourceUserData, value: Throttler.magic)
                copy.post(tap: .cghidEventTap)
            }
        }
        t.resume()
        timer = t
    }

    func startStats() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let i = self.inCount, o = self.outCount, s = self.syntheticSeen
            self.inCount = 0; self.outCount = 0; self.syntheticSeen = 0
            self.lock.unlock()
            FileHandle.standardOutput.write("in=\(i)/s out=\(o)/s synthetic=\(s)/s\n".data(using: .utf8)!)
        }
        t.resume()
        statsTimer = t
    }
}

let throttler = Throttler(hz: targetHz)

print("AXIsProcessTrusted: \(AXIsProcessTrusted())")
print("ListenEventAccess preflight: \(CGPreflightListenEventAccess())")

let mask: CGEventMask =
    (1 << CGEventType.mouseMoved.rawValue) |
    (1 << CGEventType.leftMouseDragged.rawValue) |
    (1 << CGEventType.rightMouseDragged.rawValue) |
    (1 << CGEventType.otherMouseDragged.rawValue)

let refcon = Unmanaged.passUnretained(throttler).toOpaque()
guard let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: { proxy, type, event, refcon in
        let t = Unmanaged<Throttler>.fromOpaque(refcon!).takeUnretainedValue()
        return t.handle(proxy, type, event)
    },
    userInfo: refcon
) else {
    print("FAILED: tapCreate returned nil (permission missing)")
    AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
    exit(1)
}

throttler.tap = tap
let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
throttler.startTimer()
throttler.startStats()
print("tap created OK, throttling to \(targetHz) Hz")
CFRunLoopRun()
