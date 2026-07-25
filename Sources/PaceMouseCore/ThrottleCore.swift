import Foundation

public struct MouseDelta: AdditiveArithmetic, Sendable, Equatable {
    public var dx: Int64
    public var dy: Int64

    public init(dx: Int64, dy: Int64) {
        self.dx = dx
        self.dy = dy
    }

    public static var zero: MouseDelta { MouseDelta(dx: 0, dy: 0) }

    public static func + (lhs: MouseDelta, rhs: MouseDelta) -> MouseDelta {
        MouseDelta(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    public static func - (lhs: MouseDelta, rhs: MouseDelta) -> MouseDelta {
        MouseDelta(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }
}

public final class ThrottleCore: @unchecked Sendable {
    private let lock = NSLock()
    private var accumulated = MouseDelta.zero
    private var hasPending = false
    private var ingestCount = 0
    private var emitCount = 0

    public init() {}

    public func store(_ delta: MouseDelta) {
        lock.lock()
        accumulated = accumulated + delta
        hasPending = true
        ingestCount += 1
        lock.unlock()
    }

    public func noteIngest() {
        lock.lock()
        ingestCount += 1
        lock.unlock()
    }

    public func drain() -> MouseDelta? {
        lock.lock()
        defer { lock.unlock() }
        guard hasPending else { return nil }
        let delta = accumulated
        accumulated = .zero
        hasPending = false
        emitCount += 1
        return delta
    }

    public func reset() {
        lock.lock()
        accumulated = .zero
        hasPending = false
        lock.unlock()
    }

    public func resetStats() -> (ingest: Int, emit: Int) {
        lock.lock()
        defer { lock.unlock() }
        let result = (ingestCount, emitCount)
        ingestCount = 0
        emitCount = 0
        return result
    }
}
