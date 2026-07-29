import Foundation
import Testing

@Test
func interfaceLocalizationKeysExistInEnglishAndChinese() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let keys = [
        "Custom",
        "Automatically Check for Updates",
        "Include Pre-release Updates",
        "Check for Updates…",
        "Update Available — v%@…",
        "Update Available",
        "Language",
        "Choose App Language",
        "Open System Settings",
    ]
    for lang in ["en", "zh-Hans"] {
        let url = root
            .appendingPathComponent("Sources/PaceMouse/Resources/\(lang).lproj/Localizable.strings")
        let text = try String(contentsOf: url, encoding: .utf8)
        for key in keys {
            #expect(text.contains("\"\(key)\""), "missing \(key) in \(lang)")
        }
    }
}
