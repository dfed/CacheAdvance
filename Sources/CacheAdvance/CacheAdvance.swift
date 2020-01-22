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
    /// - Warning: `maximumBytes` must be consistent for the life of a cache. Changing this value after logs have been persisted to a cache will lead to data loss.
    /// - Warning: `shouldOverwriteOldMessages` must be consistent for the life of a cache. Changing this value after logs have been persisted to a cache will lead to data loss.
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
        reader = try CacheReader(forReadingFrom: file, overwriteOldMessages: shouldOverwriteOldMessages)
        header = try CacheHeaderHandle(forReadingFrom: file, maximumBytes: maximumBytes, overwritesOldMessages: shouldOverwriteOldMessages)
    }

    deinit {
        try? writer.closeHandle()
    }

    // MARK: Public

    public let file: URL

    /// Appends a message to the cache.
    /// - Parameter message: A message to write to disk. Must be smaller than both `maximumBytes - FileHeader.expectedEndOfHeaderInFile` and `MessageSpan.max`.
    public func append(message: T) throws {
        try setUpFileHandlesIfNecessary()

        let encodableMessage = EncodableMessage(message: message, encoder: encoder)
        let messageData = try encodableMessage.encodedData()
        let bytesNeededToStoreMessage = Bytes(messageData.count)

        guard
            bytesNeededToStoreMessage <= maximumBytes - FileHeader.expectedEndOfHeaderInFile // Make sure we have room in this file for this message.
                && bytesNeededToStoreMessage < Int32.max // Make sure we can read this message back out with Int on a 32-bit device.
            else
        {
            // The message is too long to be written to a cache of this size.
            throw CacheAdvanceError.messageDataTooLarge
        }

        let cacheHasSpaceForNewMessageBeforeEndOfFile = writer.offsetInFile + bytesNeededToStoreMessage <= maximumBytes
        if shouldOverwriteOldMessages {
            if !cacheHasSpaceForNewMessageBeforeEndOfFile {
                // This message can't be written without exceeding our maximum file length.
                // We'll need to start writing the file from the beginning of the file.

                // Trim the file to the current position to remove soon-to-be-abandoned data from the file.
                try writer.truncate(at: writer.offsetInFile)

                // Set the offset back to the beginning of the file.
                try writer.seek(to: FileHeader.expectedEndOfHeaderInFile)

                // We know the oldest message is at the beginning of the file, since we just tossed out the rest of the file.
                reader.offsetInFileOfOldestMessage = FileHeader.expectedEndOfHeaderInFile
                try reader.seekToBeginningOfOldestMessage()

                // We know we're about to overwrite the oldest message, so advance the reader to the second oldest message.
                try reader.seekToNextMessage()
            }

            // Prepare the reader before writing the message.
            try prepareReaderForWriting(dataOfLength: bytesNeededToStoreMessage)

            // Create the marker for the offset representing the beginning of the message that will be the oldest once our write is done.
            let offsetInFileOfOldestMessage = UInt64(reader.offsetInFile)

            // Update the offsetInFileOfOldestMessage in our header before we write the message.
            // If the application crashes between writing the header and writing the message data, we'll have lost the messages between the previous offsetInFileOfOldestMessage and the new offsetInFileOfOldestMessage.
            try header.updateOffsetInFileOfOldestMessage(to: offsetInFileOfOldestMessage)

            // Let the reader know where the oldest message begins.
            reader.offsetInFileOfOldestMessage = offsetInFileOfOldestMessage

            // Write the message.
            try write(messageData: messageData)

        } else if cacheHasSpaceForNewMessageBeforeEndOfFile {
            // Write the message.
            try write(messageData: messageData)

        } else {
            // We're out of room.
            throw CacheAdvanceError.messageDataTooLarge
        }
    }

    /// - Returns: `true` when there are no messages written to the file.
    public func isEmpty() throws -> Bool {
        try setUpFileHandlesIfNecessary()

        return header.offsetInFileAtEndOfNewestMessage == FileHeader.expectedEndOfHeaderInFile
    }

    /// Fetches all messages from the cache.
    public func messages() throws -> [T] {
        try setUpFileHandlesIfNecessary()

        var messages = [T]()
        while let encodedMessage = try reader.nextEncodedMessage() {
            messages.append(try decoder.decode(T.self, from: encodedMessage))
        }

        // Now that we've read all messages, seek back to the oldest message.
        try reader.seekToBeginningOfOldestMessage()

        return messages
    }

    // MARK: Private

    /// Seeks the reader and writer file handles to the correct place.
    /// Only necessary the first time this method is called.
    private func setUpFileHandlesIfNecessary() throws {
        guard !hasSetUpFileHandles else {
            return
        }

        // Read our header data.
        try header.synchronizeHeaderData()

        // Update the reader with data from the header
        reader.offsetInFileOfOldestMessage = header.offsetInFileOfOldestMessage
        reader.offsetInFileAtEndOfNewestMessage = header.offsetInFileAtEndOfNewestMessage

        // This is our first cache action.
        // Seek our writer to where we should write our next message.
        try writer.seek(to: header.offsetInFileAtEndOfNewestMessage)

        // Seek our reader to the oldest message.
        try reader.seekToBeginningOfOldestMessage()

        hasSetUpFileHandles = true
    }

    /// Advances the reader until there is room to store a new message without writing past the reader.
    /// This method should only be called on a cache that overwrites old messages.
    /// - Parameter messageLength: the length of the next message that will be written.
    private func prepareReaderForWriting(dataOfLength messageLength: Bytes) throws {
        while writer.offsetInFile < reader.offsetInFile
            && reader.offsetInFile < writer.offsetInFile + messageLength
        {
            // The current position of the writer is before the oldest message, which means that writing this message would write into the current message.
            // Advance to the next message.
            try reader.seekToNextMessage()
        }
    }

    /// Writes message data to the cache.
    ///
    /// - Parameters:
    ///   - messageData: an `EncodableMessage`'s encoded data.
    private func write(messageData: Data) throws {
        // Write the message data.
        try writer.write(data: messageData)

        // Update the offsetInFileAtEndOfNewestMessage in our header and reader now that we've written the message.
        // If the application crashes between writing the message data and writing the header, we'll have lost the most recent message.
        try header.updateOffsetInFileAtEndOfNewestMessage(to: writer.offsetInFile)
        reader.offsetInFileAtEndOfNewestMessage = writer.offsetInFile
    }

    private let writer: FileHandle
    private let reader: CacheReader
    private let header: CacheHeaderHandle

    private var hasSetUpFileHandles = false
    private let shouldOverwriteOldMessages: Bool

    private let maximumBytes: Bytes

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
}
