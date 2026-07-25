import Foundation
import IOKit.hid

setbuf(stdout, nil)

final class Counter {
    var n = 0
}

let counter = Counter()
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatchingMultiple(manager, [
    [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse],
    [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Pointer],
] as CFArray)

let refcon = Unmanaged.passUnretained(counter).toOpaque()
IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, _ in
    guard let context else { return }
    Unmanaged<Counter>.fromOpaque(context).takeUnretainedValue().n += 1
}, refcon)

IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("open: \(openResult == kIOReturnSuccess ? "OK" : "FAIL \(openResult)")")

Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    print("HID 报告率: \(counter.n) /s")
    counter.n = 0
}
RunLoop.main.run()
