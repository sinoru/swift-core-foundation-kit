//
//  CollectionBenchmarks.swift
//  CoreFoundationKitBenchmarks
//
//  Copyright (c) 2026 Kang Jaehong
//  SPDX-License-Identifier: Apache-2.0
//

import Benchmark
import CoreFoundation
import CoreFoundationKit
import Foundation

/// How many elements the collections hold. Sixteen is about what one level of a property list or
/// a keychain item's attributes has; the small ones are where what a collection costs to create
/// is not yet spread over many elements, and none at all is that cost alone. Sixty-four is a
/// collection too large for anything a walk keeps room for in itself.
private let elementCounts = [0, 1, 4, 16, 64]

/// An array CoreFoundation owns, as a framework hands one back.
private func makeArray(count: Int) -> CFArray {
    NSArray(array: (0..<count).map { NSString(string: "element \($0)") })
}

/// An array a caller built in Swift, which crosses into an object of Swift's own class and
/// answers CoreFoundation through messages.
private func makeBridgedArray(count: Int) -> CFArray {
    (0..<count).map { "element \($0)" as Any } as CFArray
}

/// A dictionary CoreFoundation owns, as a framework hands one back.
private func makeDictionary(count: Int) -> CFDictionary {
    let dictionary = NSMutableDictionary()

    for index in 0..<count {
        dictionary[NSString(string: "key \(index)")] = NSNumber(value: index)
    }

    return NSDictionary(dictionary: dictionary)
}

/// A dictionary a caller built in Swift.
private func makeBridgedDictionary(count: Int) -> CFDictionary {
    var dictionary = [String: Any]()

    for index in 0..<count {
        dictionary["key \(index)"] = index
    }

    return dictionary as CFDictionary
}

/// Takes an element as far as knowing which case it is.
///
/// A number for the case is folded into a sum that is handed to the harness once the walk is
/// over. Handing each element over as it is read would measure the harness instead: what it is
/// given is looked up by its dynamic type, which costs more than reading the element did.
@inline(__always)
private func take(_ element: CoreFoundationValue, into sum: inout Int) {
    switch element {
    case .string: sum &+= 1
    case .boolean: sum &+= 2
    case .number: sum &+= 3
    case .data: sum &+= 4
    case .date: sum &+= 5
    case .array: sum &+= 6
    case .dictionary: sum &+= 7
    case .other: sum &+= 8
    }
}

/// Registers the benchmarks that walk one array: through its view, and the two ways a reader
/// walks an `NSArray` and tells each element apart without it.
private func registerArrayBenchmarks(named name: String, makeArray: @escaping () -> CFArray) {
    Benchmark("Walk \(name)") { benchmark, array in
        for _ in benchmark.scaledIterations {
            var sum = 0

            if case .array(let elements) = CoreFoundationValue(unchecked: array) {
                for element in elements {
                    take(element, into: &sum)
                }
            }

            blackHole(sum)
        }
    } setup: {
        makeArray()
    }

    Benchmark("Walk \(name) of unknown origin") { benchmark, array in
        for _ in benchmark.scaledIterations {
            var sum = 0

            if case .array(let elements)? = CoreFoundationValue(array) {
                for element in elements {
                    take(element, into: &sum)
                }
            }

            blackHole(sum)
        }
    } setup: {
        makeArray()
    }

    Benchmark("Walk \(name) by fast enumeration") { benchmark, array in
        for _ in benchmark.scaledIterations {
            var sum = 0

            if case .array(let elements) = CoreFoundationValue(unchecked: array) {
                for element in elements.base as NSArray {
                    take(CoreFoundationValue(unchecked: element as AnyObject), into: &sum)
                }
            }

            blackHole(sum)
        }
    } setup: {
        makeArray()
    }

    Benchmark("Walk \(name) by index") { benchmark, array in
        for _ in benchmark.scaledIterations {
            var sum = 0

            if case .array(let elements) = CoreFoundationValue(unchecked: array) {
                let array = elements.base as NSArray

                for index in 0..<array.count {
                    take(
                        CoreFoundationValue(unchecked: array.object(at: index) as AnyObject),
                        into: &sum
                    )
                }
            }

            blackHole(sum)
        }
    } setup: {
        makeArray()
    }
}

/// Registers the benchmarks that walk one dictionary: through its view, and by the block
/// enumeration a reader writes without it.
private func registerDictionaryBenchmarks(
    named name: String,
    makeDictionary: @escaping () -> CFDictionary,
) {
    Benchmark("Walk \(name)") { benchmark, dictionary in
        for _ in benchmark.scaledIterations {
            var sum = 0

            if case .dictionary(let elements) = CoreFoundationValue(unchecked: dictionary) {
                for (key, value) in elements {
                    take(key, into: &sum)
                    take(value, into: &sum)
                }
            }

            blackHole(sum)
        }
    } setup: {
        makeDictionary()
    }

    Benchmark("Walk \(name) of unknown origin") { benchmark, dictionary in
        for _ in benchmark.scaledIterations {
            var sum = 0

            if case .dictionary(let elements)? = CoreFoundationValue(dictionary) {
                for (key, value) in elements {
                    take(key, into: &sum)
                    take(value, into: &sum)
                }
            }

            blackHole(sum)
        }
    } setup: {
        makeDictionary()
    }

    Benchmark("Walk \(name) by block enumeration") { benchmark, dictionary in
        for _ in benchmark.scaledIterations {
            var sum = 0

            if case .dictionary(let elements) = CoreFoundationValue(unchecked: dictionary) {
                unsafe (elements.base as NSDictionary).enumerateKeysAndObjects { key, value, _ in
                    take(CoreFoundationValue(unchecked: key as AnyObject), into: &sum)
                    take(CoreFoundationValue(unchecked: value as AnyObject), into: &sum)
                }
            }

            blackHole(sum)
        }
    } setup: {
        makeDictionary()
    }
}

/// What walking a collection costs, next to what a reader writes without its view.
///
/// Each walk starts from the collection as an object, tells it apart, and tells every element
/// apart, since that is what a view hands over; the walks it is measured against do the same by
/// hand, over the object the view is of. A collection
/// CoreFoundation owns and one bridged from Swift are measured apart: CoreFoundation reads the
/// first directly and sends the second a message for everything it is asked, so neither number
/// stands in for the other. A collection of unknown origin is measured beside each, for what
/// asking every element's class about `_cfTypeID` adds.
func registerCollectionBenchmarks() {
    for count in elementCounts {
        registerArrayBenchmarks(named: "an array of \(count)") { makeArray(count: count) }
        registerArrayBenchmarks(named: "a bridged array of \(count)") {
            makeBridgedArray(count: count)
        }
        registerDictionaryBenchmarks(named: "a dictionary of \(count)") {
            makeDictionary(count: count)
        }
        registerDictionaryBenchmarks(named: "a bridged dictionary of \(count)") {
            makeBridgedDictionary(count: count)
        }
    }
}
