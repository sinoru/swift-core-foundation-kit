//
//  CoreFoundationValue+DictionaryView.swift
//  CoreFoundationKit
//

public import CoreFoundation
public import Foundation

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
        ///
        /// Asked of the Foundation type, as an array's is and for the same reason:
        /// `CFDictionaryGetCount` works out whether the dictionary is CoreFoundation's own
        /// before it answers.
        @inlinable
        public var count: Int {
            (base as NSDictionary).count
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
        /// What keeps the keys and values alive. They are read from `inlineStorage` or `storage`.
        @usableFromInline
        let base: CFDictionary

        /// How many key-value pairs `inlineStorage` has room for.
        ///
        /// Every walk pays for the room whether it uses it or not. Room for sixteen measured as
        /// a quarter less work for a dictionary of sixteen and a fifth more for one of none;
        /// with room for eight, no dictionary is walked in more work than it was from the heap
        /// alone.
        @inlinable
        static var inlineCapacity: Int { 8 }

        /// Room for `inlineCapacity` keys and as many values.
        ///
        /// A tuple with every element spelled out rather than an `InlineArray`, which is
        /// unavailable below macOS 26.
        @usableFromInline
        typealias InlineStorage = (
            UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?,
            UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?,
            UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?,
            UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?
        )

        /// The keys, then the values, of a dictionary of no more than `inlineCapacity` pairs,
        /// as the dictionary wrote them out in one call.
        ///
        /// Kept in the iterator itself, because an array's buffer is one allocation made and
        /// one freed for every walk, which for a dictionary of one pair measured as more than
        /// the rest of walking it.
        @usableFromInline
        var inlineStorage: InlineStorage = (
            nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
        )

        /// The keys, then the values, of a dictionary too large for `inlineStorage`. Empty for
        /// one that is not.
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

            guard count <= Self.inlineCapacity else {
                unsafe self.storage = [UnsafeRawPointer?](
                    unsafeUninitializedCapacity: count * 2
                ) { buffer, initializedCount in
                    guard let keys = buffer.baseAddress else { return }

                    unsafe CFDictionaryGetKeysAndValues(base, keys, keys + count)
                    initializedCount = count * 2
                }
                return
            }

            unsafe self.storage = []

            guard count > 0 else { return }

            unsafe withUnsafeMutablePointer(to: &inlineStorage) { storage in
                unsafe storage.withMemoryRebound(
                    to: UnsafeRawPointer?.self,
                    capacity: Self.inlineCapacity * 2
                ) { keys in
                    unsafe CFDictionaryGetKeysAndValues(base, keys, keys + count)
                }
            }
        }

        @inlinable
        public mutating func next() -> Element? {
            let position = position
            let count = count

            guard position < count else { return nil }

            let keyPointer: UnsafeRawPointer?
            let valuePointer: UnsafeRawPointer?

            if count <= Self.inlineCapacity {
                unsafe (keyPointer, valuePointer) = withUnsafePointer(to: &inlineStorage) {
                    unsafe $0.withMemoryRebound(
                        to: UnsafeRawPointer?.self,
                        capacity: Self.inlineCapacity * 2
                    ) {
                        unsafe ($0[position], $0[count + position])
                    }
                }
            } else {
                unsafe (keyPointer, valuePointer) = (storage[position], storage[count + position])
            }

            // Neither is `nil`: a dictionary of objects holds no null key or value, and the
            // storage was filled with `count` of each. Each is lent, not claimed, as an element
            // of an array is and for the same reason: the dictionary keeps them alive.
            let key = unsafe Unmanaged<AnyObject>.fromOpaque(keyPointer!)
            let value = unsafe Unmanaged<AnyObject>.fromOpaque(valuePointer!)

            self.position = position + 1

            return (
                key: unsafe key._withUnsafeGuaranteedRef {
                    CoreFoundationValue(element: $0, checked: checksElements)
                },
                value: unsafe value._withUnsafeGuaranteedRef {
                    CoreFoundationValue(element: $0, checked: checksElements)
                }
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
