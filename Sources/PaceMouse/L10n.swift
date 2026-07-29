import Foundation

@MainActor
enum L10n {
    static func tr(_ key: String) -> String {
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    static func tr(_ key: String, args: [CVarArg]) -> String {
        String(format: tr(key), arguments: args)
    }
}
