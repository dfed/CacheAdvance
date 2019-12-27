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

final class CacheHeaderHandle {

    // MARK: Initialization

    /// Creates a new instance of the receiver.
    ///
    /// - Parameters:
    ///   - file: The file URL indicating the desired location of the on-disk store. This file should already exist.
    ///   - maximumBytes: The maximum size of the cache, in bytes. Logs larger than this size will fail to append to the store.
    ///   - overwritesOldMessages: When `true`,  the cache encodes a pointer to the oldest message after the newest message marker.
    init(forReadingFrom file: URL, maximumBytes: Bytes, overwritesOldMessages: Bool) throws {
        handle = try FileHandle(forUpdating: file)
        self.maximumBytes = maximumBytes
        self.overwritesOldMessages = overwritesOldMessages
        offsetInFileOfOldestMessage = FileHeader.expectedEndOfHeaderInFile
        offsetInFileAtEndOfNewestMessage = FileHeader.expectedEndOfHeaderInFile
    }

    deinit {
        try? handle.closeHandle()
    }

    // MARK: Internal

    private(set) var offsetInFileOfOldestMessage: UInt64
    private(set) var offsetInFileAtEndOfNewestMessage: UInt64

    func updateOffsetInFileOfOldestMessage(to offset: UInt64) throws {
        offsetInFileOfOldestMessage = offset
        try writeHeaderData()
    }

    func updateOffsetInFileAtEndOfNewestMessage(to offset: UInt64) throws {
        offsetInFileAtEndOfNewestMessage = offset
        try writeHeaderData()
    }

    /// Reads the header data from the file.
    func readHeaderData() throws {
        // Start at the beginning of the file.
        try handle.seek(to: 0)

        // Read the version of the header.
        let headerVersionData = try handle.readDataUp(toLength: UInt8.storageLength)

        if headerVersionData.isEmpty {
            // There is no header. Create a header to write to disk.
            try writeHeaderData()

        } else {
            guard
                let headerVersion = UInt8(headerVersionData),
                headerVersion == FileHeader.version
                else
            {
                // Our current file header version is 1.
                // That means there is no prior header version we could attempt to read.
                // We have no idea how to read this file. Nuke it.
                try handle.truncate(at: 0)

                // Now that we've started from scratch, write a new header.
                try writeHeaderData()
                return
            }

            // Read the maximum number of bytes in this cache.
            let maximumBytesData = try handle.readDataUp(toLength: UInt64.storageLength)
            // Read whether we overwrite old messages.
            let overwritesOldMessagesData = try handle.readDataUp(toLength: Bool.storageLength)
            // Read the offset in file of the oldest message.
            let offsetInFileOfOldestMessageData = try handle.readDataUp(toLength: UInt64.storageLength)
            // Read the offset in file at the end of the newest message.
            let offsetInFileAtEndOfNewestMessageData = try handle.readDataUp(toLength: UInt64.storageLength)

            guard
                let maximumBytes = Bytes(maximumBytesData),
                maximumBytes == self.maximumBytes,
                let overwritesOldMessages = Bool(overwritesOldMessagesData),
                overwritesOldMessages == self.overwritesOldMessages,
                let offsetInFileOfOldestMessage = UInt64(offsetInFileOfOldestMessageData),
                let offsetInFileAtEndOfNewestMessage = UInt64(offsetInFileAtEndOfNewestMessageData)
                else
            {
                // The header's values are not consistent with our expectations.
                // We have no idea how to read this file. Nuke it.
                try handle.truncate(at: 0)

                // Now that we've started from scratch, write a new header.
                try writeHeaderData()
                return
            }

            self.offsetInFileOfOldestMessage = offsetInFileOfOldestMessage
            self.offsetInFileAtEndOfNewestMessage = offsetInFileAtEndOfNewestMessage
        }
    }

    // MARK: Private

    private let handle: FileHandle
    private let overwritesOldMessages: Bool
    private let maximumBytes: Bytes

    /// Writes header data to the file and returns the info.
    private func writeHeaderData() throws {
        // Seek to the beginning of the file before writing the header.
        try handle.seek(to: 0)

        // Create the header.
        let header = FileHeader(
            maximumBytes: maximumBytes,
            overwritesOldMessages: overwritesOldMessages,
            offsetInFileOfOldestMessage: offsetInFileOfOldestMessage,
            offsetInFileAtEndOfNewestMessage: offsetInFileAtEndOfNewestMessage)

        // Write the header to disk.
        try handle.write(data: header.asData)
    }
}
