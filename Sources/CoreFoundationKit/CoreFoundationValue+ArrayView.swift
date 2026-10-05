//
//  CoreFoundationValue+ArrayView.swift
//  CoreFoundationKit
//
//  Copyright (c) 2026 Kang Jaehong
//  SPDX-License-Identifier: Apache-2.0
//

public import CoreFoundation
public import Foundation

extension CoreFoundationValue {
    /// A `CFArray`, as a sequence of its elements.
    ///
    /// Each element is told apart as it is reached, the way the array itself was: one read by
    /// ``CoreFoundationValue/init(_:)`` has its elements read under the same guard. Casting the
    /// array to `[Any]` instead would box every element on the way out, only for the reader to
    /// unbox it again, and walking it as an `NSArray` does the same one element at a time.
    ///
    /// The array must not be mutated while it is being walked, which is what CoreFoundation asks
    /// of anything that walks one of its collections. An array handed over as a `CFArray` may
    /// still be a mutable one underneath, and nothing here can tell: an iterator reads the count
    /// once, and CoreFoundation does not check an index against it.
    public struct ArrayView {
        /// The array this is a view of.
        public let base: CFArray

        /// Whether the elements are of unknown origin, as the array was.
        @usableFromInline
        let checksElements: Bool

        @inlinable
        init(base: CFArray, checksElements: Bool) {
            self.base = base
            self.checksElements = checksElements
        }

        /// The number of elements in the array.
        ///
        /// Asked of the Foundation type, unlike the elements: `CFArrayGetCount` works out whether
        /// the array is CoreFoundation's own before it answers, which for an array of one or none
        /// measured as more than the rest of walking it.
        @inlinable
        public var count: Int {
            (base as NSArray).count
        }
    }
}

extension CoreFoundationValue.ArrayView: Sequence {
    /// An iterator over the elements of an array.
    public struct Iterator: IteratorProtocol {
        /// Kept as the CoreFoundation type, because that is the one to ask for an element.
        /// `CFArrayGetValueAtIndex` hands back the element as the array holds it; `object(at:)`
        /// hands back one the caller has to claim before it can be used, and measured as half as
        /// much work again for an array CoreFoundation owns.
        @usableFromInline
        let base: CFArray

        @usableFromInline
        let count: Int

        @usableFromInline
        let checksElements: Bool

        @usableFromInline
        var position = 0

        @inlinable
        init(base: CFArray, count: Int, checksElements: Bool) {
            self.base = base
            self.count = count
            self.checksElements = checksElements
        }

        @inlinable
        public mutating func next() -> CoreFoundationValue? {
            guard position < count else { return nil }

            let element = unsafe Unmanaged<AnyObject>
                .fromOpaque(CFArrayGetValueAtIndex(base, position))

            position += 1

            // The element is lent, not claimed: the array keeps it alive for as long as it is
            // not mutated, which a walk already asks. Claiming it retained it once to be handed
            // over and once more for the payload, which for an array of 16 measured as a fifth
            // of walking it. `_withUnsafeGuaranteedRef` is not a public API, and is the one
            // thing here to replace should the standard library take it away.
            return unsafe element._withUnsafeGuaranteedRef {
                CoreFoundationValue(element: $0, checked: checksElements)
            }
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(base: base, count: count, checksElements: checksElements)
    }

    @inlinable
    public var underestimatedCount: Int {
        count
    }
}
