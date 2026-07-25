import Foundation
import IOKit.hid

public struct HidRateUpdate: Sendable {
    public var current: Int
    public var peak: Int
}

public final class HidRateMonitor: @unchecked Sendable {
    public static let standardRates = [125, 250, 500, 1000, 2000, 4000, 8000]

    public var onUpdate: ((HidRateUpdate) -> Void)?

    private var manager: IOHIDManager?
    private var timer: Timer?
    private let lock = NSLock()
    private var perDevice: [ObjectIdentifier: Int] = [:]
    private var peak = 0

    public init() {}

    public func start() {
        guard manager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, [
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse],
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Pointer],
        ] as CFArray)
        IOHIDManagerRegisterInputValueCallback(manager, hidValueCallback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            let current = self.perDevice.values.max() ?? 0
            self.perDevice = [:]
            self.peak = max(self.peak, current)
            let peak = self.peak
            self.lock.unlock()
            self.onUpdate?(HidRateUpdate(current: current, peak: peak))
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        peak = 0
    }

    public static func snapped(_ rate: Int) -> Int? {
        standardRates.first { abs($0 - rate) <= max(1, $0 / 8) }
    }

    fileprivate func noteValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == 0x01, IOHIDElementGetUsage(element) == 0x30 else { return }
        let device = IOHIDElementGetDevice(element)
        let id = ObjectIdentifier(device)
        lock.lock()
        perDevice[id, default: 0] += 1
        lock.unlock()
    }
}

private let hidValueCallback: IOHIDValueCallback = { context, _, _, value in
    guard let context else { return }
    Unmanaged<HidRateMonitor>.fromOpaque(context).takeUnretainedValue().noteValue(value)
}
