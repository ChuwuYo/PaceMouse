import Testing
@testable import PaceMouseCore

@Test
func smartModeRunsTapWhileManualThrottleIsOff() {
    let shouldRun = ThrottleRuntimePolicy.shouldRunTap(
        manualEnabled: false,
        autoMode: true,
        accessibilityTrusted: true
    )

    #expect(shouldRun)
}

@Test
func tapStopsOnlyWhenManualAndSmartModesAreBothOff() {
    #expect(ThrottleRuntimePolicy.shouldRunTap(
        manualEnabled: true,
        autoMode: false,
        accessibilityTrusted: true
    ))
    #expect(!ThrottleRuntimePolicy.shouldRunTap(
        manualEnabled: false,
        autoMode: false,
        accessibilityTrusted: true
    ))
}

@Test
func tapDoesNotRunWithoutAccessibilityPermission() {
    #expect(!ThrottleRuntimePolicy.shouldRunTap(
        manualEnabled: true,
        autoMode: true,
        accessibilityTrusted: false
    ))
}

@Test
func smartModeStartsInBypass() {
    #expect(ThrottleRuntimePolicy.initialBypass(autoMode: true))
    #expect(!ThrottleRuntimePolicy.initialBypass(autoMode: false))
}

@Test
func smartModeEngagesOnlyAboveThreshold() {
    #expect(ThrottleRuntimePolicy.smartModeShouldEngage(peakHz: 500, threshold: 250))
    #expect(!ThrottleRuntimePolicy.smartModeShouldEngage(peakHz: 250, threshold: 250))
    #expect(!ThrottleRuntimePolicy.smartModeShouldEngage(peakHz: 249, threshold: 250))
}
