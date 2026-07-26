import AppKit
import PaceMouseCore
import OSLog

private let logger = Logger(subsystem: "com.chuwuyo.pacemouse", category: "ui")

struct MenuState {
    var enabled: Bool
    var rate: Double
    var trusted: Bool
    var showStats: Bool
    var language: String
    var menuBarIcon: String
}

private final class CapsuleButton: NSButton {
    var horizontalPadding: CGFloat = 0 {
        didSet { invalidateIntrinsicContentSize() }
    }

    private var hovered = false
    private var trackingAreaRef: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += horizontalPadding * 2
        return size
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        wantsLayer = true
        refreshLayer()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        refreshLayer()
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        refreshLayer()
    }

    private func refreshLayer() {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(hovered ? 0.16 : 0.09).cgColor
    }
}

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    var onToggleEnabled: (() -> Void)?
    var onSelectRate: ((Double) -> Void)?
    var onRequestPermission: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onPopoverWillOpen: (() -> Void)?
    var onInstallUpdate: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: 20)
    private let popover = NSPopover()
    private let statsLabel = NSTextField(labelWithString: "")
    private let toggleButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let rateSegments = NSSegmentedControl()
    private let permissionButton = NSButton(title: "", target: nil, action: nil)
    private let updateButton = NSButton(title: "", target: nil, action: nil)
    private let settingsButton = CapsuleButton()
    private let quitButton = CapsuleButton()
    private let statsSeparator = NSBox()
    private let accessorySeparator = NSBox()
    private let footerSeparator = NSBox()
    private var state = MenuState(
        enabled: false, rate: 250, trusted: false, showStats: true, language: "system", menuBarIcon: "logo")
    private var running = false
    private var pendingUpdateVersion: String?

    override init() {
        super.init()
        updateIcon()
        configureControls()
        configurePopover()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
        }
    }

    func update(state: MenuState) {
        logger.notice("update ui: enabled=\(state.enabled) rate=\(state.rate) trusted=\(state.trusted)")
        self.state = state
        running = state.enabled && state.trusted
        toggleButton.state = state.enabled ? .on : .off
        if let index = SettingsStore.supportedRates.firstIndex(of: state.rate) {
            rateSegments.selectedSegment = index
        }
        reloadStrings()
        refreshAccessoryVisibility()
        updateIcon()
        if !running {
            statsLabel.stringValue = state.trusted
                ? tr("Stopped")
                : tr("Waiting for Accessibility Permission")
        }
        refreshPopoverContentSizeIfNeeded()
    }

    func updateStats(ingest: Int, emit: Int, bypass: Bool) {
        guard running else { return }
        if bypass {
            statsLabel.stringValue = ingest == 0
                ? tr("Smart Standby")
                : tr("In %lld Hz · Bypass", Int64(ingest))
        } else {
            statsLabel.stringValue = tr("In %lld Hz → Out %lld Hz", Int64(ingest), Int64(emit))
        }
    }

    func setPendingUpdate(version: String?) {
        pendingUpdateVersion = version
        reloadStrings()
        refreshAccessoryVisibility()
        updateIcon()
        refreshPopoverContentSizeIfNeeded()
    }

    private func configureControls() {
        toggleButton.target = self
        toggleButton.action = #selector(toggleClicked)

        rateSegments.segmentCount = SettingsStore.supportedRates.count
        rateSegments.trackingMode = .selectOne
        for (index, value) in SettingsStore.supportedRates.enumerated() {
            rateSegments.setLabel("\(Int(value))", forSegment: index)
        }
        rateSegments.target = self
        rateSegments.action = #selector(rateClicked)

        statsLabel.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
        statsLabel.textColor = .secondaryLabelColor
        statsLabel.lineBreakMode = .byTruncatingTail
        statsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        configureTextRowButton(permissionButton, action: #selector(permissionClicked))
        configureTextRowButton(updateButton, action: #selector(updateClicked))

        for box in [statsSeparator, accessorySeparator, footerSeparator] {
            box.boxType = .separator
        }

        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.imagePosition = .imageOnly
        settingsButton.contentTintColor = NSColor.labelColor.withAlphaComponent(0.8)
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)
        settingsButton.image?.isTemplate = true

        quitButton.imagePosition = .noImage
        quitButton.target = self
        quitButton.action = #selector(quitClicked)

        for (button, width) in [(settingsButton, 30.0), (quitButton, 0.0)] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
            if width > 0 {
                button.widthAnchor.constraint(equalToConstant: width).isActive = true
            } else {
                button.horizontalPadding = 12
            }
        }
    }

    private func configurePopover() {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let bottomRow = NSStackView(views: [spacer, settingsButton, quitButton])
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 10
        bottomRow.alignment = .centerY

        let stack = NSStackView(views: [
            statsLabel,
            statsSeparator,
            toggleButton,
            rateSegments,
            accessorySeparator,
            permissionButton,
            updateButton,
            footerSeparator,
            bottomRow,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            root.widthAnchor.constraint(equalToConstant: 210),
            rateSegments.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            permissionButton.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            updateButton.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            bottomRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            statsLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            statsSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            accessorySeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            footerSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
        ])

        let controller = NSViewController()
        controller.view = root
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        refreshPopoverContentSizeIfNeeded()
    }

    private func configureTextRowButton(_ button: NSButton, action: Selector) {
        button.bezelStyle = .recessed
        button.isBordered = false
        button.alignment = .left
        button.target = self
        button.action = action
        button.font = .menuFont(ofSize: 0)
        button.contentTintColor = .labelColor
    }

    private func refreshAccessoryVisibility() {
        statsLabel.isHidden = !state.showStats
        statsSeparator.isHidden = !state.showStats
        permissionButton.isHidden = state.trusted
        updateButton.isHidden = pendingUpdateVersion == nil
        accessorySeparator.isHidden = permissionButton.isHidden && updateButton.isHidden
    }

    private func refreshPopoverContentSizeIfNeeded() {
        guard let root = popover.contentViewController?.view else { return }
        root.layoutSubtreeIfNeeded()
        let size = root.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        popover.contentSize = size
    }

    private func reloadStrings() {
        toggleButton.title = tr("Enable Throttling")
        permissionButton.title = tr("Accessibility Permission Required…")
        settingsButton.toolTip = tr("Settings…")
        quitButton.toolTip = tr("Quit PaceMouse")
        if let version = pendingUpdateVersion {
            updateButton.title = tr("Update Available — v%@…", version)
        }
        let word = NSAttributedString(
            string: tr("Quit"),
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.8),
            ])
        let shortcut = NSAttributedString(
            string: "  ⌘Q",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.45),
            ])
        let title = NSMutableAttributedString(attributedString: word)
        title.append(shortcut)
        quitButton.attributedTitle = title
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let hasUpdate = pendingUpdateVersion != nil
        let emphasized = running || hasUpdate
        if state.menuBarIcon == "logo" {
            button.image = MenuBarLogoImage.template(pointSize: 20, emphasized: emphasized)
        } else {
            button.image = MenuBarMouseImage.template(pointSize: 20, emphasized: emphasized)
        }
        button.alphaValue = emphasized ? 1.0 : 0.4
        button.contentTintColor = hasUpdate ? .systemOrange : nil
        button.toolTip = hasUpdate ? tr("Update Available") : nil
    }

    private func tr(_ key: String, _ args: CVarArg...) -> String {
        L10n.tr(key, language: state.language, args: args)
    }

    private func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    private func openPopover(from button: NSStatusBarButton) {
        onPopoverWillOpen?()
        refreshPopoverContentSizeIfNeeded()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if popover.isShown {
            closePopover()
            return
        }
        guard let button = statusItem.button else { return }
        openPopover(from: button)
    }

    @objc private func toggleClicked() {
        logger.notice("toggle clicked")
        onToggleEnabled?()
    }

    @objc private func rateClicked() {
        let index = rateSegments.selectedSegment
        guard SettingsStore.supportedRates.indices.contains(index) else { return }
        logger.notice("rate clicked: \(SettingsStore.supportedRates[index])")
        onSelectRate?(SettingsStore.supportedRates[index])
    }

    @objc private func permissionClicked() {
        closePopover()
        onRequestPermission?()
    }

    @objc private func updateClicked() {
        closePopover()
        DispatchQueue.main.async { [weak self] in
            self?.onInstallUpdate?()
        }
    }

    @objc private func settingsClicked() {
        closePopover()
        DispatchQueue.main.async { [weak self] in
            self?.onOpenSettings?()
        }
    }

    @objc private func quitClicked() {
        closePopover()
        NSApp.terminate(nil)
    }

    func popoverWillShow(_ notification: Notification) {
        statusItem.button?.highlight(true)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }
}
