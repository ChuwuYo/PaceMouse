import Cocoa

if let ev = CGEvent(source: nil) {
    let p = ev.location
    print("\(Int(p.x)),\(Int(p.y))")
}
