//
//  Created by Dan Federman on 11/9/19.
//  Copyright © 2019 Dan Federman.
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

import Foundation

/// A performant on-disk cache that can be appended to one element at a time.
public final class CacheAdvance<T: Codable> {

    // MARK: Initialization

    /// Creates a CacheAdvance.
    /// - Parameters:
    ///   - file: The URL for the on-disk cache to live.
    ///   - maximumBytes: The maximum size of the cache, in bytes.
    ///   - shouldRoll: When `true`, new logs will overwrite the oldest logs when the cache runs out of space.
    public init(
        file: URL,
        maximumBytes: Bytes,
        shouldRoll: Bool)
        throws
    {
        self.file = file
        self.maximumBytes = maximumBytes
        self.shouldRoll = shouldRoll

        writer = try FileHandle(forWritingTo: file)
        reader = try FileHandle(forReadingFrom: file)

        lengthOfMessageSuffix = {
            if shouldRoll {
                /// We store both the `endOfNewestMessageMarker` and `offsetInFileOfOldestMessage` after each message.
                return Bytes(Data.messageSpanLength + Data.oldestMessageOffsetLength)
            } else {
                /// We store a `endOfNewestMessageMarker` after each message.
                return Bytes(Data.messageSpanLength)
            }
        }()
    }

    deinit {
        try? writer.close()
        try? reader.close()
    }

    // MARK: Public

    public let file: URL

    /// Appends a message to the cache.
    /// - Parameter message: A message to write to disk.
    /// - Returns: Whether there was room in the cache to append the message. Always `true` for caches that roll.
    @discardableResult
    public func append(message: T) throws -> Bool {
        try setUpFileHandlesIfNecessary()

        let encodedMessage = EncodableMessage(message: message, encoder: encoder)
        let messageData = try encodedMessage.encodedData()
        let cacheHasSpaceForNewMessage = writer.offsetInFile + Bytes(messageData.count) + lengthOfMessageSuffix <= maximumBytes
        if cacheHasSpaceForNewMessage {
            try write(messageData: messageData)
            return true

        } else if shouldRoll {
            // Trim the file to the current position.
            try writer.truncate(atOffset: writer.offsetInFile)

            // Set the offset back to the beginning of the file.
            try writer.seek(toOffset: 0)

            // We know the oldest message is at the beginning of the file, since we just tossed out the rest of the file.
            try reader.seek(toOffset: 0)
            // We know we're about to overwrite the oldest message, so advance the reader to the next message.
            try reader.seekToNextMessage(shouldSeekToOldestMessageIfFound: false, cacheCanRoll: true)

            // Start writing from the beginning of the file.
            try write(messageData: messageData)
            return true

        } else {
            // We're out of room.
            return false
        }
    }

    /// Fetches all messages from the cache.
    public func cachedMessages() throws -> [T] {
        try setUpFileHandlesIfNecessary()

        var messages = [T]()
        while let encodedMessage = try reader.nextEncodedMessage(cacheCanRoll: shouldRoll) {
            messages.append(try decoder.decode(T.self, from: encodedMessage))
        }

        return messages
    }

    // MARK: Private

    /// Seeks the reader and writer file handles to the correct place.
    /// Only necessary the first time this method is called.
    private func setUpFileHandlesIfNecessary() throws {
        guard !hasSetUpFileHandles else {
            return
        }

        // This is our first cache action.
        // We need to find out where we should write our next message.
        try reader.seekToEndOfNewestMessage(cacheCanRoll: shouldRoll)
        try writer.seek(toOffset: reader.offsetInFile)

        // Now that we know where to write, we need to figure out where the oldest message is.
        try reader.seekToBeginningOfOldestMessage(cacheCanRoll: shouldRoll)

        hasSetUpFileHandles = true
    }

    /// Writes message data to the cache.
    ///
    /// For caches that do not roll, the message data is written in the following format:
    /// `[messageData][endOfNewestMessageMarker]`
    /// - `messageData` is an `EncodableMessage`'s encoded data.
    /// - `endOfNewestMessageMarker` is length `messageSpanLength`.
    ///
    /// For caches that roll, the message data is written in the following format:
    /// `[messageData][endOfNewestMessageMarker][offsetInFileOfOldestMessage]`
    /// - `messageData` is an `EncodableMessage`'s encoded data.
    /// - `endOfNewestMessageMarker` is length `messageSpanLength`.
    /// - `offsetInFileOfOldestMessage` is length `messageSpanLength`.
    ///
    /// By the time this method returns, the `writer`'s `offsetInFile` is always set to the
    /// beginning of the written `endOfNewestMessageMarker`, such that the next message
    /// written will overwrite the marker.
    ///
    /// - Parameter messageData: an `EncodableMessage`'s encoded data. Must be smaller than both `maximumBytes` and `MessageSpan.max`.
    private func write(messageData: Data) throws {
        let messageLength = Bytes(messageData.count) + lengthOfMessageSuffix
        guard messageLength <= maximumBytes && messageLength <= Bytes(MessageSpan.max) else {
            throw CacheAdvanceWriteError.messageDataTooLarge
        }

        while shouldRoll
            && writer.offsetInFile < reader.offsetInFile
            && reader.offsetInFile < writer.offsetInFile + messageLength
        {
            // We are a rolling cache. The current position of the writer is before the oldest message,
            // and writing this message would write into the current message. Advance to the next message.
            try reader.seekToNextMessage(shouldSeekToOldestMessageIfFound: true, cacheCanRoll: shouldRoll)
        }

        try writer.__write(messageData, error: ())
        let endOfMessageOffset = writer.offsetInFile

        // Write the end of newest message marker.
        try writer.__write(Data.endOfNewestMessageMarker, error: ())

        if shouldRoll {
            try writer.__write(Data(Bytes(reader.offsetInFile)), error: ())
        }

        // Back the file handle's offset back to the end of the message we just wrote.
        // This way the next time we write a message, we'll overwrite the last message marker.
        try writer.seek(toOffset: endOfMessageOffset)
    }

    private let writer: FileHandle
    private let reader: FileHandle

    private var hasSetUpFileHandles = false
    private let shouldRoll: Bool

    private let maximumBytes: Bytes
    private let lengthOfMessageSuffix: Bytes

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
}
