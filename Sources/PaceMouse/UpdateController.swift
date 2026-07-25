import AppKit
import PaceMouseCore
import Sparkle

@MainActor
final class UpdateController: NSObject {
    var onPendingUpdateChange: ((String?) -> Void)?
    var onCanCheckForUpdatesChange: ((Bool) -> Void)?

    private(set) var pendingDisplayVersion: String? {
        didSet { onPendingUpdateChange?(pendingDisplayVersion) }
    }

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: self)

    private var canCheckObservation: NSKeyValueObservation?

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    func start() {
        do {
            try controller.updater.start()
        } catch {
            NSLog("Sparkle failed to start: %@", error.localizedDescription)
        }
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, change in
            let enabled = change.newValue ?? false
            Task { @MainActor in
                self?.onCanCheckForUpdatesChange?(enabled)
            }
        }
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    func clearPendingUpdate() {
        pendingDisplayVersion = nil
    }

    func applyChannelPreference(includePreRelease: Bool) {
        if !includePreRelease {
            clearPendingUpdate()
            controller.userDriver.dismissUpdateInstallation()
        }
        controller.updater.resetUpdateCycle()
    }
}

extension UpdateController: SPUUpdaterDelegate {
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        "https://github.com/ChuwuYo/PaceMouse/releases/download/app-latest/appcast.xml"
    }

    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let include = UserDefaults.standard.object(forKey: SettingsStore.Keys.includePreReleaseUpdates) as? Bool ?? true
        return UpdateChannel.allowedChannels(includePreRelease: include)
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard Self.isItemAllowed(item) else { return }
        let version = item.displayVersionString
        Task { @MainActor in
            self.pendingDisplayVersion = version
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        Task { @MainActor in
            self.pendingDisplayVersion = nil
        }
    }
}

extension UpdateController: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        false
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        guard Self.isItemAllowed(update) else { return }
        let version = update.displayVersionString
        Task { @MainActor in
            self.pendingDisplayVersion = version
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in
            self.pendingDisplayVersion = nil
        }
    }
}

extension UpdateController {
    nonisolated private static func isItemAllowed(_ item: SUAppcastItem) -> Bool {
        let channel = item.channel ?? ""
        if channel == UpdateChannel.preRelease {
            let include = UserDefaults.standard.object(forKey: SettingsStore.Keys.includePreReleaseUpdates) as? Bool ?? true
            return include
        }
        return true
    }
}
