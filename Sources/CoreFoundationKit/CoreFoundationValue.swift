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
/// A string, data and a date are carried as the CoreFoundation type: bridge with `as` to the
/// Foundation or Swift type from there. A number and the two collections take more than a cast to
/// read, and are carried as views that read them — ``NumberView``, whose value ``Number`` reads,
/// and ``ArrayView`` and ``DictionaryView``, which are sequences of their elements, each told apart
/// as it is reached. A view costs nothing until it is asked, and hands back the object it was made
/// from as `base`. Whether an object of some other type is an error or something to carry along is
/// the reader's own to decide.
public enum CoreFoundationValue {
    /// A `CFString`.
    case string(CFString)
    /// A `CFBoolean`, which is one of two objects, as the value it stands for.
    case boolean(Bool)
    /// A `CFNumber`, of whichever numeric type it holds, which ``Number`` reads the value of.
    case number(NumberView)
    /// A `CFData`.
    case data(CFData)
    /// A `CFDate`.
    case date(CFDate)
    /// A `CFArray`, as a sequence of its elements.
    case array(ArrayView)
    /// A `CFDictionary`, as a sequence of its keys and values.
    case dictionary(DictionaryView)
    /// An object of any other type, CoreFoundation's or not, carried through untouched.
    ///
    /// An element of a collection read by ``init(_:)`` that cannot be asked for its type ID — a
    /// proxy — is one of these too, since an element has no `nil` to read as. ``typeID(of:)`` is
    /// the question to ask of the object, not `CFGetTypeID`.
    case other(CFTypeRef)
}

extension CoreFoundationValue {
    /// Creates a value from an object that came from CoreFoundation, or from a framework built
    /// on it.
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
    ///   proxy — see ``init(_:)`` for one whose origin is not known.
    @inlinable
    public init(unchecked object: CFTypeRef) {
        self.init(object, typeID: CFGetTypeID(object), checksElements: false)
    }

    /// Creates a value from an object of unknown origin, if the object can be asked for its
    /// type ID.
    ///
    /// A proxy cannot be, and reads as `nil`; ``typeID(of:)`` is where that is settled, and why.
    ///
    /// An object a framework returned needs none of this; ``init(unchecked:)`` reads it directly.
    ///
    /// - Parameter object: Any object at all.
    @inlinable
    public init?(_ object: AnyObject) {
        guard let typeID = Self.typeID(of: object) else { return nil }

        self.init(object, typeID: typeID, checksElements: true)
    }

    /// Creates a value from an element of a collection, read the way the collection was.
    ///
    /// An element of a collection of unknown origin is of unknown origin itself, and is asked for
    /// its type ID under the same guard. One that cannot be asked is carried as ``other(_:)``
    /// rather than ending the walk: the sequence has no way to say `nil` for one element, and what
    /// an object of another type means is the reader's to decide in either case.
    @inlinable
    init(element object: CFTypeRef, checked: Bool) {
        guard checked else {
            self.init(object, typeID: CFGetTypeID(object), checksElements: false)
            return
        }

        guard let typeID = Self.typeID(of: object) else {
            self = .other(object)
            return
        }

        self.init(object, typeID: typeID, checksElements: true)
    }

    /// Creates a value from an object and the type ID it has already answered with, so that
    /// neither initializer asks for it twice.
    ///
    /// A collection is told how it was read, so that its elements are read the same way.
    @inlinable
    init(_ object: CFTypeRef, typeID: CFTypeID, checksElements: Bool) {
        switch typeID {
        case CFStringGetTypeID():
            self = .string(unsafe unsafeDowncast(object, to: CFString.self))
        case CFBooleanGetTypeID():
            self = .boolean(object === kCFBooleanTrue)
        case CFNumberGetTypeID():
            self = .number(NumberView(base: unsafe unsafeDowncast(object, to: CFNumber.self)))
        case CFDataGetTypeID():
            self = .data(unsafe unsafeDowncast(object, to: CFData.self))
        case CFDateGetTypeID():
            self = .date(unsafe unsafeDowncast(object, to: CFDate.self))
        case CFArrayGetTypeID():
            self = .array(
                ArrayView(
                    base: unsafe unsafeDowncast(object, to: CFArray.self),
                    checksElements: checksElements
                )
            )
        case CFDictionaryGetTypeID():
            self = .dictionary(
                DictionaryView(
                    base: unsafe unsafeDowncast(object, to: CFDictionary.self),
                    checksElements: checksElements
                )
            )
        default:
            self = .other(object)
        }
    }
}

extension CoreFoundationValue {
    /// Returns the CoreFoundation type ID of an object of unknown origin, or `nil` if the object
    /// cannot be asked for one.
    ///
    /// For the types that are not among the cases — a `SecKey`, an `IOSurface` — this is the
    /// question to ask before comparing against that type's own `GetTypeID` function.
    ///
    /// `CFGetTypeID` answers for a CoreFoundation object itself and sends every other one
    /// `_cfTypeID`, which `NSObject` and Swift's own root class implement and `NSProxy` does not:
    /// a proxy forwards the message or raises, and either way an object a caller handed over
    /// would bring the process down rather than be turned away. Asking the object anything —
    /// `is NSObject` is `isKindOfClass:` — would be forwarded just the same. The runtime answers
    /// for the class without a message being sent, and the question is the one `CFGetTypeID` is
    /// about to depend on.
    ///
    /// An object a framework returned needs none of this; `CFGetTypeID` reads it directly.
    ///
    /// - Parameter object: Any object at all.
    @inlinable
    public static func typeID(of object: AnyObject) -> CFTypeID? {
        guard
            class_respondsToSelector(
                object_getClass(object),
                #selector(getter: (any _CoreFoundationTypeIdentifiable)._cfTypeID)
            )
        else {
            return nil
        }

        return CFGetTypeID(object)
    }
}

/// An object that answers `_cfTypeID`, the message `CFGetTypeID` sends an object that is not
/// CoreFoundation's own.
///
/// No header declares the message; CoreFoundation implements it for `NSObject` in its
/// `__NSCFType` category, and the Swift runtime for the root class of its own objects.
///
/// Nothing conforms to this. It is declared so that the selector can be named with `#selector`,
/// which the linker resolves once: a selector built from a string is registered on every call, and
/// one kept in a static is fetched through an accessor that inlined code has to call into this
/// module for.
@objc
@usableFromInline
protocol _CoreFoundationTypeIdentifiable {
    /// The CoreFoundation type ID the object answers with.
    @objc var _cfTypeID: CFTypeID { get }
}
