//
//  CoreFoundationValue+DictionaryView.swift
//  CoreFoundationKit
//

public import CoreFoundation

extension CoreFoundationValue {
    /// A `CFDictionary`, as a sequence of its keys and values.
    ///
    /// Each key and value is told apart as it is reached, the way the dictionary itself was: one
    /// read by ``CoreFoundationValue/init(_:)`` has its keys and values read under the same guard.
    /// Casting the dictionary to `[String: Any]` instead would build a Swift dictionary, hashing
    /// every key again, only for the reader to build its own from it — and would fail outright for
    /// a key that is not a string, where this leaves the reader to say what such a key means.
    ///
    /// A loop over this ends where the reader ends it: `break` and `return` do what
    /// `enumerateKeysAndObjects(_:)` needs its stop pointer for. The elements come in the order
    /// the dictionary answered with them, which is no order to depend on.
    ///
    /// The dictionary must not be mutated while it is being walked, which is what CoreFoundation
    /// asks of anything that walks one of its collections. A dictionary handed over as a
    /// `CFDictionary` may still be a mutable one underneath, and nothing here can tell: an
    /// iterator reads the keys and values out once, and they are the dictionary's to keep alive.
    public struct DictionaryView {
        /// The dictionary this is a view of.
        public let base: CFDictionary

        /// Whether the keys and values are of unknown origin, as the dictionary was.
        @usableFromInline
        let checksElements: Bool

        @inlinable
        init(base: CFDictionary, checksElements: Bool) {
            self.base = base
            self.checksElements = checksElements
        }

        /// The number of key-value pairs in the dictionary.
        @inlinable
        public var count: Int {
            CFDictionaryGetCount(base)
        }
    }
}

extension CoreFoundationValue.DictionaryView: Sequence {
    public typealias Element = (key: CoreFoundationValue, value: CoreFoundationValue)

    /// An iterator over the keys and values of a dictionary.
    ///
    /// The keys and values are read out when the iterator is made, not when the dictionary is
    /// told apart, so a reader that never walks the dictionary allocates nothing for it.
    @safe
    public struct Iterator: IteratorProtocol {
        /// What keeps the keys and values alive. They are read from `storage`.
        @usableFromInline
        let base: CFDictionary

        /// The keys, then the values, as the dictionary wrote them out in one call.
        @usableFromInline
        let storage: [UnsafeRawPointer?]

        @usableFromInline
        let count: Int

        @usableFromInline
        let checksElements: Bool

        @usableFromInline
        var position = 0

        @inlinable
        init(base: CFDictionary, count: Int, checksElements: Bool) {
            self.base = base
            self.count = count
            self.checksElements = checksElements
            unsafe self.storage = [UnsafeRawPointer?](
                unsafeUninitializedCapacity: count * 2
            ) { buffer, initializedCount in
                guard count > 0, let keys = buffer.baseAddress else { return }

                unsafe CFDictionaryGetKeysAndValues(base, keys, keys + count)
                initializedCount = count * 2
            }
        }

        @inlinable
        public mutating func next() -> Element? {
            guard position < count else { return nil }

            // Neither is `nil`: a dictionary of objects holds no null key or value, and `storage`
            // was filled with `count` of each.
            let key = unsafe Unmanaged<AnyObject>
                .fromOpaque(storage[position]!)
                .takeUnretainedValue()
            let value = unsafe Unmanaged<AnyObject>
                .fromOpaque(storage[count + position]!)
                .takeUnretainedValue()

            position += 1

            return (
                key: CoreFoundationValue(element: key, checked: checksElements),
                value: CoreFoundationValue(element: value, checked: checksElements)
            )
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
