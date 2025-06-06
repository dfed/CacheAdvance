// swift-tools-version:6.0
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
		),
	].filter {
		#if os(Linux)
			$0.name != "CADCacheAdvance"
		#else
			true
		#endif
	},
	targets: [
		.target(
			name: "CacheAdvance",
			swiftSettings: [
				.swiftLanguageMode(.v6),
				.define("SWIFT_PACKAGE_MANAGER"),
			]
		),
		.testTarget(
			name: "CacheAdvanceTests",
			dependencies: ["CacheAdvance", "LorumIpsum"],
			swiftSettings: [
				.swiftLanguageMode(.v6),
			]
		),
		.target(
			name: "CADCacheAdvance",
			dependencies: ["CacheAdvance"],
			swiftSettings: [
				.swiftLanguageMode(.v6),
				.define("SWIFT_PACKAGE_MANAGER"),
			]
		),
		.target(
			name: "LorumIpsum",
			dependencies: [],
			swiftSettings: [
				.swiftLanguageMode(.v6),
			]
		),
		.testTarget(
			name: "CADCacheAdvanceTests",
			dependencies: ["CADCacheAdvance", "LorumIpsum"],
			swiftSettings: [
				.swiftLanguageMode(.v6),
			]
		),
	].filter {
		#if os(Linux)
			$0.name != "CADCacheAdvance"
				&& $0.name != "CADCacheAdvanceTests"
		#else
			true
		#endif
	}
)
