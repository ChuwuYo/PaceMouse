import Foundation

final class SettingsStore {
    static let supportedRates: [Double] = [125, 250, 500]

    var onChange: (() -> Void)?

    private let defaults = UserDefaults.standard

    var isEnabled: Bool {
        get { defaults.bool(forKey: "enabled") }
        set { defaults.set(newValue, forKey: "enabled"); onChange?() }
    }

    var targetHz: Double {
        get {
            let value = defaults.double(forKey: "targetHz")
            return value > 0 ? value : 250
        }
        set { defaults.set(newValue, forKey: "targetHz"); onChange?() }
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
        static let includePreReleaseUpdates = "includePreReleaseUpdates"
        static let menuBarIcon = "menuBarIcon"
    }
}
