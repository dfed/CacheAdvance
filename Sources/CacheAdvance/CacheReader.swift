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
    /// - Parameter file: The file URL indicating the desired location of the on-disk store. This file should already exist.
    init(forReadingFrom file: URL) throws {
        reader = try FileHandle(forReadingFrom: file)
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

    /// Returns the encodable messages in a range
    ///
    /// - Parameter startOffset: the offset from which to start reading
    /// - Parameter endOffset: the offset at which to stop reading. If `nil`, the end offset will be the EOF
    func encodedMessagesFromOffset(_ startOffset: UInt64, endOffset: UInt64? = nil) throws -> [Data] {
        var encodedMessages = [Data]()
        try reader.seek(to: startOffset)
        while let data = try nextEncodedMessage() {
            encodedMessages.append(data)
            if let endOffset = endOffset {
                if offsetInFile == endOffset {
                    break
                } else if offsetInFile > endOffset {
                    // The messages on disk are out of sync with our header data.
                    throw CacheAdvanceError.fileCorrupted
                }
            }
        }
        if let endOffset = endOffset, offsetInFile != endOffset {
            // If we finished reading messages but our offset in the file is less (or greater) than our expected ending offset, our header data is incorrect.
            throw CacheAdvanceError.fileCorrupted
        }
        return encodedMessages
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

    /// Returns the next encodable message, seeking to the beginning of the next message.
    private func nextEncodedMessage() throws -> Data? {
        switch try nextEncodedMessageSpan() {
        case let .span(messageLength):
            let message = try reader.readDataUp(toLength: Int(messageLength))
            guard message.count > 0 else {
                throw CacheAdvanceError.fileCorrupted
            }

            return message

        case .emptyRead:
            // An empty read means we hit the EOF. It is the responsibility of the calling code to validate this assumption.
            return nil

        case .invalidFormat:
            throw CacheAdvanceError.fileCorrupted
        }
    }

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

}

private enum NextMessageSpan {
    case span(MessageSpan)
    case emptyRead
    case invalidFormat
}
