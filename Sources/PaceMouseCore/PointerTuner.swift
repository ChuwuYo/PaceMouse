import CoreFoundation
import Foundation
import PaceMouseHID

@MainActor
public enum PointerTuner {
    private static let typeKey = "HIDPointerAccelerationType"
    private static let pointerKey = "HIDPointerAcceleration"
    private static let fallbackKey = "HIDMouseAccelerationType"
    private static let linearScalingKey = "HIDUseLinearScalingMouseAcceleration"
    private static let dirtyDefaultsKey = "pacemouse.accel.dirty"
    private static let savedDefaultsKey = "pacemouse.accel.saved"

    private static var systemClient: IOHIDEventSystemClientRef?
    private static var savedValues: [String: NSNumber] = [:]
    public private(set) static var active = false

    public static func disableAcceleration() {
        if systemClient == nil {
            systemClient = createSystemClient()
        }
        guard systemClient != nil else {
            active = false
            return
        }
        applyToServices()
        active = !savedValues.isEmpty
        persistDirty()
    }

    public static func reapplyIfActive() {
        guard active else { return }
        applyToServices()
    }

    public static func restore() {
        guard active else { return }
        active = false
        forEachMouseService { service in
            guard let key = valueKey(for: service), let saved = savedValues[key] else { return }
            IOHIDServiceClientSetProperty(service, key as CFString, saved)
        }
        savedValues = [:]
        clearDirty()
    }

    public static func recoverIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: dirtyDefaultsKey),
              let saved = defaults.dictionary(forKey: savedDefaultsKey) as? [String: NSNumber],
              !saved.isEmpty else { return }
        forEachMouseService { service in
            guard let key = valueKey(for: service), let value = saved[key] else { return }
            IOHIDServiceClientSetProperty(service, key as CFString, value)
        }
        clearDirty()
    }

    private static func applyToServices() {
        forEachMouseService { service in
            if let linear = IOHIDServiceClientCopyProperty(service, linearScalingKey as CFString) as? Int, linear == 1 {
                return
            }
            guard let key = valueKey(for: service),
                  let current = IOHIDServiceClientCopyProperty(service, key as CFString) as? NSNumber else { return }
            if savedValues[key] == nil, current.intValue != 0 {
                savedValues[key] = current
            }
            IOHIDServiceClientSetProperty(service, key as CFString, NSNumber(value: 0))
        }
    }

    private static func valueKey(for service: IOHIDServiceClientRef) -> String? {
        if let named = IOHIDServiceClientCopyProperty(service, typeKey as CFString) as? String, !named.isEmpty {
            return named
        }
        if IOHIDServiceClientCopyProperty(service, pointerKey as CFString) != nil { return pointerKey }
        if IOHIDServiceClientCopyProperty(service, fallbackKey as CFString) != nil { return fallbackKey }
        return nil
    }

    private static func createSystemClient() -> IOHIDEventSystemClientRef? {
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return nil }
        IOHIDEventSystemClientSetMatchingMultiple(client, [
            ["DeviceUsagePage": 0x01, "DeviceUsage": 0x02],
            ["DeviceUsagePage": 0x01, "DeviceUsage": 0x01],
        ] as CFArray)
        return client
    }

    private static func forEachMouseService(_ body: (IOHIDServiceClientRef) -> Void) {
        guard let systemClient, let raw = IOHIDEventSystemClientCopyServices(systemClient) else { return }
        for index in 0..<CFArrayGetCount(raw) {
            let service = unsafeBitCast(CFArrayGetValueAtIndex(raw, index), to: IOHIDServiceClientRef.self)
            body(service)
        }
    }

    private static func persistDirty() {
        let defaults = UserDefaults.standard
        defaults.set(!savedValues.isEmpty, forKey: dirtyDefaultsKey)
        defaults.set(savedValues, forKey: savedDefaultsKey)
    }

    private static func clearDirty() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: dirtyDefaultsKey)
        defaults.removeObject(forKey: savedDefaultsKey)
    }
}
