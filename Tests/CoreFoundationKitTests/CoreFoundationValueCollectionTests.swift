//
//  CoreFoundationValueCollectionTests.swift
//  CoreFoundationKit
//

import CoreFoundation
import CoreFoundationKit
import Foundation
import Testing

@Suite
struct CoreFoundationValueCollectionTests {
    private typealias ArrayElements = CoreFoundationValue.ArrayElements
    private typealias DictionaryElements = CoreFoundationValue.DictionaryElements

    // MARK: - Arrays

    // The elements are the objects the array holds, in its order, and not copies of them.
    @Test
    func walksTheElementsOfAnArrayInOrder() {
        let objects: [AnyObject] = [NSString(string: "one"), NSNumber(value: 2), NSNull()]
        let elements = ArrayElements(NSArray(array: objects))

        #expect(elements.count == 3)
        #expect(elements.elementsEqual(objects, by: ===))
        #expect(elements[1] === objects[1])
        #expect(elements.last === objects[2])
    }

    @Test
    func walksAnEmptyArray() {
        let elements = ArrayElements(NSArray())

        #expect(elements.isEmpty)
        #expect(Array(elements).isEmpty)
    }

    // A Swift array a caller built by hand crosses into an object of Swift's own class, which
    // answers CoreFoundation through messages rather than being read directly.
    @Test
    func walksABridgedSwiftArray() {
        let elements = ArrayElements(["one", 2, 3.5] as [Any] as CFArray)

        #expect(
            elements.map { CoreFoundationValue(unchecked: $0).description }
                == ["string", "number", "number"]
        )
        #expect(elements[0] as? String == "one")
        #expect(elements[1] as? Int == 2)
        #expect(elements[2] as? Double == 3.5)
    }

    // MARK: - Dictionaries

    @Test
    func walksTheKeysAndValuesOfADictionary() {
        let name = NSString(string: "Jane Doe")
        let age = NSNumber(value: 30)
        let objects: [String: AnyObject] = ["name": name, "age": age]
        let elements = DictionaryElements(NSDictionary(dictionary: objects))
        var read = [String: AnyObject]()

        #expect(elements.count == 2)

        for element in elements {
            guard case .string(let key) = CoreFoundationValue(unchecked: element.key) else {
                Issue.record("A key was read as something that is not a string")
                continue
            }

            read[key as String] = element.value
        }

        // Each value is the object the dictionary holds, not a copy of it.
        #expect(read.count == 2)
        #expect(read["name"] === name)
        #expect(read["age"] === age)
    }

    @Test
    func walksAnEmptyDictionary() {
        let elements = DictionaryElements(NSDictionary())

        #expect(elements.isEmpty)
        #expect(Array(elements).isEmpty)
    }

    @Test
    func walksABridgedSwiftDictionary() {
        let dictionary: [String: Any] = ["name": "Jane Doe", "age": 30, "height": 1.7]
        let elements = DictionaryElements(dictionary as CFDictionary)
        var read = [String: String]()

        for (key, value) in elements {
            read[key as! String] = CoreFoundationValue(unchecked: value).description
        }

        #expect(read == ["name": "string", "age": "number", "height": "number"])
    }

    // What a cast to `[String: Any]` cannot do: it fails for the whole dictionary, where this
    // hands the key over for the reader to judge.
    @Test
    func handsOverAKeyThatIsNotAString() {
        let elements = DictionaryElements(NSDictionary(dictionary: [NSNumber(value: 1): "one"]))
        let element = elements.first

        #expect(element.map { CoreFoundationValue(unchecked: $0.key).description } == "number")
        #expect(element?.value as? String == "one")
    }

    // The loop is the reader's to end, which is what the stop pointer of
    // `enumerateKeysAndObjects(_:)` was for.
    @Test
    func stopsWhereTheReaderStops() {
        let dictionary = NSDictionary(dictionary: ["a": 1, "b": 2, "c": 3, "d": 4])
        var visited = 0

        for _ in DictionaryElements(dictionary) {
            visited += 1

            if visited == 2 { break }
        }

        #expect(visited == 2)
    }
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
