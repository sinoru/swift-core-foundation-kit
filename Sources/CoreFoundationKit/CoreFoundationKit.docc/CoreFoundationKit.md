# ``CoreFoundationKit``

Reads what CoreFoundation hands back: tells an object apart by its type ID, reads a number as
what it says it holds, and walks an array or a dictionary without bridging it.

## Overview

The frameworks that deal in `CFDictionary` and `CFTypeRef` — property lists, the keychain,
IOKit — hand back a small set of types and leave the reader to work out which one it got. A
Swift cast cannot: `as? CFString` succeeds for any object, and `NSNumber(value: 1) as? Bool`
succeeds too. The type ID is the one question that answers it, and ``CoreFoundationValue`` is
that question asked once.

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
Foundation or Swift type from there. A number and the two collections take more than a cast to
read, and are carried as views that read them. A view costs nothing until it is asked, and
hands back the object it was made from as `base`.

An object a framework returned is read with ``CoreFoundationValue/init(unchecked:)``. One a
caller handed over is read with ``CoreFoundationValue/init(_:)``, which returns `nil` for a
proxy instead of letting `CFGetTypeID` send it a message it would raise on.

The package is for Apple platforms alone: what it reads is the CoreFoundation the Objective-C
runtime is bridged to, and no other platform has one.

## Topics

### Telling Objects Apart

- ``CoreFoundationValue``

### Reading Numbers

- ``CoreFoundationValue/NumberView``
- ``CoreFoundationValue/Number``

### Walking Collections

- ``CoreFoundationValue/ArrayView``
- ``CoreFoundationValue/DictionaryView``
