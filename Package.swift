// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CacheAdvance",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v5),
        .macOS(.v10_14),
    ],
    products: [
        .library(
            name: "CacheAdvance",
            targets: ["CacheAdvance"]),
    ],
    targets: [
        .target(
            name: "CacheAdvance",
            dependencies: ["SwiftTryCatch"],
            swiftSettings: [.define("SWIFT_PACKAGE_MANAGER")]
        ),
        .testTarget(
            name: "CacheAdvanceTests",
            dependencies: ["CacheAdvance"]),
        .target(
            name: "SwiftTryCatch",
            dependencies: [],
            publicHeadersPath: "./",
            // Make Objective-C exceptions not leak, since we can now recover from them.
            // For more info, see https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions
            swiftSettings: [SwiftSetting.define("-fobjc-arc-exceptions")]
        ),
        .testTarget(
            name: "SwiftTryCatchTests",
            dependencies: ["SwiftTryCatch"])
    ],
    swiftLanguageVersions: [.v5]
)
