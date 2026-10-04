//
//  ClassificationBenchmarks.swift
//  CoreFoundationKitBenchmarks
//

import Benchmark
import CoreFoundationKit
import Foundation

/// The objects a property list or a keychain item is made of, in roughly the proportions one
/// holds them: mostly strings and numbers, a few of everything else, and two that are none of the
/// types told apart.
private func makeObjects() -> [AnyObject] {
    [
        NSString(string: "com.example.service"),
        NSString(string: "a"),
        NSString(string: String(repeating: "core foundation ", count: 8)),
        NSNumber(value: 2048),
        NSNumber(value: 1.5),
        NSNumber(value: UInt64.max),
        kCFBooleanTrue,
        kCFBooleanFalse,
        NSData(data: Data([1, 2, 3])),
        NSDate(timeIntervalSinceReferenceDate: 0),
        NSArray(array: [1, 2]),
        NSDictionary(dictionary: ["key": 1]),
        NSNull(),
        NSObject(),
    ]
}

/// What a reader without the type ID writes instead: one conditional cast after another, until one
/// succeeds. It is here for what it costs, not for what it answers — it takes a number for a
/// boolean, which is the reason not to write it.
private func castLadder(_ object: AnyObject) {
    switch object {
    case let value as String:
        blackHole(value)
    case let value as Bool:
        blackHole(value)
    case let value as Int64:
        blackHole(value)
    case let value as Double:
        blackHole(value)
    case let value as Data:
        blackHole(value)
    case let value as Date:
        blackHole(value)
    case let value as [Any]:
        blackHole(value)
    case let value as [String: Any]:
        blackHole(value)
    default:
        blackHole(object)
    }
}

private func registerLeaf(_ name: String, _ makeObject: @escaping () -> AnyObject) {
    Benchmark("Tell apart \(name)") { benchmark, object in
        for _ in benchmark.scaledIterations {
            blackHole(CoreFoundationValue(object))
        }
    } setup: {
        makeObject()
    }
}

/// What telling an object apart costs, and what it costs next to the alternatives.
///
/// This target is a module of its own, so what is measured is what a package depending on this
/// one gets: the initializers inlined across the module boundary, not called through it. Two of
/// the choices in `CoreFoundationValue` were made on these numbers — the payloads are taken
/// without a checked cast, and the selector the proxy guard asks about is named rather than kept
/// in a static — and this is where either can be re-checked rather than assumed.
///
/// The same objects are told apart three ways. As they came from a framework, which is the
/// number the rest are read against; as objects of unknown origin, where the difference is what
/// asking the class about `_cfTypeID` costs; and by a ladder of Swift casts, which is what the
/// type ID replaces.
///
/// Each type is then measured alone, because `CFGetTypeID` does not cost the same for all of
/// them: it answers for a tagged pointer and for CoreFoundation's own classes itself, and sends
/// every other object a message.
func registerClassificationBenchmarks() {
    Benchmark("Tell apart a framework's objects") { benchmark, objects in
        for _ in benchmark.scaledIterations {
            for object in objects {
                blackHole(CoreFoundationValue(object))
            }
        }
    } setup: {
        makeObjects()
    }

    Benchmark("Tell apart objects of unknown origin") { benchmark, objects in
        for _ in benchmark.scaledIterations {
            for object in objects {
                blackHole(CoreFoundationValue(untrusted: object))
            }
        }
    } setup: {
        makeObjects()
    }

    Benchmark("Tell apart objects by a cast ladder") { benchmark, objects in
        for _ in benchmark.scaledIterations {
            for object in objects {
                castLadder(object)
            }
        }
    } setup: {
        makeObjects()
    }

    registerLeaf("a string") { NSString(string: "com.example.service") }
    registerLeaf("a boolean") { kCFBooleanTrue }
    registerLeaf("a number") { NSNumber(value: 2048) }
    registerLeaf("data") { NSData(data: Data([1, 2, 3])) }
    registerLeaf("a date") { NSDate(timeIntervalSinceReferenceDate: 0) }
    registerLeaf("an array") { NSArray(array: [1, 2]) }
    registerLeaf("a dictionary") { NSDictionary(dictionary: ["key": 1]) }
    registerLeaf("an object of another type") { NSObject() }
}
