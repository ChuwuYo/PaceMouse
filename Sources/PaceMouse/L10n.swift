import Foundation

@MainActor
enum L10n {
    static let supportedLanguages = ["system", "zh-Hans", "en"]

    private static var cache: [String: Bundle] = [:]

    static func tr(_ key: String, language: String) -> String {
        if language != "system", let bundle = bundle(for: language) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    static func tr(_ key: String, language: String, args: [CVarArg]) -> String {
        String(format: tr(key, language: language), arguments: args)
    }

    private static func bundle(for language: String) -> Bundle? {
        if let cached = cache[language] { return cached }
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        cache[language] = bundle
        return bundle
    }
}
