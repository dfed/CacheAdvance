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

final class CacheReader {

    // MARK: Initialization

    /// Creates a new instance of the receiver.
    ///
    /// - Parameters:
    ///   - file: The file URL indicating the desired location of the on-disk store. This file should already exist.
    ///   - overwriteOldMessages: When `true`,  the cache encodes a pointer to the oldest message after the newest message marker.
    init(forReadingFrom file: URL, overwriteOldMessages: Bool) throws {
        reader = try FileHandle(forReadingFrom: file)
        self.overwriteOldMessages = overwriteOldMessages
    }

    deinit {
        try? reader.closeHandle()
    }

    // MARK: Internal

    var offsetInFileOfOldestMessage: UInt64 = 0

    var offsetInFile: UInt64 {
        reader.offsetInFile
    }

    /// Returns the next encodable message, seeking to the beginning of the next message.
    func nextEncodedMessage() throws -> Data? {
        let startingOffset = offsetInFile
        switch try nextEncodedMessageSpan() {
        case let .span(messageLength):
            let message = try reader.readDataUp(toLength: Int(messageLength))
            guard message.count > 0 else {
                throw CacheAdvanceReadError.fileCorrupted
            }

            return message

        case .endOfNewestMessageMarker:
            // Seek to the oldest message.
            try reader.seek(to: offsetInFileOfOldestMessage)
            // The next message is now the oldest.
            return nil

        case .emptyRead:
            // We've encountered an empty read rather than a marker for the end of a newest message.
            // This means we're in a cache that doesn't overwrite old messages. We know the next
            // message is at the end of the file header. Let's seek to it.
            try reader.seek(to: FileHeader.expectedEndOfHeaderInFile)

            if startingOffset != FileHeader.expectedEndOfHeaderInFile {
                // We hit an empty read at the end of the file.
                // We know there's a message to read now that we're at the start of the file.
                return try nextEncodedMessage()
            }
            return nil

        case .invalidFormat:
            throw CacheAdvanceReadError.fileCorrupted
        }
    }

    /// Seeks to the beginning of the oldest message in the file.
    func seekToBeginningOfOldestMessage() throws {
        try reader.seek(to: offsetInFileOfOldestMessage)
    }

    /// Seeks to the next message. Returns `true` when the span skipped represented a message.
    /// When `false` is returned, it signifies that the last message marker was passed.
    @discardableResult
    func seekToNextMessage() throws -> Bool {
        switch try nextEncodedMessageSpan() {
        case .endOfNewestMessageMarker,
             .emptyRead:
            // The remaining file is empty, or we've hit the end of our messages.
            // The next message is at the beginning of the file.
            try reader.seek(to: FileHeader.expectedEndOfHeaderInFile)
            return false

        case let .span(messageLength):
            // There's a valid message here. Seek ahead of it.
            try reader.seek(to: offsetInFile + UInt64(messageLength))
            return true

        case .invalidFormat:
            throw CacheAdvanceReadError.fileCorrupted
        }
    }

    // MARK: Private

    /// Returns the next encoded message span, seeking to the end the span.
    private func nextEncodedMessageSpan() throws -> NextMessageSpan {
        let messageSizeData = try reader.readDataUp(toLength: MessageSpan.storageLength)

        guard messageSizeData.count > 0 else {
            // We haven't written anything to this file yet, or we've reached the end of the file.
            return .emptyRead
        }

        guard messageSizeData != MessageSpan.endOfNewestMessageMarker else {
            // We have reached the most recently written message.
            return .endOfNewestMessageMarker
        }

        guard let messageSize = MessageSpan(messageSizeData) else {
            // The file is improperly formatted.
            return .invalidFormat
        }

        return .span(messageSize)
    }

    // MARK: Private

    private let reader: FileHandle
    private let overwriteOldMessages: Bool

}

private enum NextMessageSpan {
    case span(MessageSpan)
    case emptyRead
    case endOfNewestMessageMarker
    case invalidFormat
}
