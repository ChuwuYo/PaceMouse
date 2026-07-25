import AppKit

final class MenuBarIconChoiceButton: NSButton {
    private static let side: CGFloat = 36

    var styleID = ""
    var isChosen = false {
        didSet { refreshChrome() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = MenuBarIconChoiceCell()
        isBordered = false
        wantsLayer = true
        layer?.masksToBounds = true
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        focusRingType = .none
        setButtonType(.momentaryChange)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
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

    private func refreshChrome() {
        layer?.borderWidth = 2
        layer?.borderColor = (isChosen ? NSColor.controlAccentColor : .clear).cgColor
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(isChosen ? 0.08 : 0.04).cgColor
        contentTintColor = .labelColor
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshChrome()
    }
}

private final class MenuBarIconChoiceCell: NSButtonCell {
    override func imageRect(forBounds rect: NSRect) -> NSRect {
        rect.insetBy(dx: 8, dy: 8)
    }
}
