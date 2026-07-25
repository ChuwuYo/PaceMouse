import Foundation


setbuf(stdout, nil)
guard let systemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
    print("no client")
    exit(1)
}
IOHIDEventSystemClientSetMatchingMultiple(systemClient, [
    ["DeviceUsagePage": 0x01, "DeviceUsage": 0x02],
    ["DeviceUsagePage": 0x01, "DeviceUsage": 0x01],
] as CFArray)
guard let raw = IOHIDEventSystemClientCopyServices(systemClient) else {
    print("CopyServices nil")
    exit(1)
}
print("raw count: \(CFArrayGetCount(raw))")
for i in 0..<CFArrayGetCount(raw) {
    let service = unsafeBitCast(CFArrayGetValueAtIndex(raw, i), to: IOHIDServiceClientRef.self)
    let linear = IOHIDServiceClientCopyProperty(service, "HIDUseLinearScalingMouseAcceleration" as CFString)
    let pat = IOHIDServiceClientCopyProperty(service, "HIDPointerAccelerationType" as CFString)
    let pa = IOHIDServiceClientCopyProperty(service, "HIDPointerAcceleration" as CFString)
    let mat = IOHIDServiceClientCopyProperty(service, "HIDMouseAccelerationType" as CFString)
    print("mouse: linear=\(String(describing: linear)) HIDPointerAccelerationType=\(String(describing: pat)) HIDPointerAcceleration=\(String(describing: pa)) HIDMouseAccelerationType=\(String(describing: mat))")
}
