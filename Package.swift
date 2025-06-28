// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "CacheAdvance",
	platforms: [
		.iOS(.v15),
		.tvOS(.v15),
		.watchOS(.v7),
		.macOS(.v11),
		.macCatalyst(.v15),
	],
	products: [
		.library(
			name: "CacheAdvance",
			targets: ["CacheAdvance"]
		),
	],
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
			name: "LorumIpsum",
			dependencies: [],
			swiftSettings: [
				.swiftLanguageMode(.v6),
			]
		),
	]
)
