# CacheAdvance

[![CI Status](https://img.shields.io/github/actions/workflow/status/dfed/cacheadvance/ci.yml?branch=main)](https://github.com/dfed/cacheadvance/actions?query=workflow%3ACI+branch%3Amain)
[![codecov](https://codecov.io/gh/dfed/CacheAdvance/branch/main/graph/badge.svg?token=nZBHcZZ63F)](https://codecov.io/gh/dfed/CacheAdvance)
[![License](https://img.shields.io/cocoapods/l/CacheAdvance.svg)](https://cocoapods.org/pods/CacheAdvance)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdfed%2FCacheAdvance%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/dfed/CacheAdvance)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdfed%2FCacheAdvance%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/dfed/CacheAdvance)

A performant cache for logging systems. CacheAdvance persists log events 30x faster than SQLite.

## Usage

### Basic Initialization

```swift
let myCache = try CacheAdvance<MyMessageType>(
    file: FileManager.default.temporaryDirectory.appendingPathComponent("MyCache"),
    maximumBytes: 5000,
    shouldOverwriteOldMessages: false)
```

```objc
CADCacheAdvance *const cache = [[CADCacheAdvance alloc]
                                initWithFileURL:[NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:@"MyCache"]
                                maximumBytes:5000
                                shouldOverwriteOldMessages:YES
                                error:nil];
```
To begin caching messages, you need to create a CacheAdvance instance with:

* A file URL – this URL must represent a file that has already been created. You can create a file by using `FileManager`'s [createFile(atPath:contents:attributes:)](https://developer.apple.com/documentation/foundation/filemanager/1410695-createfile) API.
* A maximum number of bytes on disk the cache can consume.
* Whether the cache should overwrite old messages. If you need to preserve every message, set this value to `false`. If you care only about preserving recent messages, set this value to `true`.

### Appending messages to disk

```swift
try myCache.append(message: someMessage)
```

```objc
[cache appendMessage:someData error:nil];
```

By the time the above method exits, the message will have been persisted to disk. A CacheAdvance keeps no in-memory buffer. Appending a new message is cheap, as a CacheAdvance needs to encode and persist only the new message and associated metadata.

A CacheAdvance instance that does not overwrite old messages will throw a `CacheAdvanceError.messageDataTooLarge` if appending a message would exceed the cache's `maximumBytes`. A CacheAdvance instance that does overwrite old messages will throw a `CacheAdvanceError.messageDataTooLarge` if the message would require more than `maximumBytes` to store even after evicting all older messages from the cache.

To ensure that caches can be read from 32bit devices, messages should not be larger than 2GB in size.

### Retrieving messages from disk

```swift
let cachedMessages = try myCache.messages()
```

```objc
NSArray<NSData> *const cachedMessages = [cache messagesAndReturnError:nil];
```

This method reads all cached messages from disk into memory.

### Thread safety

CacheAdvances are not thread safe: a single CacheAdvance instance should always be interacted with from a single, serial queue. Since CacheAdvance reads from and writes to the disk synchronously, it is best to interact with a CacheAdvance on a background queue to prevent blocking the main queue.

### Error handling

A CacheAdvance will never fatal error: only recoverable errors will be thrown. A CacheAdvance may throw a `CacheAdvanceError`, or errors related to reading or writing with `FileHandle`s.

If a `CacheAdvanceError.fileCorrupted` error is thrown, the cache file is corrupt and should be deleted.

## How it works

CacheAdvance immediately persists each appended messages to disk using `FileHandle`s. Messages are encoded into `Data` using a `JSONEncoder` by default, though the encoding/decoding mechanism can be customized. Messages are written to disk as an encoded data blob that is prefixed with the length of the message. The length of a message is stored using a `UInt32` to ensure that the size of the data on disk that stores a message's length is consistent between devices.

The first 64bytes of a CacheAdvance is reserved for storing metadata about the file. Any configuration data that must be static between cache opens should be stored in this header. It is also reasonable to store mutable information in the header, if doing so speeds up reads or writes to the file. The header format is managed by [FileHeader.swift](Sources/CacheAdvance/FileHeader.swift).

## Requirements

* Xcode 12.4 or later.
* iOS 13 or later.
* tvOS 13 or later.
* watchOS 6 or later.
* macOS 10.15 or later.
* Swift 5.6 or later.

## Installation

### Swift Package Manager

To install CacheAdvance in your iOS project with [Swift Package Manager](https://github.com/apple/swift-package-manager), the following lines can be added to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/dfed/CacheAdvance", from: "2.0.0"),
]
```

### CocoaPods

To install CacheAdvance in your iOS project with [CocoaPods](http://cocoapods.org), add the following to your `Podfile`:

```
platform :ios, '13.0'
pod 'CacheAdvance', '~> 2.0'
```

### Submodules

To use git submodules, checkout the submodule with `git submodule add git@github.com:dfed/CacheAdvance.git`, drag CacheAdvance.xcodeproj to your project, and add CacheAdvance as a build dependency.

## Contributing

I’m glad you’re interested in CacheAdvance, and I’d love to see where you take it. Please read the [contributing guidelines](Contributing.md) prior to submitting a Pull Request.

Thanks, and happy caching!

## Developing

Double-click on `Package.swift` in the root of the repository to open the project in Xcode.

## Default branch

The default branch of this repository is `main`. Between the initial commit and [`151ab3f`](https://github.com/dfed/CacheAdvance/commit/151ab3f1d57531b9ae7a9219d0d8a33300704595), the default branch of this repository was `master`. See #46 for more details on why this change was made.

## Appreciations

Shout out to [Peter Westen](https://twitter.com/pwesten) who inspired the creation of this library.

Big thanks to [Michael Bachand](https://github.com/bachand) who has reviewed nearly every change to this library over the years.
