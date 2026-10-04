# CoreFoundationKit

**CoreFoundationKit** tells CoreFoundation objects apart. The frameworks that deal in
`CFDictionary` and `CFTypeRef` — property lists, the keychain, IOKit — hand back a small set of
types and leave the reader to work out which one it got, and a Swift cast cannot: `as? CFString`
succeeds for any object, and `NSNumber(value: 1) as? Bool` succeeds too. The type ID is the one
question that answers it, and this is that question asked once.

```swift
import CoreFoundationKit

switch CoreFoundationValue(object) {
case .string(let value):
    print(value as String)
case .boolean(let value):
    print(value)
case .number(let value):
    print(CFNumberIsFloatType(value) ? "real" : "integer")
case .data, .date, .array, .dictionary:
    break
case .other(let object):
    print("not one of these:", object)
}
```

What a number becomes, how a collection is walked, and whether an object of some other type is
an error or something to carry along are left to the reader. Each payload is the CoreFoundation
type; bridge with `as` to the Foundation or Swift type from there.

An object a framework returned is read with `CoreFoundationValue(_:)`. One a caller handed over
is read with `CoreFoundationValue(untrusted:)`, which returns `nil` for a proxy instead of
letting `CFGetTypeID` send it a message it would raise on.

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

## License

See [LICENSE](LICENSE).
