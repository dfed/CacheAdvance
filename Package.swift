// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CacheAdvance",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "CacheAdvance",
            targets: ["CacheAdvance"]),
    ],
    targets: [
        .target(
            name: "CacheAdvance",
            dependencies: []),
        .testTarget(
            name: "CacheAdvanceTests",
            dependencies: ["CacheAdvance"])
    ],
    swiftLanguageVersions: [.v5]
)
let version = Version(0, 0, 1)
