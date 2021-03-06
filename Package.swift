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
            targets: ["CacheAdvance"]
        ),
        .library(
            name: "CADCacheAdvance",
            targets: ["CADCacheAdvance"]
        )
    ],
    targets: [
        .target(
            name: "CacheAdvance",
            dependencies: ["SwiftTryCatch"],
            swiftSettings: [.define("SWIFT_PACKAGE_MANAGER")]
        ),
        .testTarget(
            name: "CacheAdvanceTests",
            dependencies: ["CacheAdvance", "LorumIpsum"]
        ),
        .target(
            name: "CADCacheAdvance",
            dependencies: ["CacheAdvance"],
            swiftSettings: [.define("SWIFT_PACKAGE_MANAGER")]
        ),
        .target(
            name: "LorumIpsum",
            dependencies: []
        ),
        .testTarget(
            name: "CADCacheAdvanceTests",
            dependencies: ["CADCacheAdvance", "LorumIpsum"]
        ),
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
            dependencies: ["SwiftTryCatch"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
