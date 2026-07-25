import PaceMouseCore
import Testing

@Test
func preReleaseChannelAllowedWhenEnabled() {
    #expect(UpdateChannel.allowedChannels(includePreRelease: true) == [UpdateChannel.preRelease])
}

@Test
func stableOnlyExcludesPreReleaseChannel() {
    #expect(UpdateChannel.allowedChannels(includePreRelease: false).isEmpty)
}

@Test
func preReleaseChannelNameMatchesSparkleConvention() {
    #expect(UpdateChannel.preRelease == "pre-release")
}
