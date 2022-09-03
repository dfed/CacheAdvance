#!/usr/bin/env swift

import Foundation

// Usage: build.swift platforms

func execute(commandPath: String, arguments: [String]) throws {
    let task = Process()
    task.launchPath = commandPath
    task.arguments = arguments
    print("Launching command: \(commandPath) \(arguments.joined(separator: " "))")
    task.launch()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else {
        throw TaskError.code(task.terminationStatus)
    }
}

enum TaskError: Error {
    case code(Int32)
}

enum Platform: String, CaseIterable, CustomStringConvertible {
    case iOS_13
    case iOS_14
    case iOS_15
    case tvOS_13
    case tvOS_14
    case tvOS_15
    case macOS_10_15
    case macOS_11
    case macOS_12
    case watchOS_6
    case watchOS_7
    case watchOS_8

    var destination: String {
        switch self {
        case .iOS_13:
            return "platform=iOS Simulator,OS=13.7,name=iPad Pro (12.9-inch) (4th generation)"
        case .iOS_14:
            return "platform=iOS Simulator,OS=14.4,name=iPad Pro (12.9-inch) (4th generation)"
        case .iOS_15:
            return "platform=iOS Simulator,OS=15.5,name=iPad Pro (12.9-inch) (5th generation)"

        case .tvOS_13:
            return "platform=tvOS Simulator,OS=13.4,name=Apple TV"
        case .tvOS_14:
            return "platform=tvOS Simulator,OS=14.3,name=Apple TV"
        case .tvOS_15:
            return "platform=tvOS Simulator,OS=15.4,name=Apple TV"

        case .macOS_10_15,
             .macOS_11,
             .macOS_12:
            return "platform=OS X"

        case .watchOS_6:
            return "OS=6.2.1,name=Apple Watch Series 4 - 44mm"
        case .watchOS_7:
            return "OS=7.2,name=Apple Watch Series 6 - 44mm"
        case .watchOS_8:
            return "OS=8.5,name=Apple Watch Series 6 - 44mm"
        }
    }

    var sdk: String {
        switch self {
        case .iOS_13,
             .iOS_14,
             .iOS_15:
            return "iphonesimulator"

        case .tvOS_13,
             .tvOS_14,
             .tvOS_15:
            return "appletvsimulator"

        case .macOS_10_15:
            return "macosx10.15"
        case .macOS_11:
            return "macosx11.1"
        case .macOS_12:
            return "macosx12.3"

        case .watchOS_6,
             .watchOS_7,
             .watchOS_8:
            return "watchsimulator"
        }
    }

    var shouldTest: Bool {
        switch self {
        case .iOS_13,
             .iOS_14,
             .iOS_15,
             .tvOS_13,
             .tvOS_14,
             .tvOS_15,
             .macOS_10_15,
             .macOS_11,
             .macOS_12:
            return true

        case .watchOS_6,
             .watchOS_7,
             .watchOS_8:
            // watchOS does not support unit testing (yet?).
            return false
        }
    }

    var shouldGenerateXcodeproj: Bool {
        switch self {
        case .iOS_13,
             .iOS_14,
             .tvOS_13,
             .tvOS_14,
             .macOS_10_15,
             .macOS_11,
             .watchOS_6,
             .watchOS_7:
            return true

        case .iOS_15,
             .tvOS_15,
             .macOS_12,
             .watchOS_8:
            // Xcode 13 does not require xcodeproj generation
            return false
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

    if isFirstRun && platform.shouldGenerateXcodeproj {
        // Generate the xcode project if we need it
        try execute(commandPath: "/usr/bin/swift", arguments: ["package", "generate-xcodeproj", "--output=generated/"])

        // The generate-xcodeproj command has a bug where the test deployment target is above the minimum deployment target for the project. Fix it with sed.
        try execute(commandPath: "/usr/bin/sed", arguments: ["-i", "-e", "s/IPHONEOS_DEPLOYMENT_TARGET = \"14.0\"/IPHONEOS_DEPLOYMENT_TARGET = \"12.0\"/g", "generated/CacheAdvance.xcodeproj/project.pbxproj"])
        try execute(commandPath: "/usr/bin/sed", arguments: ["-i", "-e", "s/TVOS_DEPLOYMENT_TARGET = \"14.0\"/TVOS_DEPLOYMENT_TARGET = \"12.0\"/g", "generated/CacheAdvance.xcodeproj/project.pbxproj"])
        try execute(commandPath: "/usr/bin/sed", arguments: ["-i", "-e", "s/WATCHOS_DEPLOYMENT_TARGET = \"7.0\"/WATCHOS_DEPLOYMENT_TARGET = \"5.0\"/g", "generated/CacheAdvance.xcodeproj/project.pbxproj"])
        try execute(commandPath: "/usr/bin/sed", arguments: ["-i", "-e", "s/MACOSX_DEPLOYMENT_TARGET = \"11.0\"/MACOSX_DEPLOYMENT_TARGET = \"11.0\"/g", "generated/CacheAdvance.xcodeproj/project.pbxproj"])
    }

    var xcodeBuildArguments = [
        "-scheme", "CacheAdvance-Package",
        "-sdk", platform.sdk,
        "-derivedDataPath", platform.derivedDataPath,
        "-PBXBuildsContinueAfterErrors=0"
    ]
    if platform.shouldGenerateXcodeproj {
        // Point at the generated project
        xcodeBuildArguments.append("-project")
        xcodeBuildArguments.append("generated/CacheAdvance.xcodeproj")
        // Set the configuration to be release – this configuration is not supported when running xcodebuild without a xcodeproj file.
        xcodeBuildArguments.append("-configuration")
        xcodeBuildArguments.append("Release")
        // Set a compiler flag to enable a xcodeproj-specific build flag.
        xcodeBuildArguments.append("OTHER_CFLAGS='-DGENERATED_XCODE_PROJECT'")
    }
    if !platform.destination.isEmpty {
        xcodeBuildArguments.append("-destination")
        xcodeBuildArguments.append(platform.destination)
    }
    if platform.shouldTest {
        xcodeBuildArguments.append("-enableCodeCoverage")
        xcodeBuildArguments.append("YES")
    }
    xcodeBuildArguments.append("build")
    if platform.shouldTest {
        xcodeBuildArguments.append("test")
    }

    try execute(commandPath: "/usr/bin/xcodebuild", arguments: xcodeBuildArguments)
    isFirstRun = false
}
