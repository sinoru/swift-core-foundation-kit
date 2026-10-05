# CoreFoundationKit

**CoreFoundationKit** reads what CoreFoundation hands back. The frameworks that deal in
`CFDictionary` and `CFTypeRef` — property lists, the keychain, IOKit — hand back a small set of
types and leave the reader to work out which one it got, and a Swift cast cannot: `as? CFString`
succeeds for any object, and `NSNumber(value: 1) as? Bool` succeeds too. The type ID is the one
question that answers it, and this is that question asked once.

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

## Requirements

* Swift 6.2 (Xcode 26) or later
* macOS 12, Mac Catalyst 15, iOS 15, tvOS 15, watchOS 8, or visionOS 1

The package is for Apple platforms alone. A package that also builds elsewhere depends on it
under a platform condition:

```swift
.product(
    name: "CoreFoundationKit",
    package: "swift-core-foundation-kit",
    condition: .when(platforms: [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS])
)
```

## Running the benchmarks

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

## License

See [LICENSE](LICENSE).
