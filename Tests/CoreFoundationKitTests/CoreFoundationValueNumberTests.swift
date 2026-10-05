//
//  CoreFoundationValueNumberTests.swift
//  CoreFoundationKit
//
//  Copyright (c) 2026 Kang Jaehong
//  SPDX-License-Identifier: Apache-2.0
//

import CoreFoundation
import CoreFoundationKit
import Foundation
import Testing

@Suite
struct CoreFoundationValueNumberTests {
    private typealias Number = CoreFoundationValue.Number

    /// Reads a number the way a reader comes by one: told apart first, then asked for its value.
    private func number(_ value: NSNumber) -> Number? {
        guard case .number(let number) = CoreFoundationValue(unchecked: value) else {
            Issue.record("A number was read as something else")
            return nil
        }

        return Number(number)
    }

    @Test
    func readsAnIntegerOfAnyWidth() {
        #expect(number(NSNumber(value: Int8(1))) == .integer(1))
        #expect(number(NSNumber(value: Int16(-300))) == .integer(-300))
        #expect(number(NSNumber(value: Int32.min)) == .integer(Int64(Int32.min)))
        #expect(number(NSNumber(value: 0)) == .integer(0))
        #expect(number(NSNumber(value: -1)) == .integer(-1))
        #expect(number(NSNumber(value: Int64.min)) == .integer(.min))
        #expect(number(NSNumber(value: Int64.max)) == .integer(.max))
    }

    // An unsigned value `Int64` holds is an integer like any other; only one above `Int64.max`
    // needs the other case. `CFNumberGetValue` reports success for those and hands back the bit
    // pattern, so `UInt64.max` and -1 are the pair that a reader of the value alone confuses.
    @Test
    func readsAnUnsignedIntegerAboveInt64AsUnsigned() {
        #expect(number(NSNumber(value: UInt32.max)) == .integer(Int64(UInt32.max)))
        #expect(number(NSNumber(value: UInt64(5))) == .integer(5))
        #expect(number(NSNumber(value: UInt64(Int64.max))) == .integer(.max))
        #expect(
            number(NSNumber(value: UInt64(Int64.max) + 1))
                == .unsignedInteger(UInt64(Int64.max) + 1)
        )
        #expect(number(NSNumber(value: UInt64.max)) == .unsignedInteger(.max))
    }

    // The collapse a Swift cast makes: `NSNumber(value: 2.0) as? Int64` succeeds.
    @Test
    func keepsAWholeFloatingPointNumberFloatingPoint() {
        #expect(number(NSNumber(value: 2.0)) == .floatingPoint(2))
        #expect(number(NSNumber(value: Float(2))) == .floatingPoint(2))
        #expect(number(NSNumber(value: -0.0)) == .floatingPoint(-0.0))
    }

    @Test
    func readsAFloatingPointNumber() {
        #expect(number(NSNumber(value: 2.5)) == .floatingPoint(2.5))
        #expect(number(NSNumber(value: Float(0.5))) == .floatingPoint(0.5))
        #expect(number(NSNumber(value: 1e300)) == .floatingPoint(1e300))
        #expect(number(NSNumber(value: Double.infinity)) == .floatingPoint(.infinity))
        #expect(number(NSNumber(value: -Double.infinity)) == .floatingPoint(-.infinity))

        guard case .floatingPoint(let value)? = number(NSNumber(value: Double.nan)) else {
            Issue.record("A NaN was read as something else")
            return
        }

        #expect(value.isNaN)
    }

    // `NSDecimalNumber` is not CoreFoundation's own, and answers through the messages
    // CoreFoundation sends an `NSNumber` it does not implement. It says it is floating-point,
    // whole or not.
    @Test
    func readsADecimalNumberAsFloatingPoint() {
        #expect(number(NSDecimalNumber(string: "3.5")) == .floatingPoint(3.5))
        #expect(number(NSDecimalNumber(string: "3")) == .floatingPoint(3))
    }

    // A decimal number is the one number read with loss, and the reason the initializer's argument
    // has no label that says otherwise. It holds more digits than a `Double` keeps and says it is
    // floating-point all the same, so it is read as the nearest `Double` — which is what
    // `PropertyListSerialization` writes for it, and so what reading it back would give.
    @Test
    func readsADecimalNumberADoubleCannotHoldAsTheNearestDouble() {
        // One past the 53 bits a `Double` keeps, with a fraction and without.
        #expect(
            number(NSDecimalNumber(string: "9007199254740993.25"))
                == .floatingPoint(9_007_199_254_740_994)
        )
        #expect(
            number(NSDecimalNumber(string: "9007199254740993"))
                == .floatingPoint(9_007_199_254_740_992)
        )
        #expect(number(NSDecimalNumber(string: "0.1")) == .floatingPoint(0.1))
    }

    // Swift values a caller built by hand bridge to the same numbers.
    @Test
    func readsABridgedSwiftNumber() {
        #expect(number(42 as NSNumber) == .integer(42))
        #expect(number(-42 as NSNumber) == .integer(-42))
        #expect(number(UInt64.max as NSNumber) == .unsignedInteger(.max))
        #expect(number(2.0 as NSNumber) == .floatingPoint(2))
        #expect(number(Float(0.5) as NSNumber) == .floatingPoint(0.5))
    }

    @Test
    func readsTheNumbersOfAPropertyList() throws {
        let data = Data(
            """
            <plist version="1.0"><array>
                <integer>18446744073709551615</integer>
                <integer>-1</integer>
                <integer>9223372036854775808</integer>
                <real>2</real>
            </array></plist>
            """.utf8
        )
        let propertyList = try unsafe PropertyListSerialization.propertyList(
            from: data,
            format: nil
        )
        let numbers = try #require(propertyList as? [NSNumber])

        #expect(
            numbers.map(number) == [
                .unsignedInteger(.max),
                .integer(-1),
                .unsignedInteger(UInt64(Int64.max) + 1),
                .floatingPoint(2),
            ]
        )
    }

    /// A binary property list holding one integer written in 16 bytes, which is the one way an
    /// API hands back a number CoreFoundation stores in 128 bits.
    private func number(high: UInt64, low: UInt64) throws -> NSNumber {
        func bigEndianBytes(of value: UInt64) -> [UInt8] {
            (0..<8).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
        }

        var data = Data("bplist00".utf8)
        data.append(0x14)
        data.append(contentsOf: bigEndianBytes(of: high))
        data.append(contentsOf: bigEndianBytes(of: low))
        // The offset table, of the one object, and the trailer that says where it is.
        data.append(0x08)
        data.append(contentsOf: [0, 0, 0, 0, 0, 0, 1, 1])
        data.append(contentsOf: bigEndianBytes(of: 1))
        data.append(contentsOf: bigEndianBytes(of: 0))
        data.append(contentsOf: bigEndianBytes(of: 25))

        let propertyList = try unsafe PropertyListSerialization.propertyList(
            from: data,
            format: nil
        )

        return try #require(propertyList as? NSNumber)
    }

    // What a 128-bit integer reads as is CoreFoundation's to decide and has not stayed the same
    // between releases, so this holds it to no value. It holds the path that does not bridge to
    // the casts that do: whatever they make of the number, this makes the same.
    @Test(
        arguments: [
            (high: 0, low: 5),
            (high: 0, low: UInt64(Int64.max)),
            (high: 0, low: UInt64(Int64.max) + 1),
            (high: 0, low: UInt64.max),
            (high: 1, low: 5),
            (high: 1, low: UInt64.max),
            (high: UInt64.max, low: UInt64.max),
            (high: UInt64.max, low: 0),
            (high: UInt64.max, low: UInt64(Int64.max)),
            (high: UInt64.max, low: UInt64(Int64.max) + 1),
        ] as [(high: UInt64, low: UInt64)]
    )
    func readsAnIntegerStoredIn128BitsAsTheCastsDo(high: UInt64, low: UInt64) throws {
        let value = try number(high: high, low: low)
        let expected: Number? =
            if let value = value as? Int64 {
                .integer(value)
            } else if let value = value as? UInt64 {
                .unsignedInteger(value)
            } else {
                nil
            }

        #expect(number(value) == expected)
    }
}
