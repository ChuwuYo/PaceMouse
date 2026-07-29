import Foundation

final class SettingsStore {
    static let supportedRates: [Double] = [125, 250, 500]
    static let customRateRange = 100...500
    static let defaultRate = 250.0

    var onChange: (() -> Void)?

    private let defaults = UserDefaults.standard

    var isEnabled: Bool {
        get { defaults.bool(forKey: "enabled") }
        set { defaults.set(newValue, forKey: "enabled"); onChange?() }
    }

    var targetHz: Double {
        get {
            guard let value = defaults.object(forKey: Keys.targetHz) as? NSNumber else {
                return Self.defaultRate
            }
            return Self.normalizedRate(value.doubleValue)
        }
        set {
            let rate = Self.normalizedRate(newValue)
            let custom = !Self.supportedRates.contains(rate)
            let changed = targetHz != rate || usesCustomRate != custom
            defaults.set(rate, forKey: Keys.targetHz)
            defaults.set(custom, forKey: Keys.usesCustomRate)
            if custom {
                defaults.set(rate, forKey: Keys.customTargetHz)
            }
            if changed { onChange?() }
        }
    }

    var customTargetHz: Double {
        get {
            guard let value = defaults.object(forKey: Keys.customTargetHz) as? NSNumber else {
                return targetHz
            }
            return Self.normalizedRate(value.doubleValue)
        }
        set {
            let rate = Self.normalizedRate(newValue)
            let changed = customTargetHz != rate || usesCustomRate && targetHz != rate
            defaults.set(rate, forKey: Keys.customTargetHz)
            if usesCustomRate {
                defaults.set(rate, forKey: Keys.targetHz)
            }
            if changed, usesCustomRate { onChange?() }
        }
    }

    var usesCustomRate: Bool {
        if !Self.supportedRates.contains(targetHz) {
            return true
        }
        if let stored = defaults.object(forKey: Keys.usesCustomRate) as? Bool {
            return stored
        }
        return false
    }

    func selectPresetRate(_ rate: Double) {
        guard Self.supportedRates.contains(rate) else { return }
        selectRate(rate, custom: false)
    }

    func selectCustomRate() {
        selectRate(customTargetHz, custom: true)
    }

    private func selectRate(_ rate: Double, custom: Bool) {
        let changed = usesCustomRate != custom || targetHz != rate
        defaults.set(custom, forKey: Keys.usesCustomRate)
        defaults.set(rate, forKey: Keys.targetHz)
        if changed { onChange?() }
    }

    var permissionPromptShown: Bool {
        get { defaults.bool(forKey: "permissionPromptShown") }
        set { defaults.set(newValue, forKey: "permissionPromptShown") }
    }

    var loginPromptShown: Bool {
        get { defaults.bool(forKey: "loginPromptShown") }
        set { defaults.set(newValue, forKey: "loginPromptShown") }
    }

    var shakePromptShown: Bool {
        get { defaults.bool(forKey: "shakePromptShown") }
        set { defaults.set(newValue, forKey: "shakePromptShown") }
    }

    var language: String {
        get { defaults.string(forKey: "language") ?? "system" }
        set { defaults.set(newValue, forKey: "language"); onChange?() }
    }

    var showLiveStats: Bool {
        get { defaults.object(forKey: "showLiveStats") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showLiveStats"); onChange?() }
    }

    static let supportedAutoThresholds: [Double] = [250, 500, 1000]

    var autoMode: Bool {
        get { defaults.bool(forKey: "autoMode") }
        set { defaults.set(newValue, forKey: "autoMode"); onChange?() }
    }

    var autoThreshold: Double {
        get {
            let value = defaults.double(forKey: "autoThreshold")
            return value > 0 ? value : 500
        }
        set { defaults.set(newValue, forKey: "autoThreshold"); onChange?() }
    }

    var includePreReleaseUpdates: Bool {
        get { defaults.object(forKey: Keys.includePreReleaseUpdates) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.includePreReleaseUpdates); onChange?() }
    }

    static let supportedMenuBarIcons = ["mouse", "logo"]

    var menuBarIcon: String {
        get {
            let value = defaults.string(forKey: Keys.menuBarIcon) ?? "logo"
            return Self.supportedMenuBarIcons.contains(value) ? value : "logo"
        }
        set { defaults.set(newValue, forKey: Keys.menuBarIcon); onChange?() }
    }

    enum Keys {
        static let targetHz = "targetHz"
        static let customTargetHz = "customTargetHz"
        static let usesCustomRate = "usesCustomRate"
        static let includePreReleaseUpdates = "includePreReleaseUpdates"
        static let menuBarIcon = "menuBarIcon"
    }

    private static func normalizedRate(_ value: Double) -> Double {
        guard value.isFinite else { return defaultRate }
        let clamped = min(max(value, Double(customRateRange.lowerBound)), Double(customRateRange.upperBound))
        return clamped.rounded()
    }
}
