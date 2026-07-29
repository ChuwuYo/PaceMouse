import AppKit
import PaceMouseCore
import ServiceManagement

@MainActor
final class SettingsWindowController: NSWindowController {
    var onChange: (() -> Void)?
    var onRequestPermission: (() -> Void)?
    var onOpenLanguageSettings: (() -> Void)?
    var onOpenShakeSettings: (() -> Void)?
    var isAutoCheckEnabled: () -> Bool = { true }
    var onAutoCheckChange: ((Bool) -> Void)?
    var canCheckForUpdates: () -> Bool = { true }
    var onCheckForUpdates: (() -> Void)?
    var onPreReleaseChange: ((Bool) -> Void)?

    private let settings: SettingsStore
    private let smartCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let thresholdSegments = NSSegmentedControl()
    private let thresholdLabel = NSTextField(labelWithString: "")
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginHint = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "", target: nil, action: nil)
    private let statsCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoUpdateCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let preReleaseCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let checkUpdateButton = NSButton(title: "", target: nil, action: nil)
    private let languageLabel = NSTextField(labelWithString: "")
    private let languageButton = NSButton(title: "", target: nil, action: nil)
    private let menuBarIconTitle = NSTextField(labelWithString: "")
    private let menuBarIconHint = NSTextField(labelWithString: "")
    private let menuBarIconMouseButton = MenuBarIconChoiceButton()
    private let menuBarIconLogoButton = MenuBarIconChoiceButton()
    private let shakeLabel = NSTextField(labelWithString: "")
    private let shakeButton = NSButton(title: "", target: nil, action: nil)
    private let versionLabel = NSTextField(labelWithString: "")
    private let pollingRateLabel = NSTextField(labelWithString: "")
    private let rateMonitor = HidRateMonitor()
    private var lastPollingCurrent = 0
    private var lastPollingPeak = 0

    init(settings: SettingsStore) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
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

    func dismiss() {
        rateMonitor.stop()
        window?.orderOut(nil)
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
        autoUpdateCheck.title = tr("Automatically Check for Updates")
        autoUpdateCheck.state = isAutoCheckEnabled() ? .on : .off
        preReleaseCheck.title = tr("Include Pre-release Updates")
        preReleaseCheck.state = settings.includePreReleaseUpdates ? .on : .off
        checkUpdateButton.title = tr("Check for Updates…")
        checkUpdateButton.isEnabled = canCheckForUpdates()
        languageLabel.stringValue = tr("Language")
        languageButton.title = tr("Choose App Language")
        menuBarIconTitle.stringValue = tr("Icon Style")
        menuBarIconHint.stringValue = tr("How PaceMouse appears in your menu bar")
        menuBarIconMouseButton.toolTip = tr("Mouse")
        menuBarIconLogoButton.toolTip = tr("Logo")
        refreshMenuBarIconSelection()
        let trusted = Permissions.isAccessibilityTrusted
        permissionLabel.stringValue = trusted ? tr("Accessibility: Granted") : tr("Accessibility: Not Granted")
        permissionButton.title = trusted ? tr("Open System Settings") : tr("Grant…")
        let shakeOn = ShakeToLocate.isEnabled
        shakeLabel.stringValue = shakeOn ? tr("Shake to Locate: On") : tr("Shake to Locate: Off")
        shakeButton.title = shakeOn ? tr("Turn Off…") : tr("Open System Settings")
        versionLabel.stringValue = tr("PaceMouse v%@", AppVersion.display)
        updatePollingRate(current: lastPollingCurrent, peak: lastPollingPeak)
    }

    private func tr(_ key: String, _ args: CVarArg...) -> String {
        L10n.tr(key, args: args)
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
        loginHint.maximumNumberOfLines = 2
        loginHint.lineBreakMode = .byWordWrapping

        statsCheck.target = self
        statsCheck.action = #selector(statsClicked)

        autoUpdateCheck.target = self
        autoUpdateCheck.action = #selector(autoUpdateClicked)

        preReleaseCheck.target = self
        preReleaseCheck.action = #selector(preReleaseClicked)

        checkUpdateButton.target = self
        checkUpdateButton.action = #selector(checkUpdateClicked)
        checkUpdateButton.bezelStyle = .rounded

        languageButton.target = self
        languageButton.action = #selector(languageClicked)
        languageButton.bezelStyle = .rounded

        menuBarIconTitle.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        menuBarIconHint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        menuBarIconHint.textColor = .secondaryLabelColor
        menuBarIconHint.maximumNumberOfLines = 2
        menuBarIconHint.lineBreakMode = .byWordWrapping

        configureMenuBarIconButton(
            menuBarIconMouseButton,
            styleID: "mouse",
            image: MenuBarMouseImage.template(pointSize: 16, emphasized: false)
        )
        configureMenuBarIconButton(
            menuBarIconLogoButton,
            styleID: "logo",
            image: MenuBarLogoImage.template(pointSize: 16, emphasized: false)
        )

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

        let languageRow = NSStackView(views: [languageLabel, languageButton])
        languageRow.spacing = 12

        let menuBarIconCopy = NSStackView(views: [menuBarIconTitle, menuBarIconHint])
        menuBarIconCopy.orientation = .vertical
        menuBarIconCopy.alignment = .leading
        menuBarIconCopy.spacing = 2

        let menuBarIconChoices = NSStackView(views: [menuBarIconLogoButton, menuBarIconMouseButton])
        menuBarIconChoices.orientation = .horizontal
        menuBarIconChoices.spacing = 8
        menuBarIconChoices.alignment = .centerY

        let menuBarIconSpacer = NSView()
        menuBarIconSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let menuBarIconRow = NSStackView(views: [menuBarIconCopy, menuBarIconSpacer, menuBarIconChoices])
        menuBarIconRow.orientation = .horizontal
        menuBarIconRow.alignment = .centerY
        menuBarIconRow.spacing = 12

        let permissionRow = NSStackView(views: [permissionLabel, permissionButton])
        permissionRow.spacing = 12

        let shakeRow = NSStackView(views: [shakeLabel, shakeButton])
        shakeRow.spacing = 12

        let separator = NSBox()
        separator.boxType = .separator

        let stack = NSStackView(views: [
            smartCheck, thresholdRow, loginCheck, loginHint, statsCheck,
            autoUpdateCheck, preReleaseCheck, checkUpdateButton, languageRow, menuBarIconRow,
            separator, pollingRateLabel, permissionRow, shakeRow, versionLabel,
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
            menuBarIconRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            menuBarIconHint.widthAnchor.constraint(lessThanOrEqualToConstant: 220),
        ])
    }

    private func configureMenuBarIconButton(_ button: MenuBarIconChoiceButton, styleID: String, image: NSImage?) {
        button.styleID = styleID
        image?.isTemplate = true
        button.image = image
        button.target = self
        button.action = #selector(menuBarIconClicked(_:))
    }

    private func refreshMenuBarIconSelection() {
        menuBarIconMouseButton.isChosen = settings.menuBarIcon == "mouse"
        menuBarIconLogoButton.isChosen = settings.menuBarIcon == "logo"
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

    @objc private func autoUpdateClicked() {
        onAutoCheckChange?(autoUpdateCheck.state == .on)
    }

    @objc private func preReleaseClicked() {
        let include = preReleaseCheck.state == .on
        settings.includePreReleaseUpdates = include
        onPreReleaseChange?(include)
        onChange?()
    }

    @objc private func checkUpdateClicked() {
        onCheckForUpdates?()
    }

    @objc private func languageClicked() {
        onOpenLanguageSettings?()
    }

    @objc private func menuBarIconClicked(_ sender: MenuBarIconChoiceButton) {
        guard SettingsStore.supportedMenuBarIcons.contains(sender.styleID) else { return }
        settings.menuBarIcon = sender.styleID
        refreshMenuBarIconSelection()
        onChange?()
    }

    @objc private func permissionClicked() { onRequestPermission?() }

    @objc private func shakeClicked() { onOpenShakeSettings?() }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        refresh()
    }

    func windowWillClose(_ notification: Notification) {
        rateMonitor.stop()
    }
}
