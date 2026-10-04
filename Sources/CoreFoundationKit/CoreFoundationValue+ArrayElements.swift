//
//  CoreFoundationValue+ArrayElements.swift
//  CoreFoundationKit
//

public import CoreFoundation
public import Foundation

extension CoreFoundationValue {
    /// The elements of a `CFArray`, not yet told apart.
    ///
    /// Each element is the object as the array holds it, to be read with
    /// ``CoreFoundationValue/init(unchecked:)`` or ``CoreFoundationValue/init(_:)`` as its origin
    /// calls for. Casting the array to `[Any]` instead would box every element on the way out,
    /// only for the reader to unbox it again, and walking it as an `NSArray` does the same one
    /// element at a time.
    ///
    /// The array must not be mutated for as long as this is in use, which is what CoreFoundation
    /// asks of anything that walks one of its collections. An array handed over as a `CFArray`
    /// may still be a mutable one underneath, and nothing here can tell: the count is read once,
    /// and CoreFoundation does not check an index against it.
    public struct ArrayElements {
        /// Kept as the CoreFoundation type, because that is the one to ask.
        /// `CFArrayGetValueAtIndex` hands back the element as the array holds it; `object(at:)`
        /// hands back one the caller has to claim before it can be used, and measured as half as
        /// much work again for an array CoreFoundation owns.
        @usableFromInline
        let array: CFArray

        public let endIndex: Int

        /// Creates a collection of the elements of an array.
        ///
        /// - Parameter array: An array whose elements are objects, as
        ///   ``CoreFoundationValue/array(_:)`` carries it. Every array a framework hands back is
        ///   one; an array created with callbacks of its own, to hold something that is not an
        ///   object, is not.
        @inlinable
        public init(_ array: CFArray) {
            self.array = array
            // Asked of the Foundation type, unlike the elements: `CFArrayGetCount` works out
            // whether the array is CoreFoundation's own before it answers, which for an array of
            // one or none measured as more than the rest of walking it.
            self.endIndex = (array as NSArray).count
        }
    }
}

extension CoreFoundationValue.ArrayElements: RandomAccessCollection {
    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public subscript(position: Int) -> CFTypeRef {
        // CoreFoundation checks the index only in a debug build of itself.
        precondition(position >= 0 && position < endIndex, "Index out of range")

        return unsafe Unmanaged<AnyObject>
            .fromOpaque(CFArrayGetValueAtIndex(array, position))
            .takeUnretainedValue()
    }
}
