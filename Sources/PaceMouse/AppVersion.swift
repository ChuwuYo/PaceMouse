import Foundation

enum AppVersion {
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    static var display: String {
        format(marketing: marketing, build: build)
    }

    static func format(marketing: String, build: String) -> String {
        let trimmedBuild = build.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBuild.isEmpty || trimmedBuild == marketing {
            return marketing
        }
        return "\(marketing) (\(trimmedBuild))"
    }
}
