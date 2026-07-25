import Cocoa

let hz: Double = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 1000 : 1000
let seconds: Double = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 5 : 5
let mode = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "circle"
let interval = 1.0 / hz
let center = NSEvent.mouseLocation
let screenH = NSScreen.main?.frame.height ?? 1000
var sent = 0
let start = CACurrentMediaTime()
var lastX = center.x, lastY = center.y
var remX = 0.0, remY = 0.0

while CACurrentMediaTime() - start < seconds {
    let t = CACurrentMediaTime() - start
    let x: Double
    let y: Double
    if mode == "line" {
        x = center.x + t * 600
        y = center.y
    } else {
        x = center.x + 100 * cos(t * 2 * .pi)
        y = center.y + 100 * sin(t * 2 * .pi)
    }
    if let ev = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: screenH - y), mouseButton: .left) {
        let rawDx = (x - lastX) + remX
        let rawDy = (lastY - y) + remY
        let dx = Double(Int64(rawDx))
        let dy = Double(Int64(rawDy))
        remX = rawDx - dx
        remY = rawDy - dy
        ev.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
        ev.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy))
        ev.post(tap: .cghidEventTap)
        sent += 1
    }
    lastX = x; lastY = y
    let next = start + Double(sent) * interval
    let sleep = next - CACurrentMediaTime()
    if sleep > 0 { Thread.sleep(forTimeInterval: sleep) }
}
print("generator sent \(sent) events (\(Double(sent)/seconds) Hz)")
