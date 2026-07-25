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
    private lazy var settingsWindow = SettingsWindowController(settings: settings)
    private var permissionTimer: Timer?
    private var lastTrusted = true

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
            self?.settings.targetHz = hz
        }
        statusController.onRequestPermission = { [weak self] in
            self?.guidePermission()
        }
        statusController.onOpenSettings = { [weak self] in
            self?.settingsWindow.present()
        }
        settingsWindow.onChange = { [weak self] in
            self?.apply()
        }
        settingsWindow.onRequestPermission = { [weak self] in
            self?.guidePermission()
        }
        settingsWindow.onOpenShakeSettings = {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display") else { return }
            NSWorkspace.shared.open(url)
        }
        bridge.onStats = { stats in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateAutoBypass(peakHz: stats.peakHz)
                self.statusController.updateStats(ingest: stats.ingest, emit: stats.emit, bypass: self.bridge.bypass)
            }
        }
        apply()
        startPermissionWatch()
        if !Permissions.isAccessibilityTrusted && !settings.permissionPromptShown {
            guidePermission()
        } else if Permissions.isAccessibilityTrusted {
            maybePromptLogin()
        }
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
        L10n.tr(key, language: settings.language)
    }

    private func apply() {
        let trusted = Permissions.isAccessibilityTrusted
        logger.notice("apply: enabled=\(self.settings.isEnabled) hz=\(self.settings.targetHz) trusted=\(trusted)")
        if !settings.autoMode { bridge.bypass = false }
        if settings.isEnabled && trusted {
            if bridge.isRunning {
                bridge.setTargetHz(settings.targetHz)
                PointerTuner.disableAcceleration()
            } else {
                let state = bridge.start(hz: settings.targetHz)
                if state == .running { PointerTuner.disableAcceleration() }
            }
        } else {
            bridge.stop()
            PointerTuner.restore()
        }
        statusController.update(state: MenuState(
            enabled: settings.isEnabled,
            rate: settings.targetHz,
            trusted: trusted,
            showStats: settings.showLiveStats,
            language: settings.language))
        settingsWindow.refresh()
    }

    private var lastHighPeak = Date.distantPast

    private func updateAutoBypass(peakHz: Int) {
        guard settings.autoMode, settings.isEnabled else {
            bridge.bypass = false
            return
        }
        if Double(peakHz) > settings.autoThreshold {
            bridge.bypass = false
            lastHighPeak = Date()
            PointerTuner.disableAcceleration()
        } else if bridge.bypass == false, Date().timeIntervalSince(lastHighPeak) > 5 {
            bridge.bypass = true
            PointerTuner.restore()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PointerTuner.restore()
    }

    private func guidePermission() {
        if settings.permissionPromptShown {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
            NSWorkspace.shared.open(url)
        } else {
            settings.permissionPromptShown = true
            Permissions.requestAccessibilityPrompt()
        }
    }

    private func startPermissionWatch() {
        lastTrusted = Permissions.isAccessibilityTrusted
        let timer = Timer(timeInterval: 2, target: self, selector: #selector(checkPermissionChange), userInfo: nil, repeats: true)
        timer.tolerance = 0.5
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
        if trusted { maybePromptLogin() }
    }
}
