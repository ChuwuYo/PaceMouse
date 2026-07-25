import Cocoa

setbuf(stdout, nil)
for (i, screen) in NSScreen.screens.enumerated() {
    print("screen\(i): \(screen.frame)")
}
if CommandLine.arguments.count > 2, let x = Double(CommandLine.arguments[1]), let y = Double(CommandLine.arguments[2]) {
    CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
    Thread.sleep(forTimeInterval: 0.1)
    if let ev = CGEvent(source: nil) {
        print("warped to: \(ev.location)")
    }
}
