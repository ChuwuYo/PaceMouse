import Testing
@testable import PaceMouseCore

@Test func deltasAccumulate() {
    let core = ThrottleCore()
    core.store(MouseDelta(dx: 10, dy: 1))
    core.store(MouseDelta(dx: 20, dy: 2))
    core.store(MouseDelta(dx: 30, dy: 3))
    #expect(core.drain() == MouseDelta(dx: 60, dy: 6))
}

@Test func drainClearsPending() {
    let core = ThrottleCore()
    #expect(core.drain() == nil)
    core.store(MouseDelta(dx: 7, dy: 7))
    #expect(core.drain() == MouseDelta(dx: 7, dy: 7))
    #expect(core.drain() == nil)
}

@Test func resetDiscardsPending() {
    let core = ThrottleCore()
    core.store(MouseDelta(dx: 5, dy: 5))
    core.reset()
    #expect(core.drain() == nil)
    core.store(MouseDelta(dx: 3, dy: 3))
    #expect(core.drain() == MouseDelta(dx: 3, dy: 3))
}

@Test func statsCountIngestAndEmit() {
    let core = ThrottleCore()
    core.store(MouseDelta(dx: 1, dy: 0))
    core.noteIngest()
    core.store(MouseDelta(dx: 1, dy: 0))
    _ = core.drain()
    let stats = core.resetStats()
    #expect(stats.ingest == 3)
    #expect(stats.emit == 1)
    let cleared = core.resetStats()
    #expect(cleared.ingest == 0)
    #expect(cleared.emit == 0)
}

@Test func mouseDeltaArithmetic() {
    let a = MouseDelta(dx: 3, dy: -2)
    let b = MouseDelta(dx: 1, dy: 5)
    #expect(a + b == MouseDelta(dx: 4, dy: 3))
    #expect(a - b == MouseDelta(dx: 2, dy: -7))
    #expect(MouseDelta.zero + a == a)
}
