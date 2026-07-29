import AppKit

enum SystemSettings {
    enum Destination: String {
        case accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case languageAndRegion = "x-apple.systempreferences:com.apple.Localization-Settings.extension"
        case shakeToLocate = "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display"
    }

    static func open(_ destination: Destination) {
        guard let url = URL(string: destination.rawValue) else { return }
        NSWorkspace.shared.open(url)
    }
}
