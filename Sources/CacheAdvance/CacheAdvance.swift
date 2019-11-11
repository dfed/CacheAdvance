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

/// A performant on-disk cache that supports appending one element at a time.
/// This cache is intended to be written from and appended to from the same serial queue.
public final class CacheAdvance<T: Codable> {

    // MARK: Initialization

    /// Creates a new instance of the receiver.
    /// - Parameters:
    ///   - file: The file URL indicating the desired location of the on-disk store. This file should already exist.
    ///   - maximumBytes: The maximum size of the cache, in bytes. Logs larger than this size will fail to append to the store.
    ///   - shouldOverwriteOldMessages: When `true`, once the on-disk store exceeds maximumBytes, new entries will replace the oldest entry.
    public init(
        file: URL,
        maximumBytes: Bytes,
        shouldOverwriteOldMessages: Bool)
        throws
    {
        self.file = file
        self.maximumBytes = maximumBytes
        self.shouldOverwriteOldMessages = shouldOverwriteOldMessages

        writer = try FileHandle(forWritingTo: file)
        reader = try FileHandle(forReadingFrom: file)

        lengthOfMessageSuffix = {
            if shouldOverwriteOldMessages {
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
    public func append(message: T) throws {
        try setUpFileHandlesIfNecessary()

        let encodedMessage = EncodableMessage(message: message, encoder: encoder)
        let messageData = try encodedMessage.encodedData()
        let cacheHasSpaceForNewMessage = writer.offsetInFile + Bytes(messageData.count) + lengthOfMessageSuffix <= maximumBytes
        if cacheHasSpaceForNewMessage {
            try write(messageData: messageData)

        } else if shouldOverwriteOldMessages {
            // Trim the file to the current position.
            try writer.truncate(atOffset: writer.offsetInFile)

            // Set the offset back to the beginning of the file.
            try writer.seek(toOffset: 0)

            // We know the oldest message is at the beginning of the file, since we just tossed out the rest of the file.
            try reader.seek(toOffset: 0)
            // We know we're about to overwrite the oldest message, so advance the reader to the next message.
            try reader.seekToNextMessage(shouldSeekToOldestMessageIfFound: false, cacheOverwritesOldMessages: true)

            // Start writing from the beginning of the file.
            try write(messageData: messageData)

        } else {
            // We're out of room.
            throw CacheAdvanceWriteError.messageDataTooLarge
        }
    }

    /// Fetches all messages from the cache.
    public func cachedMessages() throws -> [T] {
        try setUpFileHandlesIfNecessary()

        var messages = [T]()
        while let encodedMessage = try reader.nextEncodedMessage(cacheOverwritesOldMessages: shouldOverwriteOldMessages) {
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
        try reader.seekToEndOfNewestMessage(cacheOverwritesOldMessages: shouldOverwriteOldMessages)
        try writer.seek(toOffset: reader.offsetInFile)

        // Now that we know where to write, we need to figure out where the oldest message is.
        try reader.seekToBeginningOfOldestMessage(cacheOverwritesOldMessages: shouldOverwriteOldMessages)

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

        while shouldOverwriteOldMessages
            && writer.offsetInFile < reader.offsetInFile
            && reader.offsetInFile < writer.offsetInFile + messageLength
        {
            // We are a rolling cache. The current position of the writer is before the oldest message,
            // and writing this message would write into the current message. Advance to the next message.
            try reader.seekToNextMessage(shouldSeekToOldestMessageIfFound: true, cacheOverwritesOldMessages: shouldOverwriteOldMessages)
        }

        try writer.__write(messageData, error: ())
        let endOfMessageOffset = writer.offsetInFile

        // Write the end of newest message marker.
        try writer.__write(Data.endOfNewestMessageMarker, error: ())

        if shouldOverwriteOldMessages {
            try writer.__write(Data(Bytes(reader.offsetInFile)), error: ())
        }

        // Back the file handle's offset back to the end of the message we just wrote.
        // This way the next time we write a message, we'll overwrite the last message marker.
        try writer.seek(toOffset: endOfMessageOffset)
    }

    private let writer: FileHandle
    private let reader: FileHandle

    private var hasSetUpFileHandles = false
    private let shouldOverwriteOldMessages: Bool

    private let maximumBytes: Bytes
    private let lengthOfMessageSuffix: Bytes

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
}
