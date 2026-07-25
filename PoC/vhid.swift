import Foundation
import IOKit.hid

setbuf(stdout, nil)

let descriptor: [UInt8] = [
    0x05, 0x01, 0x09, 0x02, 0xA1, 0x01,
    0x09, 0x01, 0xA1, 0x00,
    0x05, 0x09, 0x19, 0x01, 0x29, 0x03,
    0x15, 0x00, 0x25, 0x01, 0x95, 0x03, 0x75, 0x01, 0x81, 0x02,
    0x95, 0x01, 0x75, 0x05, 0x81, 0x01,
    0x05, 0x01, 0x09, 0x30, 0x09, 0x31,
    0x15, 0x81, 0x25, 0x7F, 0x75, 0x08, 0x95, 0x02, 0x81, 0x06,
    0xC0, 0xC0,
]

let properties: [String: Any] = [
    kIOHIDReportDescriptorKey: Data(descriptor),
    kIOHIDVendorIDKey: 0x4D46,
    kIOHIDProductIDKey: 0x0001,
    kIOHIDProductKey: "PaceMouse Virtual Mouse PoC",
    kIOHIDPrimaryUsagePageKey: 0x01,
    kIOHIDPrimaryUsageKey: 0x02,
]

guard let device = IOHIDUserDeviceCreate(kCFAllocatorDefault, properties as CFDictionary) else {
    print("FAIL: IOHIDUserDeviceCreate returned nil")
    exit(1)
}
print("virtual device created")

if #available(macOS 11.0, *) {
    let result = IOHIDUserDeviceActivate(device)
    print("activate: \(result == kIOReturnSuccess ? "OK" : "FAIL \(result)")")
}

print("cursor pos before: \(CGEvent(source: nil)!.location)")

for i in 0..<40 {
    var report: [UInt8] = [0, 10, 0, 0]
    let status = report.withUnsafeBytes { ptr in
        IOHIDUserDeviceHandleReport(device, ptr.baseAddress!, ptr.count)
    }
    if i == 0 { print("first report: \(status == kIOReturnSuccess ? "OK" : "FAIL \(status)")") }
    Thread.sleep(forTimeInterval: 0.02)
}
Thread.sleep(forTimeInterval: 0.3)
print("cursor pos after: \(CGEvent(source: nil)!.location)")
print("如果 before/after 相差约 (400, 0)，虚拟 HID 方案可行")
