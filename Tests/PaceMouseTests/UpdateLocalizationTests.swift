import Foundation
import Testing

private let supportedLocalizations = [
    "en", "zh-Hans", "zh-Hant", "ja", "ko", "pt", "es", "de", "fr", "it",
]

private let formatPlaceholderPattern = try! NSRegularExpression(pattern: #"%(?:lld|@)"#)

private enum LocalizationTestError: Error {
    case invalidStringsFile(String)
}

private func loadLocalization(at url: URL) throws -> [String: String] {
    let data = try Data(contentsOf: url)
    let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    guard let localization = propertyList as? [String: String] else {
        throw LocalizationTestError.invalidStringsFile(url.path)
    }
    return localization
}

private func formatPlaceholders(in value: String) -> [String] {
    let range = NSRange(value.startIndex..., in: value)
    return formatPlaceholderPattern.matches(in: value, range: range).compactMap { match in
        Range(match.range, in: value).map { String(value[$0]) }
    }
}

@Test
func interfaceLocalizationsMatchEnglishKeysAndPlaceholders() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let resources = root.appendingPathComponent("Sources/PaceMouse/Resources")
    let english = try loadLocalization(
        at: resources.appendingPathComponent("en.lproj/Localizable.strings")
    )
    let englishKeys = Set(english.keys)

    #expect(english.count == 46)

    for language in supportedLocalizations {
        let localization = try loadLocalization(
            at: resources.appendingPathComponent("\(language).lproj/Localizable.strings")
        )
        #expect(
            Set(localization.keys) == englishKeys,
            "\(language) localization keys differ from English"
        )
        for key in englishKeys {
            let localizedValue = try #require(localization[key])
            #expect(
                formatPlaceholders(in: localizedValue) == formatPlaceholders(in: english[key]!),
                "\(language) format placeholders differ for \(key)"
            )
        }
    }
}
