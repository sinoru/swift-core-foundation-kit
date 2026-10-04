//
//  NumberBenchmarks.swift
//  CoreFoundationKitBenchmarks
//

import Benchmark
import CoreFoundation
import CoreFoundationKit
import Foundation

/// What a reader without `CoreFoundationValue.Number` writes instead: the question about the
/// type, then the two casts that check exactness. It answers the same as the initializer does,
/// and as the same type, so the difference between them is only how the answer is come by.
private func readByCasts(_ number: CFNumber) -> CoreFoundationValue.Number? {
    if CFNumberIsFloatType(number) {
        .floatingPoint((number as NSNumber).doubleValue)
    } else if let value = (number as NSNumber) as? Int64 {
        .integer(value)
    } else if let value = (number as NSNumber) as? UInt64 {
        .unsignedInteger(value)
    } else {
        nil
    }
}

/// Registers the pair of benchmarks that read one number, by the initializer and by the casts.
///
/// Each tells the object apart first and reads the number it is handed, which is how a reader
/// comes by one.
private func registerNumberBenchmarks(named name: String, makeNumber: @escaping () -> NSNumber) {
    Benchmark("Read \(name)") { benchmark, object in
        for _ in benchmark.scaledIterations {
            if case .number(let number) = CoreFoundationValue(unchecked: object) {
                blackHole(CoreFoundationValue.Number(exactly: number))
            }
        }
    } setup: {
        makeNumber() as AnyObject
    }

    Benchmark("Read \(name) by casts") { benchmark, object in
        for _ in benchmark.scaledIterations {
            if case .number(let number) = CoreFoundationValue(unchecked: object) {
                blackHole(readByCasts(number))
            }
        }
    } setup: {
        makeNumber() as AnyObject
    }
}

/// What reading the value of a number costs, next to the casts it replaces.
///
/// Each kind of number is measured alone because each takes a different path. An integer that is
/// not negative is read from CoreFoundation and never bridged, which is the path most numbers
/// take; a negative one, and an unsigned one above `Int64.max`, read alike and are settled by
/// what the number says it holds; a floating-point one is settled by the first question. A
/// number too large for a tagged pointer is measured beside a small one, since CoreFoundation
/// reads the two differently.
func registerNumberBenchmarks() {
    registerNumberBenchmarks(named: "a small integer") { NSNumber(value: 2048) }
    registerNumberBenchmarks(named: "a large integer") { NSNumber(value: Int64.max) }
    registerNumberBenchmarks(named: "a negative integer") { NSNumber(value: -2048) }
    registerNumberBenchmarks(named: "an unsigned integer above Int64") {
        NSNumber(value: UInt64.max)
    }
    registerNumberBenchmarks(named: "a floating-point number") { NSNumber(value: 1.5) }

    // A number the caller has only on loan, read without being told apart first. The initializer
    // borrows its argument so that this costs what the casts cost; were it to own the argument,
    // as an initializer does unless it says otherwise, the retain to hand the number over and
    // the release after would show here and nowhere above.
    Benchmark("Read a borrowed floating-point number") { benchmark, number in
        for _ in benchmark.scaledIterations {
            blackHole(CoreFoundationValue.Number(exactly: number))
        }
    } setup: {
        NSNumber(value: 1.5) as CFNumber
    }

    Benchmark("Read a borrowed floating-point number by casts") { benchmark, number in
        for _ in benchmark.scaledIterations {
            blackHole(readByCasts(number))
        }
    } setup: {
        NSNumber(value: 1.5) as CFNumber
    }
}
