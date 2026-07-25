import AppKit
import PaceMouseCore
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController {
    var onChange: (() -> Void)?
    var onRequestPermission: (() -> Void)?
    var onOpenShakeSettings: (() -> Void)?

    private let settings: SettingsStore
    private let smartCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let thresholdSegments = NSSegmentedControl()
    private let thresholdLabel = NSTextField(labelWithString: "")
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginHint = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "", target: nil, action: nil)
    private let statsCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let languageSegments = NSSegmentedControl()
    private let languageLabel = NSTextField(labelWithString: "")
    private let shakeButton = NSButton(title: "", target: nil, action: nil)
    private let versionLabel = NSTextField(labelWithString: "")
    private let pollingRateLabel = NSTextField(labelWithString: "")
    private let rateMonitor = HidRateMonitor()
    private var lastPollingCurrent = 0
    private var lastPollingPeak = 0

    init(settings: SettingsStore) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        rateMonitor.onUpdate = { [weak self] update in
            DispatchQueue.main.async {
                self?.updatePollingRate(current: update.current, peak: update.peak)
            }
        }
        buildContent()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func present() {
        refresh()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updatePollingRate(current: 0, peak: 0)
        rateMonitor.start()
    }

    private func updatePollingRate(current: Int, peak: Int) {
        lastPollingCurrent = current
        lastPollingPeak = peak
        pollingRateLabel.stringValue = tr("Hardware Polling Rate") + ": " + {
            if peak == 0 { return tr("Move mouse to measure") }
            let shown = HidRateMonitor.snapped(peak) ?? peak
            return tr("≈ %lld Hz (measured peak)", Int64(shown))
        }()
    }

    func refresh() {
        window?.title = tr("PaceMouse Settings")
        smartCheck.title = tr("Smart Mode: Engage Only Above Threshold")
        smartCheck.state = settings.autoMode ? .on : .off
        thresholdLabel.stringValue = tr("Engage Threshold")
        thresholdSegments.isEnabled = settings.autoMode
        if let index = SettingsStore.supportedAutoThresholds.firstIndex(of: settings.autoThreshold) {
            thresholdSegments.selectedSegment = index
        }
        loginCheck.title = tr("Launch at Login")
        loginCheck.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let needsApproval = SMAppService.mainApp.status == .requiresApproval
        loginHint.stringValue = tr("Allow PaceMouse in System Settings → General → Login Items")
        loginHint.isHidden = !needsApproval
        statsCheck.title = tr("Show Live Rate in Menu")
        statsCheck.state = settings.showLiveStats ? .on : .off
        languageLabel.stringValue = tr("Language")
        languageSegments.setLabel(tr("System"), forSegment: 0)
        if let index = L10n.supportedLanguages.firstIndex(of: settings.language) {
            languageSegments.selectedSegment = index
        }
        let trusted = Permissions.isAccessibilityTrusted
        permissionLabel.stringValue = trusted ? tr("Accessibility: Granted") : tr("Accessibility: Not Granted")
        permissionButton.title = trusted ? tr("Open System Settings") : tr("Grant…")
        shakeButton.title = tr("Disable Shake to Locate")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        versionLabel.stringValue = tr("PaceMouse v%@", version)
        updatePollingRate(current: lastPollingCurrent, peak: lastPollingPeak)
    }

    private func tr(_ key: String, _ args: CVarArg...) -> String {
        L10n.tr(key, language: settings.language, args: args)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        smartCheck.target = self
        smartCheck.action = #selector(smartClicked)

        thresholdSegments.segmentCount = SettingsStore.supportedAutoThresholds.count
        thresholdSegments.trackingMode = .selectOne
        for (index, value) in SettingsStore.supportedAutoThresholds.enumerated() {
            thresholdSegments.setLabel("\(Int(value))", forSegment: index)
        }
        thresholdSegments.target = self
        thresholdSegments.action = #selector(thresholdClicked)

        loginCheck.target = self
        loginCheck.action = #selector(loginClicked)

        loginHint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        loginHint.textColor = .secondaryLabelColor

        statsCheck.target = self
        statsCheck.action = #selector(statsClicked)

        languageSegments.segmentCount = L10n.supportedLanguages.count
        languageSegments.trackingMode = .selectOne
        languageSegments.setLabel("中文", forSegment: 1)
        languageSegments.setLabel("English", forSegment: 2)
        languageSegments.target = self
        languageSegments.action = #selector(languageClicked)

        permissionButton.target = self
        permissionButton.action = #selector(permissionClicked)
        permissionButton.bezelStyle = .rounded

        shakeButton.target = self
        shakeButton.action = #selector(shakeClicked)
        shakeButton.bezelStyle = .rounded

        versionLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        versionLabel.textColor = .secondaryLabelColor

        let thresholdRow = NSStackView(views: [thresholdLabel, thresholdSegments])
        thresholdRow.spacing = 12

        let languageRow = NSStackView(views: [languageLabel, languageSegments])
        languageRow.spacing = 12

        let permissionRow = NSStackView(views: [permissionLabel, permissionButton])
        permissionRow.spacing = 12

        let separator = NSBox()
        separator.boxType = .separator

        let stack = NSStackView(views: [
            smartCheck, thresholdRow, loginCheck, loginHint, statsCheck, languageRow,
            separator, pollingRateLabel, permissionRow, shakeButton, versionLabel,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
        ])
    }

    @objc private func smartClicked() {
        settings.autoMode = smartCheck.state == .on
        onChange?()
    }

    @objc private func thresholdClicked() {
        let index = thresholdSegments.selectedSegment
        guard SettingsStore.supportedAutoThresholds.indices.contains(index) else { return }
        settings.autoThreshold = SettingsStore.supportedAutoThresholds[index]
        onChange?()
    }

    @objc private func loginClicked() {
        do {
            if loginCheck.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginHint.stringValue = tr("Failed: %@", error.localizedDescription)
            loginHint.isHidden = false
        }
        refresh()
    }

    @objc private func statsClicked() {
        settings.showLiveStats = statsCheck.state == .on
        onChange?()
    }

    @objc private func languageClicked() {
        let index = languageSegments.selectedSegment
        guard L10n.supportedLanguages.indices.contains(index) else { return }
        settings.language = L10n.supportedLanguages[index]
        onChange?()
    }

    @objc private func permissionClicked() { onRequestPermission?() }

    @objc private func shakeClicked() { onOpenShakeSettings?() }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        rateMonitor.stop()
    }
}
