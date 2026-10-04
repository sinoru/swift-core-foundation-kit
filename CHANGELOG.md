# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[unreleased]: https://github.com/sinoru/swift-core-foundation-kit/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/sinoru/swift-core-foundation-kit/releases/tag/v0.0.1
