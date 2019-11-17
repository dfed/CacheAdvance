//
//  Created by Dan Federman on 11/10/19.
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

extension FileHandle {

    // MARK: Internal

    /// Returns the next encodable message, seeking to the beginning of the next message.
    func nextEncodedMessage(cacheOverwritesOldMessages: Bool) throws -> Data? {
        let startingOffset = offsetInFile
        switch try nextEncodedMessageSpan(cacheOverwritesOldMessages: cacheOverwritesOldMessages) {
        case let .span(messageLength):
            let message = try __readDataUp(toLength: Int(messageLength))
            guard message.count > 0 else {
                throw CacheAdvanceReadError.fileCorrupted
            }

            return message

        case let .endOfNewestMessageMarker(offsetOfFirstMessage):
            // Seek to the oldest message.
            try seek(toOffset: offsetOfFirstMessage)
            // The next message is now the oldest.
            return nil

        case .emptyRead:
            // Seek back to the beginning of the file.
            try seek(toOffset: 0)

            if startingOffset != 0 {
                // We hit an empty read at the end of the file.
                // We know there's a message to read now that we're at the start of the file.
                return try nextEncodedMessage(cacheOverwritesOldMessages: cacheOverwritesOldMessages)
            }
            return nil

        case .invalidFormat:
            throw CacheAdvanceReadError.fileCorrupted
        }
    }

    /// Seeks just ahead of the newest message in the file.
    /// - Parameter cacheOverwritesOldMessages: When `true`,  the cache encodes a pointer to the oldest message after the newest message marker.
    func seekToEndOfNewestMessage(cacheOverwritesOldMessages: Bool) throws {
        while try seekToNextMessage(shouldSeekToOldestMessageIfFound: false, cacheOverwritesOldMessages: cacheOverwritesOldMessages) {}
    }

    /// Seeks to the beginning of the oldest message in the file.
    /// - Parameter cacheOverwritesOldMessages: When `true`,  the cache encodes a pointer to the oldest message after the newest message marker.
    func seekToBeginningOfOldestMessage(cacheOverwritesOldMessages: Bool) throws {
        if cacheOverwritesOldMessages {
            while try seekToNextMessage(shouldSeekToOldestMessageIfFound: true, cacheOverwritesOldMessages: true) {}
        } else {
            // The oldest message is always at the beginning of the cache.
            try seek(toOffset: 0)
        }
    }

    /// Seeks to the next message. Returns `true` when the span skipped represented a message.
    /// When `false` is returned, it signifies that the last message marker was passed.
    ///
    /// - Parameters:
    ///   - shouldSeekToOldestMessageIfFound: When `true`, the file handle will seek to the oldest message if the last message marker is pased.
    ///   - cacheOverwritesOldMessages: When `true`,  the cache encodes a pointer to the oldest message after the newest message marker.
    @discardableResult
    func seekToNextMessage(shouldSeekToOldestMessageIfFound: Bool, cacheOverwritesOldMessages: Bool) throws -> Bool {
        let startingOffset = offsetInFile
        switch try nextEncodedMessageSpan(cacheOverwritesOldMessages: cacheOverwritesOldMessages) {
        case let .endOfNewestMessageMarker(offsetOfNextMessage):
            // We found the last message!
            if shouldSeekToOldestMessageIfFound {
                // Seek to it.
                try seek(toOffset: offsetOfNextMessage)
            } else {
                // Seek back to where we started.
                try seek(toOffset: startingOffset)
            }
            return false

        case .emptyRead:
            // The remaining file is empty.
            if shouldSeekToOldestMessageIfFound {
                // The oldest message is at the beginning of the file.
                try seek(toOffset: 0)
            } else {
                // Seek back to where we started.
                try seek(toOffset: startingOffset)
            }
            return false

        case let .span(messageLength):
            // There's a valid message here. Seek ahead of it.
            try seek(toOffset: offsetInFile + UInt64(messageLength))
            return true

        case .invalidFormat:
            throw CacheAdvanceReadError.fileCorrupted
        }
    }

    // MARK: Private

    /// Returns the next encoded message span, seeking to the end the span.
    private func nextEncodedMessageSpan(cacheOverwritesOldMessages: Bool) throws -> NextMessageSpan {
        let messageSizeData = try __readDataUp(toLength: Data.messageSpanLength)

        guard messageSizeData.count > 0 else {
            // We haven't written anything to this file yet, or we've reached the end of the file.
            return .emptyRead
        }

        guard messageSizeData != Data.endOfNewestMessageMarker else {
            // We have reached the most recently written message.
            if cacheOverwritesOldMessages {
                // We have a span marking the offset of the oldest message.
                let offsetOfFirstMessageData = try __readDataUp(toLength: Data.offsetOfOldestMessageLength)
                guard let offsetOfFirstMessage = Bytes(offsetOfFirstMessageData) else {
                    // The file is improperly formatted.
                    return .invalidFormat
                }
                return .endOfNewestMessageMarker(offsetOfFirstMessage: offsetOfFirstMessage)

            } else {
                // The first message is always at the beginning of the file.
                return .endOfNewestMessageMarker(offsetOfFirstMessage: 0)
            }
        }

        guard let messageSize = MessageSpan(messageSizeData) else {
            // The file is improperly formatted.
            return .invalidFormat
        }

        return .span(messageSize)
    }

}

private enum NextMessageSpan {
    case span(MessageSpan)
    case emptyRead
    case endOfNewestMessageMarker(offsetOfFirstMessage: Bytes)
    case invalidFormat
}
