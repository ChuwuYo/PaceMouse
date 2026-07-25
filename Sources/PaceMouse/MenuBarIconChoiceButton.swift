import AppKit

final class MenuBarIconChoiceButton: NSButton {
    var styleID = ""
    var isChosen = false {
        didSet { refreshChrome() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        wantsLayer = true
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        focusRingType = .none
        setButtonType(.momentaryChange)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 36),
            heightAnchor.constraint(equalToConstant: 36),
        ])
        refreshChrome()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 36, height: 36)
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
