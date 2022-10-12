//
//  Created by Dan Federman on 4/24/20.
//  Copyright © 2020 Dan Federman.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if SWIFT_PACKAGE_MANAGER
// Swift Package Manager defines multiple modules, while other distribution mechanisms do not.
// We only need to import CacheAdvance if this project is being built with Swift Package Manager.
import CacheAdvance
#endif
import Foundation

/// A cache that enables the performant persistence of individual messages to disk.
/// This cache is intended to be written to and read from using the same serial queue.
/// - Attention: This type is meant to be used by Objective-C code, and is not exposed to Swift. Swift code should use CacheAdvance<T>.
@objc(CADCacheAdvance)
@available(swift, obsoleted: 1.0)
public final class __ObjectiveCCompatibleCacheAdvanceWithGenericData: NSObject {

    // MARK: Initialization

    /// Creates a new instance of the receiver.
    ///
    /// - Parameters:
    ///   - fileURL: The file URL indicating the desired location of the on-disk store. This file should already exist.
    ///   - maximumBytes: The maximum size of the cache, in bytes. Logs larger than this size will fail to append to the store.
    ///   - shouldOverwriteOldMessages: When `true`, once the on-disk store exceeds maximumBytes, new entries will replace the oldest entry.
    ///
    /// - Warning: `maximumBytes` must be consistent for the life of a cache. Changing this value after logs have been persisted to a cache will prevent appending new messages to this cache.
    /// - Warning: `shouldOverwriteOldMessages` must be consistent for the life of a cache. Changing this value after logs have been persisted to a cache will prevent appending new messages to this cache.
    @objc
    public init(
        fileURL: URL,
        maximumBytes: Bytes,
        shouldOverwriteOldMessages: Bool)
        throws
    {
        cache = try CacheAdvance<Data>(
            fileURL: fileURL,
            maximumBytes: maximumBytes,
            shouldOverwriteOldMessages: shouldOverwriteOldMessages,
            decoder: PassthroughDataDecoder(),
            encoder: PassthroughDataEncoder())
    }

    // MARK: Public

    @objc
    public var fileURL: URL {
        cache.fileURL
    }

    /// Checks if the all the header metadata provided at initialization matches the persisted header. If not, the cache is not writable.
    /// - Returns: `true` if the cache is writable.
    @objc
    public var isWritable: Bool {
        (try? cache.isWritable()) ?? false
    }

    /// Appends a message to the cache.
    /// - Parameter message: A message to write to disk. Must be smaller than both `maximumBytes - FileHeader.expectedEndOfHeaderInFile` and `MessageSpan.max`.
    @objc
    public func appendMessage(_ message: Data) throws {
        try cache.append(message: message)
    }

    /// - Returns: `true` when there are no messages written to the file, or when the file can not be read.
    @objc
    public var isEmpty: Bool {
        (try? cache.isEmpty()) ?? true
    }

    /// Fetches all messages from the cache.
    @objc
    public func messages() throws -> [Data] {
        try cache.messages()
    }

    // MARK: Private

    private let cache: CacheAdvance<Data>
}

// MARK: - PassthroughDataDecoder

/// A decoder that treats all messages as if they are `Data`.
final class PassthroughDataDecoder: MessageDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        // Force cast because this type is only used with a CacheAdvance<Data> type.
        return data as! T
    }
}

// MARK: - PassthroughDataEncoder

/// A encoder that treats all messages as if they are `Data`.
final class PassthroughDataEncoder: MessageEncoder {
    func encode<T>(_ value: T) throws -> Data where T : Encodable {
        // Force cast because this type is only used with a CacheAdvance<Data> type.
        return value as! Data
    }
}
