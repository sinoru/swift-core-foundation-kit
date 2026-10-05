//
//  CoreFoundationValueViewTests.swift
//  CoreFoundationKit
//

import CoreFoundation
import CoreFoundationKit
import Foundation
import Testing

@Suite
struct CoreFoundationValueViewTests {
    private func arrayView(_ object: AnyObject) -> CoreFoundationValue.ArrayView? {
        if case .array(let view) = CoreFoundationValue(unchecked: object) { view } else { nil }
    }

    private func dictionaryView(_ object: AnyObject) -> CoreFoundationValue.DictionaryView? {
        if case .dictionary(let view) = CoreFoundationValue(unchecked: object) { view } else { nil }
    }

    // MARK: - Numbers

    // The view is the number that was handed in, for a reader that carries it along unread.
    @Test
    func handsBackTheNumberItIsAViewOf() throws {
        let number = NSNumber(value: 1.5)

        guard case .number(let view) = CoreFoundationValue(unchecked: number) else {
            Issue.record("A number was read as something else")
            return
        }

        #expect(view.base === number)
    }

    // MARK: - Arrays

    // The elements come in the array's order, each already told apart, and each payload is the
    // object the array holds and not a copy of it.
    @Test
    func walksTheElementsOfAnArrayInOrder() throws {
        let objects: [AnyObject] = [NSString(string: "one"), NSNumber(value: 2), NSNull()]
        let array = NSArray(array: objects)
        let view = try #require(arrayView(array))

        #expect(view.base === array)
        #expect(view.count == 3)
        #expect(view.map(\.description) == ["string", "number", "other"])

        var iterator = view.makeIterator()

        guard
            case .string(let string)? = iterator.next(),
            case .number(let number)? = iterator.next(),
            case .other(let other)? = iterator.next()
        else {
            Issue.record("An element was read as something else")
            return
        }

        // Compared outside the expectations: one that is handed an `AnyObject` on either side of
        // `===` brings the compiler down.
        let areTheObjects = string === objects[0] && number.base === objects[1] && other === objects[2]
        let isAtTheEnd = iterator.next() == nil

        #expect(areTheObjects)
        #expect(isAtTheEnd)
    }

    @Test
    func walksAnEmptyArray() throws {
        let view = try #require(arrayView(NSArray()))

        #expect(view.count == 0)
        #expect(Array(view).isEmpty)
    }

    // A Swift array a caller built by hand crosses into an object of Swift's own class, which
    // answers CoreFoundation through messages rather than being read directly.
    @Test
    func walksABridgedSwiftArray() throws {
        let view = try #require(arrayView(["one", 2, 3.5] as [Any] as AnyObject))

        #expect(view.count == 3)
        #expect(view.map(\.description) == ["string", "number", "number"])
    }

    // A collection inside a collection is a view in turn, and nothing is read until it is walked.
    @Test
    func walksACollectionInsideACollection() throws {
        let view = try #require(
            arrayView(NSArray(array: [NSArray(array: ["one", "two"]), NSDictionary(dictionary: ["key": 1])]))
        )
        var iterator = view.makeIterator()

        guard
            case .array(let array)? = iterator.next(),
            case .dictionary(let dictionary)? = iterator.next()
        else {
            Issue.record("A collection was read as something else")
            return
        }

        #expect(array.map(\.description) == ["string", "string"])
        #expect(dictionary.count == 1)
    }

    // MARK: - Dictionaries

    @Test
    func walksTheKeysAndValuesOfADictionary() throws {
        let name = NSString(string: "Jane Doe")
        let age = NSNumber(value: 30)
        let objects: [String: AnyObject] = ["name": name, "age": age]
        let dictionary = NSDictionary(dictionary: objects)
        let view = try #require(dictionaryView(dictionary))
        var read = [String: CoreFoundationValue]()

        #expect(view.base === dictionary)
        #expect(view.count == 2)

        for element in view {
            guard case .string(let key) = element.key else {
                Issue.record("A key was read as something that is not a string")
                continue
            }

            read[key as String] = element.value
        }

        // Each value is the object the dictionary holds, not a copy of it.
        guard case .string(let readName)? = read["name"], case .number(let readAge)? = read["age"]
        else {
            Issue.record("A value was read as something else")
            return
        }

        #expect(read.count == 2)
        #expect(readName === name)
        #expect(readAge.base === age)
    }

    @Test
    func walksAnEmptyDictionary() throws {
        let view = try #require(dictionaryView(NSDictionary()))

        #expect(view.count == 0)
        #expect(Array(view).isEmpty)
    }

    @Test
    func walksABridgedSwiftDictionary() throws {
        let dictionary: [String: Any] = ["name": "Jane Doe", "age": 30, "height": 1.7]
        let view = try #require(dictionaryView(dictionary as AnyObject))
        var read = [String: String]()

        for element in view {
            guard case .string(let key) = element.key else {
                Issue.record("A key was read as something that is not a string")
                continue
            }

            read[key as String] = element.value.description
        }

        #expect(read == ["name": "string", "age": "number", "height": "number"])
    }

    // What a cast to `[String: Any]` cannot do: it fails for the whole dictionary, where this
    // hands the key over for the reader to judge.
    @Test
    func handsOverAKeyThatIsNotAString() throws {
        let view = try #require(
            dictionaryView(NSDictionary(dictionary: [NSNumber(value: 1): "one"]))
        )
        let element = Array(view).first

        #expect(element?.key.description == "number")
        #expect(element?.value.description == "string")
    }

    // The loop is the reader's to end, which is what the stop pointer of
    // `enumerateKeysAndObjects(_:)` was for.
    @Test
    func stopsWhereTheReaderStops() throws {
        let view = try #require(
            dictionaryView(NSDictionary(dictionary: ["a": 1, "b": 2, "c": 3, "d": 4]))
        )
        var visited = 0

        for _ in view {
            visited += 1

            if visited == 2 { break }
        }

        #expect(visited == 2)
    }

    // An iterator keeps the keys and values of a small dictionary in itself and reads a larger
    // one out to the heap, so each key has to come with its own value on either side of where
    // one gives way to the other, and well past it.
    @Test(arguments: [7, 8, 9, 64])
    func pairsEachKeyWithItsValue(count: Int) throws {
        let objects = NSMutableDictionary()

        for index in 0..<count {
            objects[NSString(string: "key \(index)")] = NSNumber(value: index)
        }

        let view = try #require(dictionaryView(NSDictionary(dictionary: objects)))

        #expect(view.count == count)
        #expect(try integersByKey(in: view) == expectedIntegersByKey(count: count))
    }

    @Test(arguments: [7, 8, 9, 64])
    func pairsEachKeyWithItsValueInABridgedSwiftDictionary(count: Int) throws {
        var dictionary = [String: Any]()

        for index in 0..<count {
            dictionary["key \(index)"] = index
        }

        let view = try #require(dictionaryView(dictionary as AnyObject))

        #expect(view.count == count)
        #expect(try integersByKey(in: view) == expectedIntegersByKey(count: count))
    }

    private func expectedIntegersByKey(count: Int) -> [String: Int64] {
        Dictionary(uniqueKeysWithValues: (0..<count).map { ("key \($0)", Int64($0)) })
    }

    private func integersByKey(
        in view: CoreFoundationValue.DictionaryView
    ) throws -> [String: Int64] {
        var read = [String: Int64]()

        for element in view {
            guard
                case .string(let key) = element.key,
                case .number(let number) = element.value,
                case .integer(let value)? = CoreFoundationValue.Number(number)
            else {
                Issue.record("A key or a value was read as something else")
                continue
            }

            read[key as String] = value
        }

        return read
    }

    // MARK: - Objects of unknown origin

    // A collection read as one of unknown origin reads its elements the same way, however deep.
    @Test
    func readsTheElementsOfACollectionOfUnknownOrigin() {
        let object = NSArray(array: [NSString(string: "one"), NSDictionary(dictionary: ["key": 1])])

        guard case .array(let view)? = CoreFoundationValue(object) else {
            Issue.record("An array was read as something else")
            return
        }

        #expect(view.map(\.description) == ["string", "dictionary"])
    }

#if os(macOS)
    // An element has no `nil` to read as, so a proxy inside a collection of unknown origin is
    // carried as an object of another type, without being sent a message. Anything short of that
    // does not fail this test; it ends the process.
    //
    // macOS alone, for the reason the test of the initializer itself is.
    @Test
    func carriesAProxyInsideACollectionWithoutSendingItAMessage() {
        let proxy = NSProtocolChecker(target: NSObject(), protocol: (any NSObjectProtocol).self)
        let nested: [Any] = [proxy]
        let keyed: [String: Any] = ["key": proxy]
        let elements: [Any] = [
            NSString(string: "one"),
            proxy,
            NSArray(array: nested),
            NSDictionary(dictionary: keyed),
        ]
        let object = NSArray(array: elements)

        guard case .array(let view)? = CoreFoundationValue(object) else {
            Issue.record("An array was read as something else")
            return
        }

        var iterator = view.makeIterator()

        guard
            case .string? = iterator.next(),
            case .other(let other)? = iterator.next(),
            case .array(let array)? = iterator.next(),
            case .dictionary(let dictionary)? = iterator.next()
        else {
            Issue.record("An element was read as something else")
            return
        }

        // Compared outside the expectations: one that is handed an `AnyObject` on either side of
        // `===` brings the compiler down.
        let isTheProxy = other === proxy
        let typeID = CoreFoundationValue.typeID(of: other)

        #expect(isTheProxy)
        #expect(typeID == nil)
        let nestedElements = array.map { $0.description }
        let keyedElements = dictionary.map { $0.value.description }

        #expect(nestedElements == ["other"])
        #expect(keyedElements == ["other"])
    }
#endif
}

extension CoreFoundationValue {
    /// The name of the case, for a test to compare.
    fileprivate var description: String {
        switch self {
        case .string: "string"
        case .boolean: "boolean"
        case .number: "number"
        case .data: "data"
        case .date: "date"
        case .array: "array"
        case .dictionary: "dictionary"
        case .other: "other"
        }
    }
}
