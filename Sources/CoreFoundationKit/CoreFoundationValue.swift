//
//  CoreFoundationValue.swift
//  CoreFoundationKit
//

public import CoreFoundation
internal import Foundation
public import ObjectiveC

/// An object, told apart by its CoreFoundation type ID.
///
/// The frameworks that deal in `CFDictionary` and `CFTypeRef` — property lists, the keychain,
/// IOKit — hand back a small set of CoreFoundation types and expect the reader to work out which
/// one it got. A Swift cast cannot answer that. A cast to a CoreFoundation type is not checked at
/// all, so `as? CFString` succeeds for any object; and a cast to the Swift type is too permissive,
/// since every number is an `NSNumber`, booleans included, and `NSNumber(value: 1) as? Bool`
/// succeeds. The type ID is the one question that tells them apart, and this is where it is asked.
///
/// That is all this does. What a number becomes, how a collection is walked, and whether an object
/// of some other type is an error or something to carry along are each reader's own to decide, and
/// each payload is the CoreFoundation type so that nothing has been decided for it: bridge with
/// `as` to the Foundation or Swift type from there.
public enum CoreFoundationValue {
    case string(CFString)
    /// A `CFBoolean`, which is one of two objects, as the value it stands for.
    case boolean(Bool)
    case number(CFNumber)
    case data(CFData)
    case date(CFDate)
    case array(CFArray)
    case dictionary(CFDictionary)
    /// An object of any other type, CoreFoundation's or not, carried through untouched.
    case other(CFTypeRef)
}

extension CoreFoundationValue {
    /// Tells apart an object that came from CoreFoundation, or from a framework built on it.
    ///
    /// One switch settles the type, and each branch then takes the object as that type without
    /// asking again. There is nothing a checked cast would add: the runtime does not compare type
    /// IDs for a cast to a CoreFoundation type, so `as!` succeeds for any object — but it still
    /// calls into the runtime to find that out, which measured as about two percent of reading a
    /// property list. The type ID just asked for is the check.
    ///
    /// The type IDs are asked for by function rather than written down. CoreFoundation registers
    /// most of them the first time they are asked for, and none of the numbers is a promise.
    ///
    /// - Parameter object: An object `CFGetTypeID` can be asked about. That is every object but a
    ///   proxy — see ``init(untrusted:)`` for one whose origin is not known.
    @inlinable
    public init(_ object: CFTypeRef) {
        switch CFGetTypeID(object) {
        case CFStringGetTypeID():
            self = .string(unsafe unsafeDowncast(object, to: CFString.self))
        case CFBooleanGetTypeID():
            self = .boolean(object === kCFBooleanTrue)
        case CFNumberGetTypeID():
            self = .number(unsafe unsafeDowncast(object, to: CFNumber.self))
        case CFDataGetTypeID():
            self = .data(unsafe unsafeDowncast(object, to: CFData.self))
        case CFDateGetTypeID():
            self = .date(unsafe unsafeDowncast(object, to: CFDate.self))
        case CFArrayGetTypeID():
            self = .array(unsafe unsafeDowncast(object, to: CFArray.self))
        case CFDictionaryGetTypeID():
            self = .dictionary(unsafe unsafeDowncast(object, to: CFDictionary.self))
        default:
            self = .other(object)
        }
    }

    /// Tells apart an object of unknown origin, or returns `nil` for one that cannot be asked.
    ///
    /// `CFGetTypeID` answers for a CoreFoundation object itself and sends every other one
    /// `_cfTypeID`, which `NSObject` and Swift's own root class implement and `NSProxy` does not:
    /// a proxy forwards the message or raises, and either way an object a caller handed over
    /// would bring the process down rather than be turned away. Asking the object anything —
    /// `is NSObject` is `isKindOfClass:` — would be forwarded just the same. The runtime answers
    /// for the class without a message being sent, and the question is the one `CFGetTypeID` is
    /// about to depend on.
    ///
    /// An object a framework returned needs none of this; ``init(_:)`` reads it directly.
    ///
    /// - Parameter object: Any object at all.
    @inlinable
    public init?(untrusted object: AnyObject) {
        guard
            class_respondsToSelector(
                object_getClass(object),
                #selector(getter: (any _CoreFoundationTypeIdentifiable)._cfTypeID)
            )
        else {
            return nil
        }

        self.init(object)
    }
}

/// What `CFGetTypeID` sends an object that is not CoreFoundation's own. No header declares it;
/// CoreFoundation implements it for `NSObject` in its `__NSCFType` category, and the Swift runtime
/// for the root class of its own objects.
///
/// Nothing conforms to this. It is declared so that the selector can be named with `#selector`,
/// which the linker resolves once: a selector built from a string is registered on every call, and
/// one kept in a static is fetched through an accessor that inlined code has to call into this
/// module for.
@objc
@usableFromInline
protocol _CoreFoundationTypeIdentifiable {
    @objc var _cfTypeID: CFTypeID { get }
}
