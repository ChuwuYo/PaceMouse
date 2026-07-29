import AppKit
import PaceMouseCore
import OSLog
import ServiceManagement

private let logger = Logger(subsystem: "com.chuwuyo.pacemouse", category: "app")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let bridge = TapBridge()
    private let statusController = StatusItemController()
    private let updater = UpdateController()
    private lazy var settingsWindow = SettingsWindowController(settings: settings)
    private var permissionTimer: Timer?
    private var lastTrusted = false
    private var lastAppliedAutoMode = false
    private var isBypassing = false
    private var latestPeakHz = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        PointerTuner.recoverIfNeeded()
        settings.onChange = { [weak self] in
            logger.notice("settings changed")
            self?.apply()
        }
        statusController.onToggleEnabled = { [weak self] in
            guard let self else { return }
            logger.notice("toggle clicked, enabled=\(!self.settings.isEnabled)")
            self.settings.isEnabled.toggle()
            if self.settings.isEnabled && !Permissions.isAccessibilityTrusted {
                self.guidePermission()
            }
        }
        statusController.onSelectRate = { [weak self] hz in
            self?.settings.selectPresetRate(hz)
        }
        statusController.onSelectCustomRate = { [weak self] in
            self?.settings.selectCustomRate()
        }
        statusController.onChangeCustomRate = { [weak self] hz in
            self?.settings.customTargetHz = hz
        }
        statusController.onRequestPermission = { [weak self] in
            self?.guidePermission()
        }
        statusController.onOpenSettings = { [weak self] in
            self?.settingsWindow.present()
        }
        statusController.onPopoverWillOpen = { [weak self] in
            self?.settingsWindow.dismiss()
        }
        statusController.onInstallUpdate = { [weak self] in
            self?.updater.checkForUpdates()
        }
        settingsWindow.onRequestPermission = { [weak self] in
            self?.guidePermission()
        }
        settingsWindow.onOpenLanguageSettings = {
            SystemSettings.open(.languageAndRegion)
        }
        settingsWindow.onOpenShakeSettings = {
            SystemSettings.open(.shakeToLocate)
        }
        settingsWindow.isAutoCheckEnabled = { [weak self] in
            self?.updater.automaticallyChecksForUpdates ?? true
        }
        settingsWindow.onAutoCheckChange = { [weak self] enabled in
            self?.updater.automaticallyChecksForUpdates = enabled
        }
        settingsWindow.canCheckForUpdates = { [weak self] in
            self?.updater.canCheckForUpdates ?? false
        }
        settingsWindow.onCheckForUpdates = { [weak self] in
            self?.updater.checkForUpdates()
        }
        settingsWindow.onPreReleaseChange = { [weak self] include in
            self?.updater.applyChannelPreference(includePreRelease: include)
        }
        updater.onPendingUpdateChange = { [weak self] version in
            self?.statusController.setPendingUpdate(version: version)
        }
        updater.onCanCheckForUpdatesChange = { [weak self] _ in
            self?.settingsWindow.refresh()
        }
        bridge.onStats = { stats in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.statusController.updateStats(ingest: stats.ingest, emit: stats.emit, bypass: self.isBypassing)
                self.updateAutoBypass(peakHz: stats.peakHz)
            }
        }
        apply()
        startPermissionWatch()
        updater.start()
        DispatchQueue.main.async { [weak self] in
            self?.promptOnLaunch()
        }
    }

    private func promptOnLaunch() {
        if Permissions.isAccessibilityTrusted {
            maybePromptShake()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        if settings.permissionPromptShown {
            SystemSettings.open(.accessibility)
        } else {
            settings.permissionPromptShown = true
            Permissions.requestAccessibilityPrompt()
        }
    }

    private func maybePromptShake() {
        guard !settings.shakePromptShown else {
            maybePromptLogin()
            return
        }
        settings.shakePromptShown = true
        guard ShakeToLocate.isEnabled else {
            maybePromptLogin()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = tr("Turn off Shake to Locate?")
        alert.informativeText = tr("Shaking to enlarge the pointer can interfere with high-rate mice. You can change this later in Settings.")
        alert.addButton(withTitle: tr("Turn Off…"))
        alert.addButton(withTitle: tr("Not Now"))
        if alert.runModal() == .alertFirstButtonReturn {
            SystemSettings.open(.shakeToLocate)
        }
        settingsWindow.refresh()
        maybePromptLogin()
    }

    private func maybePromptLogin() {
        guard !settings.loginPromptShown else { return }
        settings.loginPromptShown = true
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = tr("Launch PaceMouse at login?")
        alert.informativeText = tr("You can change this later in Settings.")
        alert.addButton(withTitle: tr("Start at Login"))
        alert.addButton(withTitle: tr("Not Now"))
        if alert.runModal() == .alertFirstButtonReturn {
            try? SMAppService.mainApp.register()
        }
        settingsWindow.refresh()
    }

    private func tr(_ key: String) -> String {
        L10n.tr(key)
    }

    private func apply() {
        let trusted = Permissions.isAccessibilityTrusted
        let autoMode = settings.autoMode
        let wasRunning = bridge.isRunning
        let resetToSmartStandby = autoMode && (!lastAppliedAutoMode || !wasRunning)
        lastAppliedAutoMode = autoMode
        logger.notice("apply: enabled=\(self.settings.isEnabled) auto=\(autoMode) hz=\(self.settings.targetHz) trusted=\(trusted)")
        let shouldRunTap = ThrottleRuntimePolicy.shouldRunTap(
            manualEnabled: settings.isEnabled,
            autoMode: autoMode,
            accessibilityTrusted: trusted
        )
        if shouldRunTap {
            if wasRunning {
                bridge.setTargetHz(settings.targetHz)
                if resetToSmartStandby {
                    latestPeakHz = 0
                }
                if autoMode {
                    setBypass(ThrottleRuntimePolicy.smartModeShouldBypass(
                        peakHz: latestPeakHz,
                        threshold: settings.autoThreshold
                    ))
                } else {
                    setBypass(false)
                }
            } else {
                if autoMode { latestPeakHz = 0 }
                let initialBypass = ThrottleRuntimePolicy.initialBypass(autoMode: autoMode)
                isBypassing = initialBypass
                _ = bridge.start(
                    hz: settings.targetHz,
                    bypass: initialBypass
                )
            }
            if bridge.isRunning && !isBypassing {
                PointerTuner.disableAcceleration()
            } else {
                PointerTuner.restore()
            }
        } else {
            bridge.stop()
            isBypassing = false
            PointerTuner.restore()
        }
        statusController.update(state: MenuState(
            enabled: settings.isEnabled,
            tapRunning: bridge.isRunning,
            rate: settings.targetHz,
            customRate: settings.customTargetHz,
            usesCustomRate: settings.usesCustomRate,
            trusted: trusted,
            showStats: settings.showLiveStats,
            menuBarIcon: settings.menuBarIcon))
        settingsWindow.refresh()
    }

    private func setBypass(_ bypass: Bool) {
        guard isBypassing != bypass else { return }
        isBypassing = bypass
        bridge.bypass = bypass
    }

    private func updateAutoBypass(peakHz: Int) {
        guard settings.autoMode, bridge.isRunning else { return }
        latestPeakHz = peakHz
        let shouldBypass = ThrottleRuntimePolicy.smartModeShouldBypass(
            peakHz: peakHz,
            threshold: settings.autoThreshold
        )
        setBypass(shouldBypass)
        if shouldBypass {
            PointerTuner.restore()
        } else {
            PointerTuner.disableAcceleration()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PointerTuner.restore()
    }

    private func guidePermission() {
        NSApp.activate(ignoringOtherApps: true)
        if settings.permissionPromptShown {
            SystemSettings.open(.accessibility)
        } else {
            settings.permissionPromptShown = true
            Permissions.requestAccessibilityPrompt()
        }
    }

    private func startPermissionWatch() {
        lastTrusted = Permissions.isAccessibilityTrusted
        let timer = Timer(timeInterval: 2, target: self, selector: #selector(checkPermissionChange), userInfo: nil, repeats: true)
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private var maintenanceTick = 0

    @objc private func checkPermissionChange() {
        maintenanceTick += 1
        if maintenanceTick % 5 == 0 {
            PointerTuner.reapplyIfActive()
        }
        let trusted = Permissions.isAccessibilityTrusted
        guard trusted != lastTrusted else { return }
        lastTrusted = trusted
        apply()
        if trusted { maybePromptShake() }
    }
}
