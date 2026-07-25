import Foundation
import IOKit.hid

setbuf(stdout, nil)

final class DeviceCounter {
    var name = ""
    var count = 0
}

var counters: [ObjectIdentifier: DeviceCounter] = [:]
let lock = NSLock()

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatchingMultiple(manager, [
    [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse],
    [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Pointer],
] as CFArray)

let callback: IOHIDReportCallback = { _, _, sender, _, _, _, _ in
    guard let sender else { return }
    let device = unsafeBitCast(sender, to: IOHIDDevice.self)
    let id = ObjectIdentifier(device)
    lock.lock()
    let counter = counters[id] ?? DeviceCounter()
    if counter.name.isEmpty {
        counter.name = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? "unknown"
    }
    counter.count += 1
    counters[id] = counter
    lock.unlock()
}

IOHIDManagerRegisterInputReportCallback(manager, callback, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("listening...")

Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
    lock.lock()
    let snapshot = counters
    for key in snapshot.keys { counters[key]?.count = 0 }
    lock.unlock()
    for (_, counter) in snapshot {
        print("  [\(counter.name)] \(counter.count / 2) reports/s")
    }
    print("---")
}
RunLoop.main.run()
