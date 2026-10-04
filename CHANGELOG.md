# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `CoreFoundationValue.Number`, the value of a `CFNumber` as the number says it holds it: an
  `Int64`, a `UInt64` for an integer above `Int64.max`, or a `Double` for a number of a
  floating-point type, whole or not. `Number(_:)` asks the questions in the order that gets
  this right, and bridges the number only when it read as negative and says it holds neither
  a signed integer nor an unsigned one. A number CoreFoundation owns is read without loss; an
  `NSDecimalNumber`, which says it is floating-point whatever it holds, is read as the
  nearest `Double`. Next to the casts that check exactness,
  an integer that is not negative is read in less than half the work, one too large for a
  tagged pointer in an eighth of it, and one above `Int64.max` in under a fifth.
- `CoreFoundationValue.ArrayElements` and `CoreFoundationValue.DictionaryElements`, the
  contents of a `CFArray` and a `CFDictionary` as collections of objects not yet told apart.
  Neither builds a Swift array or dictionary, a loop over either ends where the reader ends
  it, and a key that is not a string is handed over for the reader to judge. For
  collections CoreFoundation owns, walking a dictionary of 16 entries takes under a fifth of
  the work of `enumerateKeysAndObjects(_:)`, and an array of 16 elements under a sixth of the
  work of fast enumeration; for ones bridged from Swift, under a third and under a half.

### Changed

- The package no longer leaves what a number becomes and how a collection is walked to the
  reader. It tells an object apart and reads the ones that take more than a cast to read.
- The module now imports Foundation publicly.

## [0.0.2] - 2026-10-05

### Added

- `CoreFoundationValue.typeID(of:)`, which answers with the CoreFoundation type ID of an object
  of unknown origin, or `nil` for a proxy. It is the question to ask before comparing against
  the type ID of a type that is not among the cases, such as `SecKeyGetTypeID()`.

## [0.0.1] - 2026-10-05

### Added

- `CoreFoundationValue`, which tells a CoreFoundation object apart by its type ID: a string,
  boolean, number, data, date, array, or dictionary, or `.other` for an object of any other
  type. A Swift cast cannot answer this, since `as? CFString` succeeds for any object and
  `NSNumber(value: 1) as? Bool` succeeds too. Each payload is the CoreFoundation type, except
  a boolean, which is the `Bool` it stands for; what a number becomes and how a collection is
  walked are left to the reader.
- `CoreFoundationValue(unchecked:)`, which reads an object that came from CoreFoundation or a
  framework built on it.
- `CoreFoundationValue(_:)`, which reads an object of unknown origin and returns `nil` for a
  proxy, instead of letting `CFGetTypeID` send it a message it would raise on.
- Support for macOS 12, Mac Catalyst 15, iOS 15, tvOS 15, watchOS 8, and visionOS 1, with
  Swift 6.2 or later. The package is for Apple platforms alone.

[unreleased]: https://github.com/sinoru/swift-core-foundation-kit/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/sinoru/swift-core-foundation-kit/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/sinoru/swift-core-foundation-kit/releases/tag/v0.0.1
