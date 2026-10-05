//
//  CoreFoundationValue+NumberView.swift
//  CoreFoundationKit
//

public import CoreFoundation
public import Foundation

extension CoreFoundationValue {
    /// A `CFNumber`, not yet read.
    ///
    /// Telling a number apart does not read it: what it holds is asked for by
    /// ``CoreFoundationValue/Number/init(_:)``, and a reader that only carries the number along
    /// takes ``base`` and pays for no question at all.
    public struct NumberView {
        /// The number this is a view of.
        public let base: CFNumber

        @inlinable
        init(base: CFNumber) {
            self.base = base
        }
    }
}

extension CoreFoundationValue.NumberView {
    /// Returns the value of the number, if one of the cases of `Number` holds it.
    ///
    /// The questions, and the order they are asked in, are `Number.init(_:)`'s to explain. They
    /// are asked here because a method borrows the value it is called on, where an initializer
    /// owns its argument: nothing is retained to be handed over.
    @inlinable
    func number() -> CoreFoundationValue.Number? {
        if CFNumberIsFloatType(base) {
            return .floatingPoint((base as NSNumber).doubleValue)
        }

        var value: Int64 = 0
        _ = unsafe CFNumberGetValue(base, .sInt64Type, &value)

        if value >= 0 {
            return .integer(value)
        } else {
            return CoreFoundationValue.Number(base, readingAsNegative: value)
        }
    }
}
