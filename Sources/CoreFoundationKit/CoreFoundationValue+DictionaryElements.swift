//
//  CoreFoundationValue+DictionaryElements.swift
//  CoreFoundationKit
//

public import CoreFoundation

extension CoreFoundationValue {
    /// The keys and values of a `CFDictionary`, not yet told apart.
    ///
    /// Each key and value is the object as the dictionary holds it, to be read with
    /// ``CoreFoundationValue/init(unchecked:)`` or ``CoreFoundationValue/init(_:)`` as its origin
    /// calls for. Casting the dictionary to `[String: Any]` instead would build a Swift
    /// dictionary, hashing every key again, only for the reader to build its own from it — and
    /// would fail outright for a key that is not a string, where this leaves the reader to say
    /// what such a key means.
    ///
    /// A loop over this ends where the reader ends it: `break` and `return` do what
    /// `enumerateKeysAndObjects(_:)` needs its stop pointer for.
    ///
    /// The elements come in the order the dictionary answered with them, which is no order to
    /// depend on.
    ///
    /// The dictionary must not be mutated for as long as this is in use, which is what
    /// CoreFoundation asks of anything that walks one of its collections. A dictionary handed
    /// over as a `CFDictionary` may still be a mutable one underneath, and nothing here can tell:
    /// the keys and values are read out once and are the dictionary's to keep alive.
    @safe
    public struct DictionaryElements {
        /// What keeps the keys and values alive. They are read from `storage`.
        @usableFromInline
        let dictionary: CFDictionary

        /// The keys, then the values, as the dictionary wrote them out in one call.
        @usableFromInline
        let storage: [UnsafeRawPointer?]

        public let endIndex: Int

        /// Creates a collection of the keys and values of a dictionary.
        ///
        /// - Parameter dictionary: A dictionary whose keys and values are objects, as
        ///   ``CoreFoundationValue/dictionary(_:)`` carries it. Every dictionary a framework hands
        ///   back is one; a dictionary created with callbacks of its own, to hold something that
        ///   is not an object, is not.
        @inlinable
        public init(_ dictionary: CFDictionary) {
            let count = CFDictionaryGetCount(dictionary)

            self.dictionary = dictionary
            self.endIndex = count
            unsafe self.storage = [UnsafeRawPointer?](
                unsafeUninitializedCapacity: count * 2
            ) { buffer, initializedCount in
                guard count > 0, let keys = buffer.baseAddress else { return }

                unsafe CFDictionaryGetKeysAndValues(dictionary, keys, keys + count)
                initializedCount = count * 2
            }
        }
    }
}

extension CoreFoundationValue.DictionaryElements: RandomAccessCollection {
    public typealias Element = (key: CFTypeRef, value: CFTypeRef)

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < endIndex, "Index out of range")

        // Neither is `nil`: a dictionary of objects holds no null key or value, and `storage`
        // was filled with `endIndex` of each.
        return (
            key: unsafe Unmanaged<AnyObject>
                .fromOpaque(storage[position]!)
                .takeUnretainedValue(),
            value: unsafe Unmanaged<AnyObject>
                .fromOpaque(storage[endIndex + position]!)
                .takeUnretainedValue()
        )
    }
}
