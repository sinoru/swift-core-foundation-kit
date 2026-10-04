//
//  Benchmarks.swift
//  CoreFoundationKitBenchmarks
//

import Benchmark

/// What the harness runs: every benchmark in this target, registered in the order it is reported.
///
/// Instructions retired is the number to read. Telling one object apart is a few nanoseconds, so
/// the clock varies by more between runs than the differences being measured, and the wall clock
/// is reported only so that a number that moved can be seen to have moved the time with it.
/// Allocations and retain/release traffic are counted because telling an object apart should
/// cause none of the first and little of the second, and a change that adds either shows there.
///
/// Nothing here fails on a regression, and no threshold is checked in: a number means something
/// next to the number beside it, or next to a baseline taken on the same machine, not next to one
/// from another machine.
let benchmarks: @Sendable () -> Void = {
    // The harness keeps its defaults in a `nonisolated(unsafe)` static. It calls this closure once,
    // before any benchmark runs, so nothing else is reading it while it is written.
    unsafe Benchmark.defaultConfiguration = .init(
        metrics: [
            .instructions,
            .mallocCountTotal,
            .retainCount,
            .releaseCount,
            .wallClock,
        ],
        scalingFactor: .kilo
    )

    registerClassificationBenchmarks()
}
