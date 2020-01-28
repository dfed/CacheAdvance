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

    let maximumBytes: Bytes
    let overwritesOldMessages: Bool
    private(set) var offsetInFileOfOldestMessage: UInt64
    private(set) var offsetInFileAtEndOfNewestMessage: UInt64

    func updateOffsetInFileOfOldestMessage(to offset: UInt64) throws {
        offsetInFileOfOldestMessage = offset

        // Seek to the beginning of this field in the header.
        try handle.seek(to: CacheHeaderHandle.beginningOfHeaderField_offsetInFileOfOldestMessage)

        // Write this updated value to disk.
        try handle.write(data: expectedHeader.data(for: .offsetInFileOfOldestMessage))
    }

    func updateOffsetInFileAtEndOfNewestMessage(to offset: UInt64) throws {
        offsetInFileAtEndOfNewestMessage = offset

        // Seek to the beginning of this field in the header.
        try handle.seek(to: CacheHeaderHandle.beginningOfHeaderField_offsetInFileAtEndOfNewestMessage)

        // Write this updated value to disk.
        try handle.write(data: expectedHeader.data(for: .offsetInFileAtEndOfNewestMessage))
    }

    /// Checks if the expected header version matches the persisted header version.
    ///
    /// - Returns: `true` if this object's header version matches that of `fileHeader`; otherwise `false`.
    func canOpenFile() throws -> Bool {
        canOpenFile(with: try memoizedMetadata())
    }

    /// Checks if the all the header metadata provided at initialization matches the persisted header.
    ///
    /// - Returns: `true` if this object's static metadata matches that of the persisted `fileHeader`; otherwise `false`.
    func canWriteToFile() throws -> Bool {
        canWriteToFile(with: try memoizedMetadata())
    }

    /// Reads the header data from the file. Writes header information to disk if no header exists.
    /// If the header data persisted to the file is not consistent with expectations, the file will be deleted.
    func synchronizeHeaderData() throws {
        let headerData = try readHeaderData()

        guard !headerData.isEmpty else {
            // The file is empty. Write a header to disk.
            let writtenHeader = try writeHeaderData()
            persistedMetadata = Metadata(fileHeader: writtenHeader)
            return
        }

        guard let fileHeader = FileHeader(from: headerData) else {
            // We can't read the header data.
            throw CacheAdvanceError.fileCorrupted
        }

        let persistedMetadata = Metadata(fileHeader: fileHeader)
        guard canOpenFile(with: persistedMetadata) else {
            return
        }

        self.persistedMetadata = persistedMetadata
        offsetInFileOfOldestMessage = fileHeader.offsetInFileOfOldestMessage
        offsetInFileAtEndOfNewestMessage = fileHeader.offsetInFileAtEndOfNewestMessage
    }

    // MARK: Private

    private let handle: FileHandle
    private let version: UInt8

    private var persistedMetadata: Metadata?

    private var expectedHeader: FileHeader {
        FileHeader(
            version: version,
            maximumBytes: maximumBytes,
            overwritesOldMessages: overwritesOldMessages,
            offsetInFileOfOldestMessage: offsetInFileOfOldestMessage,
            offsetInFileAtEndOfNewestMessage: offsetInFileAtEndOfNewestMessage)
    }

    /// Attempts to read the header data of the file.
    ///
    /// - Returns: As much of the header data as exists. The returned data may not form a complete header.
    private func readHeaderData() throws -> Data {
        // Start at the beginning of the file.
        try handle.seek(to: 0)

        // Read the entire header.
        return try handle.readDataUp(toLength: Int(FileHeader.expectedEndOfHeaderInFile))
    }

    /// Checks if the expected header version matches the persisted header version.
    ///
    /// - Parameter persistedMetadata: The persisted header metadata.
    /// - Returns: `true` if this object's header version matches that of `fileHeader`; otherwise `false`.
    private func canOpenFile(with persistedMetadata: Metadata) -> Bool {
        // Our current file header version is 1.
        // That means there is only one header version we can understand.
        // Our header version must be our expected version for us to open the file successfully.
        persistedMetadata.version == version
    }

    /// Checks if the all the header metadata provided at initialization matches the persisted header.
    ///
    /// - Parameter persistedMetadata: The persisted header metadata.
    /// - Returns: `true` if this object's static metadata matches that of the persisted `fileHeader`; otherwise `false`.
    private func canWriteToFile(with persistedMetadata: Metadata) -> Bool {
        guard canOpenFile(with: persistedMetadata) else {
            // If we can't open the file, we can't write to it.
            return false
        }

        return persistedMetadata.maximumBytes == maximumBytes
            && persistedMetadata.overwritesOldMessages == overwritesOldMessages
    }

    /// Writes header data to the file.
    private func writeHeaderData() throws -> FileHeader {
        let header = expectedHeader

        // Seek to the beginning of the file before writing the header.
        try handle.seek(to: 0)

        // Write the header to disk.
        try handle.write(data: header.asData)

        return header
    }

    private func memoizedMetadata() throws -> Metadata {
        if let persistedMetadata = self.persistedMetadata {
            return persistedMetadata
        } else {
            return try Metadata(headerData: try readHeaderData())
        }
    }

    private static let beginningOfHeaderField_offsetInFileOfOldestMessage = FileHeader.Field.offsetInFileOfOldestMessage.expectedBeginningOfFieldInFile
    private static let beginningOfHeaderField_offsetInFileAtEndOfNewestMessage = FileHeader.Field.offsetInFileAtEndOfNewestMessage.expectedBeginningOfFieldInFile

    // MARK: Metadata

    /// A snapshot of data read from a persisted file header.
    private struct Metadata {

        // MARK: Initialization

        init(fileHeader: FileHeader) {
            version = fileHeader.version
            maximumBytes = fileHeader.maximumBytes
            overwritesOldMessages = fileHeader.overwritesOldMessages
        }

        init(headerData: Data) throws {
            guard let fileHeader = FileHeader(from: headerData) else {
                // We can't read the header data.
                throw CacheAdvanceError.fileCorrupted
            }
            self = .init(fileHeader: fileHeader)
        }

        // MARK: Properties

        let version: UInt8
        let maximumBytes: UInt64
        let overwritesOldMessages: Bool
    }
}
