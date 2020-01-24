//
//  Created by Dan Federman on 12/26/19.
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

public final class CacheReader {

    // MARK: Initialization

    /// Creates a new instance of the receiver.
    ///
    /// - Parameter fileURL: The file URL indicating the desired location of the on-disk store. This file should already exist.
    public init(fileURL: URL)
        throws
    {
        reader = try FileHandle(forReadingFrom: fileURL)
        // Make up numbers for maximumBytes and overwritesOldMessages. They aren't necessary for reading.
        header = try CacheHeaderHandle(
            forReadingFrom: fileURL,
            maximumBytes: 0,
            overwritesOldMessages: false)
    }

    /// Creates a new instance of the receiver.
    ///
    /// - Parameter header: The header for the cache the reader will read from.
    init(forCacheWith header: CacheHeaderHandle) throws {
        reader = try FileHandle(forReadingFrom: header.fileURL)
        self.header = header
    }

    deinit {
        try? reader.closeHandle()
    }

    // MARK: Public

    /// Fetches all messages from the cache.
    public func messages<T: Decodable>() throws -> [T] {
        try setUpIfNecessary()

        var messages = [T]()
        while let encodedMessage = try nextEncodedMessage() {
            messages.append(try decoder.decode(T.self, from: encodedMessage))
        }

        // Now that we've read all messages, seek back to the oldest message.
        try seekToBeginningOfOldestMessage()

        return messages
    }

    // MARK: Internal

    var offsetInFileOfOldestMessage: UInt64 = 0
    var offsetInFileAtEndOfNewestMessage: UInt64 = 0

    var offsetInFile: UInt64 {
        reader.offsetInFile
    }

    /// Returns the next encodable message, seeking to the beginning of the next message.
    func nextEncodedMessage() throws -> Data? {
        try setUpIfNecessary()

        let startingOffset = offsetInFile

        guard startingOffset != offsetInFileAtEndOfNewestMessage else {
            // We're at the last message.
            return nil
        }

        switch try nextEncodedMessageSpan() {
        case let .span(messageLength):
            let message = try reader.readDataUp(toLength: Int(messageLength))
            guard message.count > 0 else {
                throw CacheAdvanceError.fileCorrupted
            }

            return message

        case .emptyRead:
            // We know the next message is at the end of the file header. Let's seek to it.
            try reader.seek(to: FileHeader.expectedEndOfHeaderInFile)

            // We know there's a message to read now that we're at the start of the file.
            return try nextEncodedMessage()

        case .invalidFormat:
            throw CacheAdvanceError.fileCorrupted
        }
    }

    /// Seeks to the beginning of the oldest message in the file.
    func seekToBeginningOfOldestMessage() throws {
        try setUpIfNecessary()

        try reader.seek(to: offsetInFileOfOldestMessage)
    }

    /// Seeks to the next message. Returns `true` when the span skipped represented a message.
    func seekToNextMessage() throws {
        try setUpIfNecessary()

        switch try nextEncodedMessageSpan() {
        case let .span(messageLength):
            // There's a valid message here. Seek ahead of it.
            try reader.seek(to: offsetInFile + UInt64(messageLength))

        case .emptyRead:
            // We hit an empty read. Seek to the next message.
            try reader.seek(to: FileHeader.expectedEndOfHeaderInFile)

        case .invalidFormat:
            throw CacheAdvanceError.fileCorrupted
        }
    }

    // MARK: Private

    /// Returns the next encoded message span, seeking to the end the span.
    private func nextEncodedMessageSpan() throws -> NextMessageSpan {
        try setUpIfNecessary()

        let messageSizeData = try reader.readDataUp(toLength: MessageSpan.storageLength)

        guard messageSizeData.count > 0 else {
            // We haven't written anything to this file yet, or we've reached the end of the file.
            return .emptyRead
        }

        guard messageSizeData.count == MessageSpan.storageLength else {
            // The file is improperly formatted.
            return .invalidFormat
        }

        return .span(MessageSpan(messageSizeData))
    }

    private func setUpIfNecessary() throws {
        guard offsetInFileOfOldestMessage == 0 && offsetInFileAtEndOfNewestMessage == 0 else {
            // We've already set up our header.
            return
        }

        // Read our header data.
        try header.synchronizeHeaderData()

        // Update ourselves with data from the header
        offsetInFileOfOldestMessage = header.offsetInFileOfOldestMessage
        offsetInFileAtEndOfNewestMessage = header.offsetInFileAtEndOfNewestMessage

        // Seek to the oldest message.
        try seekToBeginningOfOldestMessage()
    }

    private let reader: FileHandle
    private let header: CacheHeaderHandle
    private let decoder = JSONDecoder()

}

private enum NextMessageSpan {
    case span(MessageSpan)
    case emptyRead
    case invalidFormat
}
