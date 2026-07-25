public enum UpdateChannel {
    public static let preRelease = "pre-release"

    public static func allowedChannels(includePreRelease: Bool) -> Set<String> {
        includePreRelease ? [preRelease] : []
    }
}
