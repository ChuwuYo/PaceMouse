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
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)
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
final class StatusItemController: NSObject {
    var onToggleEnabled: (() -> Void)?
    var onSelectRate: ((Double) -> Void)?
    var onRequestPermission: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let statsItem = NSMenuItem()
    private let toggleButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let rateSegments = NSSegmentedControl()
    private let permissionItem = NSMenuItem()
    private let settingsButton = CapsuleButton()
    private let quitButton = CapsuleButton()
    private var state = MenuState(enabled: false, rate: 250, trusted: false, showStats: true, language: "system")
    private var running = false

    override init() {
        super.init()
        updateIcon()

        statsItem.isEnabled = false
        menu.addItem(statsItem)
        menu.addItem(.separator())

        toggleButton.target = self
        toggleButton.action = #selector(toggleClicked)
        let toggleItem = NSMenuItem()
        toggleItem.view = StatusItemController.rowView(with: toggleButton)
        menu.addItem(toggleItem)

        rateSegments.segmentCount = SettingsStore.supportedRates.count
        rateSegments.trackingMode = .selectOne
        for (index, value) in SettingsStore.supportedRates.enumerated() {
            rateSegments.setLabel("\(Int(value))", forSegment: index)
        }
        rateSegments.target = self
        rateSegments.action = #selector(rateClicked)
        let rateItem = NSMenuItem()
        rateItem.view = StatusItemController.rowView(with: rateSegments)
        menu.addItem(rateItem)

        menu.addItem(.separator())
        permissionItem.action = #selector(permissionClicked)
        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())

        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.imagePosition = .imageOnly
        settingsButton.contentTintColor = NSColor.labelColor.withAlphaComponent(0.8)
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)
        quitButton.imagePosition = .noImage
        quitButton.target = self
        quitButton.action = #selector(quitClicked)
        settingsButton.image?.isTemplate = true
        for (button, width) in [(settingsButton, 30.0), (quitButton, 0.0)] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
            if width > 0 {
                button.widthAnchor.constraint(equalToConstant: width).isActive = true
            } else {
                button.horizontalPadding = 12
            }
        }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let bottomRow = NSStackView(views: [spacer, settingsButton, quitButton])
        bottomRow.spacing = 10
        let bottomItem = NSMenuItem()
        bottomItem.view = StatusItemController.rowView(with: bottomRow)
        menu.addItem(bottomItem)

        statusItem.menu = menu
    }

    func update(state: MenuState) {
        logger.notice("update ui: enabled=\(state.enabled) rate=\(state.rate) trusted=\(state.trusted)")
        self.state = state
        running = state.enabled && state.trusted
        toggleButton.state = state.enabled ? .on : .off
        if let index = SettingsStore.supportedRates.firstIndex(of: state.rate) {
            rateSegments.selectedSegment = index
        }
        permissionItem.isHidden = state.trusted
        statsItem.isHidden = !state.showStats
        reloadStrings()
        updateIcon()
        if !running {
            statsItem.title = state.trusted ? tr("Stopped") : tr("Waiting for Accessibility Permission")
        }
    }

    func updateStats(ingest: Int, emit: Int, bypass: Bool) {
        guard running else { return }
        if bypass {
            statsItem.title = ingest == 0 ? tr("Smart Standby") : tr("In %lld Hz · Bypass", Int64(ingest))
        } else {
            statsItem.title = tr("In %lld Hz → Out %lld Hz", Int64(ingest), Int64(emit))
        }
    }

    private func reloadStrings() {
        toggleButton.title = tr("Enable Throttling")
        permissionItem.title = tr("Accessibility Permission Required…")
        settingsButton.toolTip = tr("Settings…")
        quitButton.toolTip = tr("Quit PaceMouse")
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
        let symbol = running ? "computermouse.fill" : "computermouse"
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "PaceMouse")?.withSymbolConfiguration(config)
        button.image?.isTemplate = true
        button.alphaValue = running ? 1.0 : 0.5
    }

    private func tr(_ key: String, _ args: CVarArg...) -> String {
        L10n.tr(key, language: state.language, args: args)
    }

    private static func rowView(with content: NSView) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(content)
        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: 210),
            content.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            content.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            content.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),
        ])
        return row
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

    @objc private func permissionClicked() { onRequestPermission?() }

    @objc private func settingsClicked() { onOpenSettings?() }

    @objc private func quitClicked() { NSApp.terminate(nil) }
}
