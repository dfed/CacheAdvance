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
    ///   - version: The file's expected header version.
    init(
        forReadingFrom file: URL,
        maximumBytes: Bytes,
        overwritesOldMessages: Bool,
        version: UInt8 = FileHeader.version)
        throws
    {
        handle = try FileHandle(forUpdating: file)
        self.maximumBytes = maximumBytes
        self.overwritesOldMessages = overwritesOldMessages
        self.version = version
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

        // Seek to the beginning of this field in the header.
        try handle.seek(to: CacheHeaderHandle.beginningOfHeaderFieldOffsetInFileOfOldestMessage)

        // Write this updated value to disk.
        try handle.write(data: currentHeader.data(for: .offsetInFileOfOldestMessage))
    }

    func updateOffsetInFileAtEndOfNewestMessage(to offset: UInt64) throws {
        offsetInFileAtEndOfNewestMessage = offset

        // Seek to the beginning of this field in the header.
        try handle.seek(to: CacheHeaderHandle.beginningOfHeaderFieldOffsetInAtEndOfNewestMessage)

        // Write this updated value to disk.
        try handle.write(data: currentHeader.data(for: .offsetInFileAtEndOfNewestMessage))
    }

    /// Reads the header data from the file. Writes header information to disk if no header exists.
    /// If the header data persisted to the file is not consistent with expectations, the file will be deleted.
    func synchronizeHeaderData() throws {
        // Start at the beginning of the file.
        try handle.seek(to: 0)

        // Read the entire header.
        let headerData = try handle.readDataUp(toLength: Int(FileHeader.expectedEndOfHeaderInFile))

        if headerData.isEmpty {
            // There is no header. Write one to disk.
            try writeHeaderData()

        } else {
            guard
                let fileHeader = FileHeader(from: headerData),
                fileHeader.version == version
                else
            {
                // Our current file header version is 1.
                // That means there is no prior header version we could attempt to read.
                // We have no idea how to read this file. Nuke it.
                try resetFile()
                return
            }

            guard
                fileHeader.maximumBytes == maximumBytes,
                fileHeader.overwritesOldMessages == overwritesOldMessages
                else
            {
                // The header's values are not consistent with our expectations. Nuke it.
                try resetFile()
                return
            }

            self.offsetInFileOfOldestMessage = fileHeader.offsetInFileOfOldestMessage
            self.offsetInFileAtEndOfNewestMessage = fileHeader.offsetInFileAtEndOfNewestMessage
        }
    }

    // MARK: Private

    private let handle: FileHandle
    private let overwritesOldMessages: Bool
    private let maximumBytes: Bytes
    private let version: UInt8

    private var currentHeader: FileHeader {
        FileHeader(
            version: version,
            maximumBytes: maximumBytes,
            overwritesOldMessages: overwritesOldMessages,
            offsetInFileOfOldestMessage: offsetInFileOfOldestMessage,
            offsetInFileAtEndOfNewestMessage: offsetInFileAtEndOfNewestMessage)
    }

    /// Writes header data to the file.
    private func writeHeaderData() throws {
        // Seek to the beginning of the file before writing the header.
        try handle.seek(to: 0)

        // Write the header to disk.
        try handle.write(data: currentHeader.asData)
    }

    private func resetFile() throws {
        try handle.truncate(at: 0)

        // Now that we've started from scratch, write a new header.
        try writeHeaderData()
    }

    private static let beginningOfHeaderFieldOffsetInFileOfOldestMessage = FileHeader.Field.offsetInFileOfOldestMessage.expectedBeginningOfFieldInFile
    private static let beginningOfHeaderFieldOffsetInAtEndOfNewestMessage = FileHeader.Field.offsetInFileAtEndOfNewestMessage.expectedBeginningOfFieldInFile
}
