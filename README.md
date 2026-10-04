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
case .number(let value):
    print(CoreFoundationValue.Number(exactly: value) as Any)
case .data, .date, .array, .dictionary:
    break
case .other(let object):
    print("not one of these:", object)
}
```

Each payload is the CoreFoundation type; bridge with `as` to the Foundation or Swift type from
there. Whether an object of some other type is an error or something to carry along is left to
the reader.

A number and the two collections take more than a cast to read, and are read here too.

`CoreFoundationValue.Number` is the value of a `CFNumber` as the Swift type that holds it
exactly. A cast gets this wrong in both directions — a floating-point `2.0` passes `as? Int64`,
and `CFNumberGetValue` reads `UInt64.max` as -1 and calls it a success — and the casts that do
get it right bridge the number first, which most numbers never need:

```swift
switch CoreFoundationValue.Number(exactly: number) {
case .integer(let value)?:          // an Int64
case .unsignedInteger(let value)?:  // a UInt64 above Int64.max
case .floatingPoint(let value)?:    // a Double, whole or not
case nil:                           // held exactly by none of them
}
```

`CoreFoundationValue.ArrayElements` and `CoreFoundationValue.DictionaryElements` are the
contents of a `CFArray` and a `CFDictionary` as collections of objects not yet told apart. No
Swift array or dictionary is built on the way, a key that is not a string is handed over rather
than failing the cast for the whole dictionary, and the loop ends where the reader ends it:

```swift
for (key, value) in CoreFoundationValue.DictionaryElements(dictionary) {
    guard case .string(let key) = CoreFoundationValue(unchecked: key) else { return nil }

    result[key as String] = read(CoreFoundationValue(unchecked: value))
}
```

An object a framework returned is read with `CoreFoundationValue(unchecked:)`. One a caller
handed over is read with `CoreFoundationValue(_:)`, which returns `nil` for a proxy instead of
letting `CFGetTypeID` send it a message it would raise on.

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
