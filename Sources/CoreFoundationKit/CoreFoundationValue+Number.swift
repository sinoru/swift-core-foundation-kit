//
//  CoreFoundationValue+Number.swift
//  CoreFoundationKit
//
//  Copyright (c) 2026 Kang Jaehong
//  SPDX-License-Identifier: Apache-2.0
//

public import CoreFoundation
internal import Foundation

extension CoreFoundationValue {
    /// The value of a `CFNumber`, as an integer or a floating-point number, whichever the number
    /// says it is.
    ///
    /// A `CFNumber` does not say what it holds in a way a reader can take at its word. A Swift cast
    /// succeeds whenever the value is exactly representable, so a floating-point `2.0` passes
    /// `as? Int64` and arrives as an integer. `CFNumberGetType` answers `sInt64Type` for an
    /// unsigned value above `Int64.max`, and `CFNumberGetValue` then reports success and hands
    /// back its bit pattern: `UInt64.max` reads as -1. The order the questions are asked in is
    /// what gets it right, and this is where they are asked.
    public enum Number: Hashable, Sendable {
        /// An integer that `Int64` holds, whichever width the number stored it in.
        case integer(Int64)
        /// An integer above `Int64.max`. One that `Int64` holds is an ``integer(_:)``, so the two
        /// cases never stand for the same value.
        case unsignedInteger(UInt64)
        /// A number of a floating-point type, widened to `Double`. It stays one when its value is
        /// whole: what was stored as `2.0` is not an integer.
        case floatingPoint(Double)
    }
}

extension CoreFoundationValue.Number {
    /// Creates a value from a number, if one of the cases holds it.
    ///
    /// The number is taken at its word about its type. One CoreFoundation owns holds what it says
    /// it does, and is read without loss. One it does not own answers through Foundation, and an
    /// `NSDecimalNumber` answers that it is floating-point whatever it holds. It is read as the
    /// `Double` nearest its value, which is what `PropertyListSerialization` writes for it and
    /// what `Double(exactly:)` makes of it: a decimal fraction is rounded, and so is a whole
    /// number past the 53 bits a `Double` keeps. That is why the argument has no label promising
    /// otherwise.
    ///
    /// Whether the number is of a floating-point type is asked first, because nothing asked of
    /// the value afterwards can tell a whole `Double` from an integer.
    ///
    /// An integer is then read as an `Int64`, which CoreFoundation answers without a conversion
    /// for every integer it stores in 64 bits. A result that is not negative is the value, and
    /// that is where most numbers are done, never having been bridged. A negative one is either
    /// that value or the bit pattern of an unsigned one above `Int64.max`, and what the number
    /// says it holds settles which.
    ///
    /// No number made through an API CoreFoundation or Foundation declares is known to come back
    /// `nil`. CoreFoundation can store an integer in 128 bits, though, and nothing promises that
    /// one beyond both `Int64` and `UInt64` cannot reach a reader, so the initializer does not
    /// promise it either.
    ///
    /// The number is borrowed. An initializer owns its arguments unless it says otherwise, so a
    /// caller that only has the number on loan would retain it to hand it over and this would
    /// release it on the way out, which for a number too large for a tagged pointer measured as
    /// more than a third of reading it.
    ///
    /// - Parameter number: A number, as ``CoreFoundationValue/number(_:)`` carries it.
    @inlinable
    public init?(_ number: borrowing CoreFoundationValue.NumberView) {
        guard let value = number.number() else { return nil }

        self = value
    }

    /// Creates a value from an integer that read as a negative `Int64`.
    ///
    /// What the number says it holds settles which of the two it is. A signed integer is that
    /// negative value: no signed type has room for one above `Int64.max`, so the reading cannot
    /// be the bit pattern of anything else. An unsigned one of 64 bits is never negative, so the
    /// reading is its bit pattern and nothing else.
    ///
    /// A number that says neither is bridged and asked by the casts that check exactness. A value
    /// above `Int64.max` fails the first and reaches the second, rather than coming back
    /// truncated.
    ///
    /// Out of line, because it is the path few numbers take.
    @usableFromInline
    init?(_ number: borrowing CFNumber, readingAsNegative value: Int64) {
        let number = (copy number) as NSNumber

        switch unsafe UInt8(bitPattern: number.objCType.pointee) {
        case UInt8(ascii: "c"), UInt8(ascii: "s"), UInt8(ascii: "i"), UInt8(ascii: "l"),
            UInt8(ascii: "q"):
            self = .integer(value)
        case UInt8(ascii: "L"), UInt8(ascii: "Q"):
            self = .unsignedInteger(UInt64(bitPattern: value))
        default:
            if let value = number as? Int64 {
                self = .integer(value)
            } else if let value = number as? UInt64 {
                self = .unsignedInteger(value)
            } else {
                return nil
            }
        }
    }
}
