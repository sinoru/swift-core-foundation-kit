//
//  CollectionBenchmarks.swift
//  CoreFoundationKitBenchmarks
//

import Benchmark
import CoreFoundation
import CoreFoundationKit
import Foundation

/// How many elements the collections hold. Sixteen is about what one level of a property list or
/// a keychain item's attributes has; the small ones are where what a collection costs to create
/// is not yet spread over many elements, and none at all is that cost alone.
private let elementCounts = [0, 1, 4, 16]

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

/// Takes an element as far as an object and no further.
///
/// The address is folded into a sum that is handed to the harness once the walk is over. Handing
/// each element over as it is read would measure the harness instead: what it is given is looked
/// up by its dynamic type, which for an object costs more than reading it out of the collection.
@inline(__always)
private func take(_ element: AnyObject, into sum: inout Int) {
    sum &+= Int(bitPattern: ObjectIdentifier(element))
}

/// Registers the benchmarks that walk one array: through `ArrayElements`, and the two ways a
/// reader walks an `NSArray` without it.
private func registerArrayBenchmarks(named name: String, makeArray: @escaping () -> CFArray) {
    Benchmark("Walk \(name)") { benchmark, array in
        for _ in benchmark.scaledIterations {
            var sum = 0

            for element in CoreFoundationValue.ArrayElements(array) {
                take(element, into: &sum)
            }

            blackHole(sum)
        }
    } setup: {
        makeArray()
    }

    Benchmark("Walk \(name) by fast enumeration") { benchmark, array in
        for _ in benchmark.scaledIterations {
            var sum = 0

            for element in array as NSArray {
                take(element as AnyObject, into: &sum)
            }

            blackHole(sum)
        }
    } setup: {
        makeArray()
    }

    Benchmark("Walk \(name) by index") { benchmark, array in
        for _ in benchmark.scaledIterations {
            let array = array as NSArray
            var sum = 0

            for index in 0..<array.count {
                take(array.object(at: index) as AnyObject, into: &sum)
            }

            blackHole(sum)
        }
    } setup: {
        makeArray()
    }
}

/// Registers the benchmarks that walk one dictionary: through `DictionaryElements`, and by the
/// block enumeration a reader writes without it.
private func registerDictionaryBenchmarks(
    named name: String,
    makeDictionary: @escaping () -> CFDictionary,
) {
    Benchmark("Walk \(name)") { benchmark, dictionary in
        for _ in benchmark.scaledIterations {
            var sum = 0

            for (key, value) in CoreFoundationValue.DictionaryElements(dictionary) {
                take(key, into: &sum)
                take(value, into: &sum)
            }

            blackHole(sum)
        }
    } setup: {
        makeDictionary()
    }

    Benchmark("Walk \(name) by block enumeration") { benchmark, dictionary in
        for _ in benchmark.scaledIterations {
            var sum = 0

            unsafe (dictionary as NSDictionary).enumerateKeysAndObjects { key, value, _ in
                take(key as AnyObject, into: &sum)
                take(value as AnyObject, into: &sum)
            }

            blackHole(sum)
        }
    } setup: {
        makeDictionary()
    }
}

/// What walking a collection costs, next to what a reader writes without these types.
///
/// Each element is taken as an object and no further, since what it is told apart as is measured
/// on its own. A collection CoreFoundation owns and one bridged from Swift are measured apart:
/// CoreFoundation reads the first directly and sends the second a message for everything it is
/// asked, so neither number stands in for the other.
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
