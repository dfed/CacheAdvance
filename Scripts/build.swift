#!/usr/bin/env swift

import Foundation

// Usage: build.swift sdk destination should_test?

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

guard CommandLine.arguments.count > 3 else {
    print("Usage: build.swift sdk destination should_test?")
    throw TaskError.code(1)
}

try execute(commandPath: "/usr/bin/swift", arguments: ["package", "generate-xcodeproj", "--output=generated/"])

let sdk = CommandLine.arguments[1]
let destination = CommandLine.arguments[2]
let shouldTest = CommandLine.arguments.count > 3 ? Bool(CommandLine.arguments[3]) ?? false : false

var xcodeBuildArguments = [
    "-project", "generated/CacheAdvance.xcodeproj",
    "-scheme", "CacheAdvance-Package",
    "-sdk", sdk,
    "-configuration", "Release",
    "-PBXBuildsContinueAfterErrors=0",
]
if !destination.isEmpty {
    xcodeBuildArguments.append("-destination")
    xcodeBuildArguments.append(destination)
}
xcodeBuildArguments.append("build")
if shouldTest {
    xcodeBuildArguments.append("test")
}

try execute(commandPath: "/usr/bin/xcodebuild", arguments: xcodeBuildArguments)
