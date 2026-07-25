import Cocoa

setbuf(stdout, nil)
let seconds: Double = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 2 : 2

final class Summer {
    var sumX: Int64 = 0
    var sumY: Int64 = 0
    var count = 0
}

let summer = Summer()
let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
let refcon = Unmanaged.passUnretained(summer).toOpaque()

guard let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .tailAppendEventTap,
    options: .listenOnly,
    eventsOfInterest: mask,
    callback: { _, _, event, refcon in
        let s = Unmanaged<Summer>.fromOpaque(refcon!).takeUnretainedValue()
        s.sumX += event.getIntegerValueField(.mouseEventDeltaX)
        s.sumY += event.getIntegerValueField(.mouseEventDeltaY)
        s.count += 1
        return Unmanaged.passUnretained(event)
    },
    userInfo: refcon
) else {
    print("FAILED: measure tap")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
    print("sumX=\(summer.sumX) sumY=\(summer.sumY) events=\(summer.count)")
    exit(0)
}
CFRunLoopRun()
