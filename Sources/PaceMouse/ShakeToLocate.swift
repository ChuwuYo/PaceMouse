import AppKit

enum ShakeToLocate {
    static var isEnabled: Bool {
        let key = "CGDisableCursorLocationMagnification" as CFString
        guard let value = CFPreferencesCopyAppValue(key, kCFPreferencesAnyApplication) else {
            return true
        }
        if let flag = value as? Bool { return !flag }
        if let number = value as? NSNumber { return !number.boolValue }
        return true
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display") else { return }
        NSWorkspace.shared.open(url)
    }
}
