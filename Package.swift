// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CacheAdvance",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15),
        .macCatalyst(.v13),
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
    ]
)
