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
    func nextEncodedMessage() throws -> Data? {
        let startingOffset = offsetInFile
        switch try nextEncodedMessageSpan() {
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
                return try nextEncodedMessage()
            }
            return nil

        case .invalidFormat:
            throw CacheAdvanceReadError.fileCorrupted
        }
    }

    /// Seeks just ahead of the newest message in the file.
    func seekToEndOfNewestMessage() throws {
        while try seekToNextMessage(shouldSeekToOldestMessageIfFound: false) {}
    }

    /// Seeks to the beginning of the oldest message in the file.
    func seekToBeginningOfOldestMessage() throws {
        while try seekToNextMessage(shouldSeekToOldestMessageIfFound: true) {}
    }

    /// Seeks to the next message. Returns true the span skipped represented a message.
    /// When false is returned, it signifies that the last message marker was passed.
    /// - Parameter shouldSeekToOldestMessageIfFound: When true, the file handle will seek to the oldest message if the last message marker is pased.
    @discardableResult
    func seekToNextMessage(shouldSeekToOldestMessageIfFound: Bool) throws -> Bool {
        let startingOffset = offsetInFile
        switch try nextEncodedMessageSpan() {
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
    private func nextEncodedMessageSpan() throws -> NextMessageSpan {
        let messageSizeData = try __readDataUp(toLength: Data.messageSpanLength)

        guard messageSizeData.count > 0 else {
            // We haven't written anything to this file yet, or we've reached the end of the file.
            return .emptyRead
        }

        guard messageSizeData != Data.endOfNewestMessageMarker else {
            // We have reached the most recently written message.

            // Find out if we have a span marking the offset of the next message.
            let nextSpan = try nextEncodedMessageSpan()
            switch nextSpan {
            case let .span(offsetOfFirstMessage):
                return .endOfNewestMessageMarker(offsetOfFirstMessage: UInt64(offsetOfFirstMessage))

            case .emptyRead:
                // We're at the end of the file.
                return .endOfNewestMessageMarker(offsetOfFirstMessage: 0)

            case .endOfNewestMessageMarker, .invalidFormat:
                // There's garbage beyond the last message marker.
                // The garbage is likely a result of rolling the log file multiple times.
                // This abandoned data can be safely ignored.
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
    case endOfNewestMessageMarker(offsetOfFirstMessage: UInt64)
    case invalidFormat
}
