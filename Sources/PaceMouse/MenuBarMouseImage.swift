import AppKit

enum MenuBarMouseImage {
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

        let body = mouseBody(in: size)
        let wheel = mouseWheel(in: size)

        if emphasized {
            let filled = NSBezierPath()
            filled.append(body)
            filled.append(wheel)
            filled.windingRule = .evenOdd
            NSColor.black.setFill()
            filled.fill()
        } else {
            let stroke = size * 0.08
            body.lineWidth = stroke
            body.lineJoinStyle = .round
            body.lineCapStyle = .round
            NSColor.black.setStroke()
            body.stroke()
            NSColor.black.setFill()
            wheel.fill()
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }

    private static func mouseBody(in size: CGFloat) -> NSBezierPath {
        let width = size * 0.54
        let height = size * 0.80
        let rect = NSRect(
            x: (size - width) * 0.5,
            y: (size - height) * 0.5,
            width: width,
            height: height
        )
        return NSBezierPath(roundedRect: rect, xRadius: width * 0.5, yRadius: width * 0.5)
    }

    private static func mouseWheel(in size: CGFloat) -> NSBezierPath {
        NSBezierPath(
            roundedRect: NSRect(
                x: size * 0.455,
                y: size * 0.58,
                width: size * 0.09,
                height: size * 0.16
            ),
            xRadius: size * 0.045,
            yRadius: size * 0.045
        )
    }
}
