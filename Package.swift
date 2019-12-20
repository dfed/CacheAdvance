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
            dependencies: ["SwiftTryCatch"]
        ),
        .testTarget(
            name: "CacheAdvanceTests",
            dependencies: ["CacheAdvance"]),
        .target(
            name: "SwiftTryCatch",
            dependencies: [],
            publicHeadersPath: "./",
            swiftSettings: [SwiftSetting.define("-fobjc-arc-exceptions")]
        ),
        .testTarget(
            name: "SwiftTryCatchTests",
            dependencies: ["SwiftTryCatch"])
    ],
    swiftLanguageVersions: [.v5]
)
let version = Version(0, 0, 2)
