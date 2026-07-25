import AppKit

let scale = 2
let logicalWidth = 640
let logicalHeight = 400
let width = logicalWidth * scale
let height = logicalHeight * scale

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("failed to create bitmap\n", stderr)
    exit(1)
}
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("failed to create graphics context\n", stderr)
    exit(1)
}
ctx.imageInterpolation = .high
ctx.shouldAntialias = true
NSGraphicsContext.current = ctx

let s = CGFloat(scale)

NSColor(calibratedRed: 0.20, green: 0.20, blue: 0.21, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

func drawCentered(_ text: String, logicalY: CGFloat, logicalSize: CGFloat, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: logicalSize * s, weight: .medium),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let maxWidth = CGFloat(width) - 80 * s
    let bounding = attributed.boundingRect(
        with: NSSize(width: maxWidth, height: 80 * s),
        options: [.usesLineFragmentOrigin])
    let rect = NSRect(
        x: (CGFloat(width) - bounding.width) / 2,
        y: logicalY * s - bounding.height / 2,
        width: bounding.width,
        height: bounding.height)
    attributed.draw(with: rect, options: [.usesLineFragmentOrigin])
}

drawCentered(
    "安装完成后若无法打开：系统设置 → 隐私与安全性 → 仍要打开",
    logicalY: 310,
    logicalSize: 12,
    color: NSColor(calibratedWhite: 0.78, alpha: 1))
drawCentered(
    "After install, if it won’t open: System Settings → Privacy & Security → Open Anyway",
    logicalY: 288,
    logicalSize: 11,
    color: NSColor(calibratedWhite: 0.62, alpha: 1))

NSColor(calibratedWhite: 0.72, alpha: 1).setStroke()

let midY = 192 * s
let startX = 250 * s
let endX = 390 * s

let shaft = NSBezierPath()
shaft.lineWidth = 2.4 * s
shaft.lineCapStyle = .round
shaft.lineJoinStyle = .round
shaft.move(to: NSPoint(x: startX, y: midY + 3 * s))
shaft.curve(
    to: NSPoint(x: endX - 12 * s, y: midY - 1 * s),
    controlPoint1: NSPoint(x: startX + 40 * s, y: midY + 16 * s),
    controlPoint2: NSPoint(x: endX - 55 * s, y: midY - 18 * s))
shaft.stroke()

let head = NSBezierPath()
head.lineWidth = 2.4 * s
head.lineCapStyle = .round
head.lineJoinStyle = .round
let tip = NSPoint(x: endX, y: midY)
head.move(to: NSPoint(x: tip.x - 14 * s, y: tip.y + 9 * s))
head.line(to: tip)
head.line(to: NSPoint(x: tip.x - 15 * s, y: tip.y - 8 * s))
head.stroke()

NSGraphicsContext.restoreGraphicsState()

let outBase = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Scripts/dmg_assets/background"
let pngPath = outBase.hasSuffix(".png") ? outBase : outBase + ".png"
let tiffPath = (pngPath as NSString).deletingPathExtension + ".tiff"

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode png\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: pngPath))

guard let tiff = rep.representation(
    using: .tiff,
    properties: [.compressionMethod: NSNumber(value: NSBitmapImageRep.TIFFCompression.none.rawValue)]
) else {
    fputs("failed to encode tiff\n", stderr)
    exit(1)
}
try tiff.write(to: URL(fileURLWithPath: tiffPath))

for path in [pngPath, tiffPath] {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    proc.arguments = ["-s", "dpiWidth", "144", "-s", "dpiHeight", "144", path]
    proc.standardOutput = FileHandle.nullDevice
    proc.standardError = FileHandle.nullDevice
    try proc.run()
    proc.waitUntilExit()
    if proc.terminationStatus != 0 {
        fputs("sips failed for \(path) (status \(proc.terminationStatus))\n", stderr)
        exit(1)
    }
}

print("Wrote \(pngPath) and \(tiffPath) (\(width)x\(height) @\(scale)x, 144 dpi)")
