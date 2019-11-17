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

/// A cache that enables the performant persistence of individual messages to disk.
/// This cache is intended to be written to and read from using the same serial queue.
public final class CacheAdvance<T: Codable> {

    // MARK: Initialization

    /// Creates a new instance of the receiver.
    ///
    /// - Parameters:
    ///   - file: The file URL indicating the desired location of the on-disk store. This file should already exist.
    ///   - maximumBytes: The maximum size of the cache, in bytes. Logs larger than this size will fail to append to the store.
    ///   - shouldOverwriteOldMessages: When `true`, once the on-disk store exceeds maximumBytes, new entries will replace the oldest entry.
    ///
    /// - Warning: `maximumBytes` must be consistent for the life of a cache. Changing this value after logs have been persisted to a cache leads to undefined behavior.
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
                /// The message suffix requires space for both `endOfNewestMessageMarker` and `offsetOfFirstMessage` after each message when rolling is enabled.
                return Bytes(Data.endOfNewestMessageMarker.count) + Bytes(Data.offsetOfFirstMessageLength)
            } else {
                /// The message suffix requires space for `endOfNewestMessageMarker` after each message.
                return Bytes(Data.endOfNewestMessageMarker.count)
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
    /// - Parameter message: A message to write to disk. The message must not be empty.
    public func append(message: T) throws {
        try setUpFileHandlesIfNecessary()

        let encodedMessage = EncodableMessage(message: message, encoder: encoder)
        let messageData = try encodedMessage.encodedData()
        let messageLength = bytesNeededToStore(messageData: messageData)
        guard messageLength <= maximumBytes && messageLength < Bytes(MessageSpan.max) else {
            // The message is too long to be written to a cache of this size.
            throw CacheAdvanceWriteError.messageDataTooLarge
        }

        guard messageLength > 0 else {
            /// The message length has the same value as as our `endOfNewestMessageMarker`.
            throw CacheAdvanceWriteError.messageDataEmpty
        }

        let cacheHasSpaceForNewMessageWithoutOverwriting = writer.offsetInFile + messageLength <= maximumBytes
        if cacheHasSpaceForNewMessageWithoutOverwriting {
            if shouldOverwriteOldMessages {
                try prepareReaderForWriting(dataOfLength: messageLength)
            }
            try write(messageData: messageData)

        } else if shouldOverwriteOldMessages {
            // Trim the file to the current position.
            try writer.truncate(atOffset: writer.offsetInFile)

            // Set the offset back to the beginning of the file.
            try writer.seek(toOffset: 0)

            // We know the oldest message is at the beginning of the file, since we just tossed out the rest of the file.
            try reader.seek(toOffset: 0)

            // We know we're about to overwrite the oldest message, so advance the reader to the second oldest message.
            try reader.seekToNextMessage(shouldSeekToOldestMessageIfFound: false, cacheOverwritesOldMessages: true)

            // Prepare the reader before writing the message.
            try prepareReaderForWriting(dataOfLength: messageLength)

            // Write the message.
            try write(messageData: messageData)

        } else {
            // We're out of room.
            throw CacheAdvanceWriteError.messageDataTooLarge
        }
    }

    /// Fetches all messages from the cache.
    public func messages() throws -> [T] {
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

    private func prepareReaderForWriting(dataOfLength messageLength: Bytes) throws {
        // Advance the reader until there is room to store the new message without writing past the reader.
        while writer.offsetInFile < reader.offsetInFile
            && reader.offsetInFile < writer.offsetInFile + messageLength
        {
            // The current position of the writer is before the oldest message, which means that
            // writing this message would write into the current message. Advance to the next message.
            try reader.seekToNextMessage(shouldSeekToOldestMessageIfFound: true, cacheOverwritesOldMessages: true)
        }
    }

    /// Writes message data to the cache.
    ///
    /// For caches that do not overwrite old messages, the message data is written in the following format:
    /// `[messageData][endOfNewestMessageMarker]`
    /// - `messageData` is an `EncodableMessage`'s encoded data.
    /// - `endOfNewestMessageMarker` is a big-endian encoded `MessageSpan` of length `messageSpanLength`.
    ///
    /// For caches that overwrite old messages, the message data is written in the following format:
    /// `[messageData][endOfNewestMessageMarker][offsetInFileOfOldestMessage]`
    /// - `messageData` is an `EncodableMessage`'s encoded data.
    /// - `endOfNewestMessageMarker` is a big-endian encoded `MessageSpan` of length `messageSpanLength`.
    /// - `offsetInFileOfOldestMessage` is a big-endian encoded `Bytes` of length `offsetOfFirstMessageLength`.
    ///
    /// By the time this method returns, the `writer`'s `offsetInFile` is always set to the
    /// beginning of the written `endOfNewestMessageMarker`, such that the next message
    /// written will overwrite the marker.
    ///
    /// - Parameter messageData: an `EncodableMessage`'s encoded data. Must be smaller than both `maximumBytes` and `MessageSpan.max`.
    private func write(messageData: Data) throws {
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

    /// Calculates the number of bytes needed to write this data to disk.
    /// - Parameter messageData: The message data in question.
    private func bytesNeededToStore(messageData: Data) -> Bytes {
        return Bytes(messageData.count) + lengthOfMessageSuffix
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
