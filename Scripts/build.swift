#!/usr/bin/env swift

import Foundation

// Usage: build.swift platforms

func execute(commandPath: String, arguments: [String]) throws {
	let task = Process()
	task.executableURL = .init(filePath: commandPath)
	task.arguments = arguments
	print("Launching command: \(commandPath) \(arguments.joined(separator: " "))")
	try task.run()
	task.waitUntilExit()
	guard task.terminationStatus == 0 else {
		throw TaskError.code(task.terminationStatus)
	}
}

enum TaskError: Error {
	case code(Int32)
}

enum Platform: String, CaseIterable, CustomStringConvertible {
	case iOS_18
	case tvOS_18
	case macOS_15
	case macCatalyst_15
	case watchOS_11
	case visionOS_2

	var destination: String {
		switch self {
		case .iOS_18:
			"platform=iOS Simulator,OS=18.0,name=iPad (10th generation)"
		case .tvOS_18:
			"platform=tvOS Simulator,OS=18.0,name=Apple TV"
		case .tvOS_18:
			"platform=tvOS Simulator,OS=18,name=Apple TV"

		case .macOS_15,
		     .macCatalyst_15:
			"platform=OS X"

		case .watchOS_11:
			"OS=11.0,name=Apple Watch Series 10 (46mm)"
		case .visionOS_2:
			"OS=2.0,name=Apple Vision Pro"
		}
	}

	var sdk: String {
		switch self {
		case .iOS_18:
			"iphonesimulator"

		case .tvOS_18:
			"appletvsimulator"

		case .macOS_15,
		     .macCatalyst_15:
			"macosx15.0"

		case .watchOS_11:
			"watchsimulator"

		case .visionOS_2:
			"xrsimulator"
		}
	}

	var derivedDataPath: String {
		".build/derivedData/" + description
	}

	var description: String {
		rawValue
	}
}

guard CommandLine.arguments.count > 1 else {
	print("Usage: build.swift platforms")
	throw TaskError.code(1)
}

let rawPlatforms = CommandLine.arguments[1].components(separatedBy: ",")

var isFirstRun = true
for rawPlatform in rawPlatforms {
	guard let platform = Platform(rawValue: rawPlatform) else {
		print("Received unknown platform type \(rawPlatform)")
		print("Possible platform types are: \(Platform.allCases)")
		throw TaskError.code(1)
	}

	var xcodeBuildArguments = [
		"-scheme", "CacheAdvance",
		"-sdk", platform.sdk,
		"-derivedDataPath", platform.derivedDataPath,
		"-PBXBuildsContinueAfterErrors=0",
		"OTHER_SWIFT_FLAGS=-warnings-as-errors",
	]
	if !platform.destination.isEmpty {
		xcodeBuildArguments.append("-destination")
		xcodeBuildArguments.append(platform.destination)
	}
	xcodeBuildArguments.append("-enableCodeCoverage")
	xcodeBuildArguments.append("YES")
	xcodeBuildArguments.append("build")
	xcodeBuildArguments.append("test")

	try execute(commandPath: "/usr/bin/xcodebuild", arguments: xcodeBuildArguments)
	isFirstRun = false
}
