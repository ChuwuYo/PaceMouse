import AppKit

setbuf(stdout, nil)

let outDir = "IconCandidates"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let size: CGFloat = 1024
let canvas = CGRect(x: 0, y: 0, width: size, height: size)

func squirclePath() -> NSBezierPath {
    NSBezierPath(roundedRect: canvas, xRadius: size * 0.2237, yRadius: size * 0.2237)
}

func background(_ colors: [NSColor]) {
    let gradient = NSGradient(colors: colors)!
    gradient.draw(in: squirclePath(), angle: -90)
}

func withGraphics(_ block: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    block()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print("wrote \(outDir)/\(name).png")
}

func mouseGlyph(center: CGPoint, scale: CGFloat, color: NSColor) {
    color.setFill()
    let w = 240 * scale, h = 400 * scale
    let body = NSBezierPath(roundedRect: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h), xRadius: w / 2, yRadius: w / 2)
    body.fill()
    squirclePath().setClip()
    let wheel = NSBezierPath(roundedRect: CGRect(x: center.x - 18 * scale, y: center.y + 60 * scale, width: 36 * scale, height: 100 * scale), xRadius: 18 * scale, yRadius: 18 * scale)
    NSColor(white: 0, alpha: 0.25).setFill()
    wheel.fill()
}

func shadowedGlyph(_ block: () -> Void) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.3)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    block()
    NSGraphicsContext.current?.cgContext.restoreGState()
    NSGraphicsContext.current?.cgContext.saveGState()
}

let white = NSColor.white

let repA = withGraphics {
    background([NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1), NSColor(srgbRed: 0.35, green: 0.34, blue: 0.9, alpha: 1)])
    squirclePath().addClip()
    white.setStroke()
    for (i, length) in [220.0, 150.0, 80.0].enumerated() {
        let y = 620.0 - Double(i) * 110.0
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 660 + (220 - length), y: y))
        line.line(to: NSPoint(x: 880, y: y))
        line.lineWidth = 42
        line.lineCapStyle = .round
        line.stroke()
    }
    mouseGlyph(center: NSPoint(x: 420, y: 480), scale: 1.0, color: white)
}
save(repA, "iconA")

let repB = withGraphics {
    background([NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1), NSColor(srgbRed: 0.2, green: 0.2, blue: 0.22, alpha: 1)])
    squirclePath().addClip()
    let accent = NSColor(srgbRed: 0.39, green: 0.82, blue: 1.0, alpha: 1)
    accent.setFill()
    let funnel = NSBezierPath()
    funnel.move(to: NSPoint(x: 272, y: 680))
    funnel.line(to: NSPoint(x: 752, y: 680))
    funnel.line(to: NSPoint(x: 592, y: 480))
    funnel.line(to: NSPoint(x: 592, y: 380))
    funnel.line(to: NSPoint(x: 432, y: 380))
    funnel.line(to: NSPoint(x: 432, y: 480))
    funnel.close()
    funnel.fill()
    let drop = NSBezierPath(ovalIn: CGRect(x: 482, y: 210, width: 60, height: 60))
    drop.fill()
    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: 512, y: 380))
    stem.line(to: NSPoint(x: 512, y: 290))
    stem.lineWidth = 36
    stem.lineCapStyle = .round
    accent.setStroke()
    stem.stroke()
}
save(repB, "iconB")

let repC = withGraphics {
    background([NSColor(srgbRed: 0.2, green: 0.78, blue: 0.75, alpha: 1), NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1)])
    squirclePath().addClip()
    white.setStroke()
    let wave = NSBezierPath()
    wave.lineWidth = 44
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    var first = true
    for step in 0...400 {
        let t = Double(step) / 400.0
        let x = 172.0 + t * 680.0
        let phase = 4.0 * t - 1.8 * t * t
        let y = 512.0 + sin(phase * .pi * 2) * 140.0
        if first { wave.move(to: NSPoint(x: x, y: y)); first = false } else { wave.line(to: NSPoint(x: x, y: y)) }
    }
    wave.stroke()
}
save(repC, "iconC")

let repD = withGraphics {
    background([NSColor(srgbRed: 0.75, green: 0.35, blue: 0.95, alpha: 1), NSColor(srgbRed: 0.35, green: 0.34, blue: 0.9, alpha: 1)])
    squirclePath().addClip()
    white.setFill()
    let pointer = NSBezierPath()
    pointer.move(to: NSPoint(x: 400, y: 760))
    pointer.line(to: NSPoint(x: 400, y: 280))
    pointer.line(to: NSPoint(x: 500, y: 400))
    pointer.line(to: NSPoint(x: 580, y: 380))
    pointer.line(to: NSPoint(x: 660, y: 600))
    pointer.close()
    pointer.fill()
    white.setStroke()
    for radius in [90.0, 150.0] {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: NSPoint(x: 660, y: 700), radius: radius, startAngle: 20, endAngle: 110)
        arc.lineWidth = 34
        arc.lineCapStyle = .round
        arc.stroke()
    }
}
save(repD, "iconD")
