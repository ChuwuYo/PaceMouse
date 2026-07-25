import AppKit

enum MenuBarLogoImage {
    static func template(pointSize: CGFloat, emphasized: Bool) -> NSImage {
        let pixels = max(16, Int((pointSize * 2).rounded()))
        let size = CGFloat(pixels)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let wave = NSBezierPath()
        wave.lineWidth = size * (emphasized ? 0.15 : 0.08)
        wave.lineCapStyle = .round
        wave.lineJoinStyle = .round
        var first = true
        for step in 0...240 {
            let t = Double(step) / 240.0
            let x = size * (0.10 + t * 0.80)
            let phase = 4.0 * t - 1.8 * t * t
            let y = size * (0.5 + sin(phase * .pi * 2) * 0.24)
            let point = NSPoint(x: x, y: y)
            if first {
                wave.move(to: point)
                first = false
            } else {
                wave.line(to: point)
            }
        }
        NSColor.black.setStroke()
        wave.stroke()

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}
