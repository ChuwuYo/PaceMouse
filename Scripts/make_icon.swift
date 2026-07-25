import AppKit

setbuf(stdout, nil)

func render(size: CGFloat) -> NSBitmapImageRep {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let squircle = NSBezierPath(roundedRect: canvas, xRadius: size * 0.2237, yRadius: size * 0.2237)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.2, green: 0.78, blue: 0.75, alpha: 1),
        NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1),
    ])!
    gradient.draw(in: squircle, angle: -90)
    squircle.addClip()

    NSColor.white.setStroke()
    let wave = NSBezierPath()
    wave.lineWidth = size * 0.043
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    var first = true
    for step in 0...400 {
        let t = Double(step) / 400.0
        let x = size * (0.168 + t * 0.664)
        let phase = 4.0 * t - 1.8 * t * t
        let y = size * (0.5 + sin(phase * .pi * 2) * 0.137)
        if first { wave.move(to: NSPoint(x: x, y: y)); first = false } else { wave.line(to: NSPoint(x: x, y: y)) }
    }
    wave.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDir = "Icon.iconset"
try? FileManager.default.removeItem(atPath: outDir)
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in specs {
    let data = render(size: pixels).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("iconset written")
