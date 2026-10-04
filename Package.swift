// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .strictMemorySafety(),
]

let package = Package(
    name: "CoreFoundationKit",
    // Darwin alone: what this reads is the CoreFoundation the Objective-C runtime is bridged to,
    // and no other platform has one. A package that builds elsewhere depends on this under
    // `.when(platforms:)`. The floor is the lowest of the packages that read through it.
    platforms: [
        .macOS(.v12),
        .macCatalyst(.v15),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "CoreFoundationKit",
            targets: ["CoreFoundationKit"]
        ),
    ],
    targets: [
        .target(
            name: "CoreFoundationKit",
            swiftSettings: commonSwiftSettings,
        ),
        .testTarget(
            name: "CoreFoundationKitTests",
            dependencies: ["CoreFoundationKit"],
            swiftSettings: commonSwiftSettings,
        ),
    ]
)
