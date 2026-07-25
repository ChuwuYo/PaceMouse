import AppKit

final class MenuBarIconChoiceButton: NSControl {
    private static let side: CGFloat = 36
    private static let iconInset: CGFloat = 8

    private let iconView = NSImageView()

    var styleID = ""
    var isChosen = false {
        didSet { refreshChrome() }
    }

    var image: NSImage? {
        get { iconView.image }
        set {
            iconView.image = newValue
            iconView.contentTintColor = .labelColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false

        iconView.imageScaling = .scaleProportionallyDown
        iconView.imageAlignment = .alignCenter
        iconView.contentTintColor = .labelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.iconInset),
            iconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.iconInset),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: Self.iconInset),
            iconView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.iconInset),
        ])
        refreshChrome()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.side, height: Self.side)
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = 8
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
    }

    override func mouseUp(with event: NSEvent) {
        refreshChrome()
        guard isEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            sendAction(action, to: target)
        }
    }

    private func refreshChrome() {
        layer?.borderWidth = 2
        layer?.borderColor = (isChosen ? NSColor.controlAccentColor : .clear).cgColor
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(isChosen ? 0.08 : 0.04).cgColor
        iconView.contentTintColor = .labelColor
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshChrome()
    }
}
