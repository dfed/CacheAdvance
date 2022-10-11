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
    ///   - maximumBytes: The maximum size of the cache, in bytes. Logs larger than this size will fail to append to the store.
    init(forReadingFrom file: URL, maximumBytes: Bytes) throws {
        reader = try FileHandle(forReadingFrom: file)
        self.maximumBytes = maximumBytes
    }

    deinit {
        try? reader.closeHandle()
    }

    // MARK: Internal

    var offsetInFileOfOldestMessage: UInt64 = 0
    var offsetInFileAtEndOfNewestMessage: UInt64 = 0

    var offsetInFile: UInt64 {
        reader.offsetInFile
    }

    /// Returns the next encodable message, seeking to the beginning of the next message.
    func nextEncodedMessage() throws -> Data? {
        let startingOffset = offsetInFile

        guard startingOffset != offsetInFileAtEndOfNewestMessage else {
            // We're at the last message.
            return nil
        }

        switch try nextEncodedMessageSpan() {
        case let .span(messageLength):
            // Check our assumptions before we try to read the message.
            let endOfMessage = Bytes(startingOffset) + Bytes(MessageSpan.storageLength) + Bytes(messageLength)
            let startingOffsetIsBeforeEndOfNewestMessageAndDoesNotExceedEndOfNewestMessage = startingOffset < offsetInFileAtEndOfNewestMessage && endOfMessage <= offsetInFileAtEndOfNewestMessage
            let startingOffsetIsOnOrAfterAfterEndOfNewestMessageAndDoesNotExceedEndOfFile = startingOffset >= offsetInFileAtEndOfNewestMessage && endOfMessage <= maximumBytes
            guard
                startingOffsetIsBeforeEndOfNewestMessageAndDoesNotExceedEndOfNewestMessage
                    || startingOffsetIsOnOrAfterAfterEndOfNewestMessageAndDoesNotExceedEndOfFile
            else {
                // The offsetInFileAtEndOfNewestMessage is incorrect. This likely occured due to a crash when writing our header file.
                throw CacheAdvanceError.fileCorrupted
            }

            let message = try reader.readDataUp(toLength: Int(messageLength))
            guard message.count > 0 else {
                throw CacheAdvanceError.fileCorrupted
            }

            return message

        case .emptyRead:
            guard !(startingOffset < offsetInFileAtEndOfNewestMessage) else {
                // We started reading before the offset of the end of the newest message, therefore we expect a message to be read. We instead read an empty space, meaning that the file is corrupt.
                throw CacheAdvanceError.fileCorrupted
            }

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
        try reader.seek(to: offsetInFileOfOldestMessage)
    }

    /// Seeks to the next message. Returns `true` when the span skipped represented a message.
    func seekToNextMessage() throws {
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

    private let reader: FileHandle
    private let maximumBytes: Bytes

}

private enum NextMessageSpan {
    case span(MessageSpan)
    case emptyRead
    case invalidFormat
}
