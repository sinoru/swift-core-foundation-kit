# CoreFoundationKit

[![GitHub Actions — Apple Platforms](https://github.com/sinoru/swift-core-foundation-kit/actions/workflows/apple-platforms.yml/badge.svg)](https://github.com/sinoru/swift-core-foundation-kit/actions/workflows/apple-platforms.yml)

[![Swift Package Index — Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsinoru%2Fswift-core-foundation-kit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/sinoru/swift-core-foundation-kit)
[![Swift Package Index — Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsinoru%2Fswift-core-foundation-kit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/sinoru/swift-core-foundation-kit)

**CoreFoundationKit** reads what CoreFoundation hands back. The frameworks that deal in
`CFDictionary` and `CFTypeRef` — property lists, the keychain, IOKit — hand back a small set of
types and leave the reader to work out which one it got, and a Swift cast cannot: `as? CFString`
succeeds for any object, and `NSNumber(value: 1) as? Bool` succeeds too. The type ID is the one
question that answers it, and this is that question asked once.

The [API documentation](https://swiftpackageindex.com/sinoru/swift-core-foundation-kit/documentation/corefoundationkit)
is hosted on the Swift Package Index.

## Table of Contents

* [Getting Started](#getting-started)
* [Numbers](#numbers)
* [Collections](#collections)
* [Objects of Unknown Origin](#objects-of-unknown-origin)
* [Performance](#performance)
* [Platform Support](#platform-support)
* [Contributing](#contributing)
* [License](#license)

## Getting Started

Add the package to your `Package.swift`, and `CoreFoundationKit` to the target that uses it:

```swift
dependencies: [
    .package(
        url: "https://github.com/sinoru/swift-core-foundation-kit.git",
        from: "1.0.0"
    ),
]
```

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "CoreFoundationKit", package: "swift-core-foundation-kit"),
    ]
),
```

```swift
import CoreFoundationKit

switch CoreFoundationValue(unchecked: object) {
case .string(let value):
    print(value as String)
case .boolean(let value):
    print(value)
case .number(let number):
    print(CoreFoundationValue.Number(number) as Any)
case .data, .date:
    break
case .array(let elements):
    for element in elements { print(element) }
case .dictionary(let elements):
    for (key, value) in elements { print(key, value) }
case .other(let object):
    print("not one of these:", object)
}
```

A string, data and a date are carried as the CoreFoundation type; bridge with `as` to the
Foundation or Swift type from there. Whether an object of some other type is an error or
something to carry along is left to the reader.

A number and the two collections take more than a cast to read, and are carried as views that
read them. A view costs nothing until it is asked, and hands back the object it was made from
as `base`.

## Numbers

`CoreFoundationValue.Number` is the value of a number as an integer or a floating-point number,
whichever the number says it is. A cast gets this wrong in both directions — a floating-point
`2.0` passes `as? Int64`, and `CFNumberGetValue` reads `UInt64.max` as -1 and calls it a
success — and the casts that do get it right bridge the number first, which most numbers never
need:

```swift
switch CoreFoundationValue.Number(number) {
case .integer(let value)?:          // an Int64
case .unsignedInteger(let value)?:  // a UInt64 above Int64.max
case .floatingPoint(let value)?:    // a Double, whole or not
case nil:                           // an integer none of them holds
}
```

A number CoreFoundation owns is read without loss. An `NSDecimalNumber` says it is
floating-point whatever it holds, and is read as the nearest `Double`, as
`PropertyListSerialization` writes it.

## Collections

An array and a dictionary are sequences of their elements, each told apart as it is reached. No
Swift array or dictionary is built on the way, a key that is not a string is handed over rather
than failing the cast for the whole dictionary, and the loop ends where the reader ends it:

```swift
case .dictionary(let elements):
    var result = [String: Value](minimumCapacity: elements.count)

    for (key, value) in elements {
        guard case .string(let key) = key, let value = Value(value) else { return nil }

        result[key as String] = value
    }
```

A collection must not be mutated while it is being walked, which is what CoreFoundation asks of
anything that walks one of its collections.

## Objects of Unknown Origin

An object a framework returned is read with `CoreFoundationValue(unchecked:)`. One a caller
handed over is read with `CoreFoundationValue(_:)`, which returns `nil` for a proxy instead of
letting `CFGetTypeID` send it a message it would raise on. A collection reads its elements the
way it was read itself, and a proxy among them is carried as `.other`.

A type that is not among the cases is told apart by its type ID, and
`CoreFoundationValue.typeID(of:)` answers with it under the same guard:

```swift
guard CoreFoundationValue.typeID(of: object) == SecKeyGetTypeID() else {
    return nil
}
```

## Performance

Measured on an Apple M4 Pro, macOS 26.7.1, Swift 6.4, by the benchmarks described under
[Running the benchmarks](#running-the-benchmarks). Each figure is instructions retired, for
objects CoreFoundation owns; read them as a comparison on one machine. Telling one object apart
is a few nanoseconds, and the clock varies by more between runs than these differ.

| | This package | Alternative |
| --- | --- | --- |
| Tell apart 14 objects of mixed types | 5,784 · of unknown origin: 8,872 | A ladder of Swift casts: 162K |
| Read a small integer | 305 | The casts that check exactness: 674 |
| Read `Int64.max` | 345 | The casts: 2,767 |
| Read a negative integer | 489 | The casts: 674 |
| Read `UInt64.max` | 740 | The casts: 3,899 |
| Read a floating-point number | 396 | The casts: 396 |
| Walk an array of 4 / 16 / 64 | 697 / 2,634 / 17K | Fast enumeration: 2,277 / 8,114 / 43K · `object(at:)`: 805 / 3,432 / 27K |
| Walk a dictionary of 4 / 16 / 64 | 1,740 / 6,939 / 20K | `enumerateKeysAndObjects(_:)`: 8,643 / 23K / 80K |

A number is read after the object is told apart, which is how a reader comes by one. A walk
starts from the collection as an object, tells it apart, and tells every element apart; the
walks it is measured against do the same by hand over the `NSArray` or `NSDictionary`. A
collection of unknown origin, and one bridged from Swift rather than owned by CoreFoundation,
are measured beside each of these.

## Platform Support

The package supports macOS 12, Mac Catalyst 15, iOS 15, tvOS 15, watchOS 8, and visionOS 1 or
later. It is for Apple platforms alone: what it reads is the CoreFoundation the Objective-C
runtime is bridged to, and no other platform has one. A package that also builds elsewhere
depends on it under a platform condition:

```swift
.product(
    name: "CoreFoundationKit",
    package: "swift-core-foundation-kit",
    condition: .when(platforms: [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS])
)
```

Building the package requires Swift 6.2 (Xcode 26) or later.

### Running the benchmarks

The measurements are a package of their own, under `Benchmarks`, so that the harness they run on
— [Benchmark](https://github.com/ordo-one/benchmark) — is never among what a package depending
on this one resolves.

```sh
cd Benchmarks
swift package benchmark
```

To compare a change against what came before it, record a baseline first:

```sh
swift package --allow-writing-to-package-directory benchmark baseline update before
swift package benchmark baseline compare before
```

Read the numbers; nothing there fails on a regression.

## Contributing

Bug reports, feature ideas, and pull requests are welcome on
[GitHub](https://github.com/sinoru/swift-core-foundation-kit).

## License

[Apache License 2.0](LICENSE)
