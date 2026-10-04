//
//  CoreFoundationValueTests.swift
//  CoreFoundationKit
//

import CoreFoundation
import CoreFoundationKit
import Foundation
import Testing

private enum Kind {
    case string
    case boolean
    case number
    case data
    case date
    case array
    case dictionary
    case other
}

extension CoreFoundationValue {
    fileprivate var kind: Kind {
        switch self {
        case .string: .string
        case .boolean: .boolean
        case .number: .number
        case .data: .data
        case .date: .date
        case .array: .array
        case .dictionary: .dictionary
        case .other: .other
        }
    }
}

@Suite
struct CoreFoundationValueTests {
    @Test
    func tellsEachTypeApart() {
        #expect(CoreFoundationValue(NSString(string: "text")).kind == .string)
        #expect(CoreFoundationValue(kCFBooleanTrue).kind == .boolean)
        #expect(CoreFoundationValue(NSNumber(value: 1)).kind == .number)
        #expect(CoreFoundationValue(NSData(data: Data([1, 2, 3]))).kind == .data)
        #expect(CoreFoundationValue(NSDate(timeIntervalSinceReferenceDate: 0)).kind == .date)
        #expect(CoreFoundationValue(NSArray(array: [1, 2])).kind == .array)
        #expect(CoreFoundationValue(NSDictionary(dictionary: ["key": 1])).kind == .dictionary)
    }

    // The payload is the object that was handed in, not a copy of it.
    @Test
    func carriesTheObjectItWasGiven() {
        let string = NSString(string: "text")
        let number = NSNumber(value: 1.5)

        guard
            case .string(let stringValue) = CoreFoundationValue(string),
            case .number(let numberValue) = CoreFoundationValue(number)
        else {
            Issue.record("A string and a number were read as something else")
            return
        }

        #expect(stringValue === string)
        #expect(stringValue as String == "text")
        #expect(numberValue === number)
        #expect(CFNumberIsFloatType(numberValue))
    }

    // The reason to ask for a type ID at all: every one of these is an `NSNumber`, and a Swift
    // cast takes any of them for a `Bool` or an `Int` alike.
    @Test
    func tellsABooleanFromANumber() {
        guard
            case .boolean(true) = CoreFoundationValue(true as NSNumber),
            case .boolean(false) = CoreFoundationValue(NSNumber(value: false))
        else {
            Issue.record("A boolean was read as something else")
            return
        }

        #expect(CoreFoundationValue(NSNumber(value: 1)).kind == .number)
        #expect(CoreFoundationValue(NSNumber(value: 0)).kind == .number)
        // The same spelling as a boolean in `objCType`, and still a number.
        #expect(CoreFoundationValue(NSNumber(value: Int8(1))).kind == .number)
    }

    // Swift values a caller built by hand cross into objects of Swift's own classes, not
    // Foundation's, and each still answers with the type ID of what it bridges to.
    @Test
    func readsABridgedSwiftValue() {
        let string = String(repeating: "core foundation ", count: 8)

        #expect(CoreFoundationValue(string as AnyObject).kind == .string)
        #expect(CoreFoundationValue(true as AnyObject).kind == .boolean)
        #expect(CoreFoundationValue(1 as AnyObject).kind == .number)
        #expect(CoreFoundationValue(1.5 as AnyObject).kind == .number)
        #expect(CoreFoundationValue(Data([1, 2, 3]) as AnyObject).kind == .data)
        #expect(CoreFoundationValue(Date() as AnyObject).kind == .date)
        #expect(CoreFoundationValue([1, 2] as AnyObject).kind == .array)
        #expect(CoreFoundationValue(["key": 1] as AnyObject).kind == .dictionary)
    }

    private final class NotAnNSObject {}

    @Test
    func carriesAnyOtherObjectThrough() {
        #expect(isCarriedThrough(NSNull()))
        #expect(isCarriedThrough(NSSet(array: [1])))
        #expect(isCarriedThrough(NSObject()))
        #expect(isCarriedThrough(NotAnNSObject()))
    }

    private func isCarriedThrough(_ object: AnyObject) -> Bool {
        guard case .other(let value) = CoreFoundationValue(object) else { return false }

        return value === object
    }

    // Turning a proxy away must not turn away anything else.
    @Test
    func readsAnObjectOfUnknownOrigin() {
        #expect(CoreFoundationValue(untrusted: NSString(string: "text"))?.kind == .string)
        #expect(CoreFoundationValue(untrusted: "text" as AnyObject)?.kind == .string)
        #expect(CoreFoundationValue(untrusted: true as AnyObject)?.kind == .boolean)
        #expect(CoreFoundationValue(untrusted: [1, 2] as AnyObject)?.kind == .array)
        #expect(CoreFoundationValue(untrusted: NSObject())?.kind == .other)
        #expect(CoreFoundationValue(untrusted: NotAnNSObject())?.kind == .other)
    }

#if os(macOS)
    // A proxy answers what it is asked by forwarding it, and one that will not forward a message
    // raises instead. `CFGetTypeID` asks an object that is not CoreFoundation's own, so a proxy
    // has to be turned away before that question rather than by it. Anything short of that does
    // not fail this test; it ends the process.
    //
    // macOS alone, because `NSProtocolChecker` is: no other platform's Foundation has it, and
    // `NSProxy` cannot be subclassed from Swift to stand in for it, having no initializer to call.
    // What is tested is one line the other Apple platforms compile unchanged.
    @Test
    func turnsAProxyAwayWithoutSendingItAMessage() {
        let proxy = NSProtocolChecker(target: NSObject(), protocol: (any NSObjectProtocol).self)

        #expect(CoreFoundationValue(untrusted: proxy) == nil)
    }
#endif
}
