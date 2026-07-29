public enum ThrottleRuntimePolicy {
    public static func shouldRunTap(
        manualEnabled: Bool,
        autoMode: Bool,
        accessibilityTrusted: Bool
    ) -> Bool {
        accessibilityTrusted && (manualEnabled || autoMode)
    }

    public static func initialBypass(autoMode: Bool) -> Bool {
        autoMode
    }

    public static func smartModeShouldEngage(peakHz: Int, threshold: Double) -> Bool {
        Double(peakHz) > threshold
    }
}
