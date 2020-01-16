//
//  Created by Dan Federman on 12/27/19.
//  Copyright © 2019 Dan Federman.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS"BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import XCTest

@testable import CacheAdvance

final class CacheHeaderHandleTests: XCTestCase {

    // MARK: XCTestCase

    override func setUp() {
        super.setUp()
        FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testFileLocation)
    }

    // MARK: Behavior Tests

    func test_synchronizeHeaderData_returnsSameVersionAsWasLastPersistedToDisk() throws {
        let headerHandle1 = try createHeaderHandle(version: 2)
        try headerHandle1.synchronizeHeaderData()
        try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1000)
        try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2000)

        let headerHandle2 = try createHeaderHandle(version: 2)
        try headerHandle2.synchronizeHeaderData()

        XCTAssertEqual(headerHandle2.offsetInFileAtEndOfNewestMessage, 1000)
        XCTAssertEqual(headerHandle2.offsetInFileOfOldestMessage, 2000)
    }

    func test_synchronizeHeaderData_returnsDefaultVersionWhenUnexpectedVersionIsOnDisk() throws {
        let headerHandle1 = try createHeaderHandle(version: 2)
        try headerHandle1.synchronizeHeaderData()
        let defaultOffsetInFileAtEndOfNewestMessage = headerHandle1.offsetInFileAtEndOfNewestMessage
        let defaultOffsetInFileOfOldestMessage = headerHandle1.offsetInFileOfOldestMessage
        try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1000)
        try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2000)

        XCTAssertNotEqual(headerHandle1.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertNotEqual(headerHandle1.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)

        let headerHandle2 = try createHeaderHandle(version: 3)
        try headerHandle2.synchronizeHeaderData()

        XCTAssertEqual(headerHandle2.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertEqual(headerHandle2.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)
    }

    func test_synchronizeHeaderData_resetsFieldsToDefaultWhenMaximumBytesIsInconsistent() throws {
        let headerHandle1 = try createHeaderHandle(maximumBytes: 5000)
        try headerHandle1.synchronizeHeaderData()
        let defaultOffsetInFileAtEndOfNewestMessage = headerHandle1.offsetInFileAtEndOfNewestMessage
        let defaultOffsetInFileOfOldestMessage = headerHandle1.offsetInFileOfOldestMessage
        try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1000)
        try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2000)

        XCTAssertNotEqual(headerHandle1.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertNotEqual(headerHandle1.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)

        let headerHandle2 = try createHeaderHandle(maximumBytes: 10000)
        try headerHandle2.synchronizeHeaderData()

        XCTAssertEqual(headerHandle2.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertEqual(headerHandle2.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)
    }

    func test_synchronizeHeaderData_resetsFileWhenFileHeaderCannotBeCreated() throws {
        // Write a file that is too short for us to parse a `FileHeader` object.
        let handle = try FileHandle(forUpdating: testFileLocation)
        handle.write(Data(repeating: 0, count: Int(FileHeader.expectedEndOfHeaderInFile) - 1))

        let headerHandle1 = try createHeaderHandle()
        try headerHandle1.synchronizeHeaderData()

        // Verify that the file is now the size of the header. This means that we rewrote the file.
        try handle.seek(to: 0)
        let headerData = try handle.readDataUp(toLength: Int(FileHeader.expectedEndOfHeaderInFile))
        XCTAssertEqual(headerData.count, Int(FileHeader.expectedEndOfHeaderInFile))
    }

    func test_validateMetadata_versionMismatch_returnsFalse() throws {
        let fileHeader = FileHeader(
            version: 1,
            maximumBytes: 1000,
            overwritesOldMessages: true,
            offsetInFileOfOldestMessage: FileHeader.expectedEndOfHeaderInFile,
            offsetInFileAtEndOfNewestMessage: 500)

        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 2)

        XCTAssertFalse(sut.validateMetadata(against: fileHeader))
    }

    func test_validateMetadata_maximumBytesMismatch_returnsFalse() throws {
        let fileHeader = FileHeader(
            version: 1,
            maximumBytes: 1000,
            overwritesOldMessages: true,
            offsetInFileOfOldestMessage: FileHeader.expectedEndOfHeaderInFile,
            offsetInFileAtEndOfNewestMessage: 500)

        let sut = try createHeaderHandle(
            maximumBytes: 2000,
            overwritesOldMessages: true,
            version: 1)

        XCTAssertFalse(sut.validateMetadata(against: fileHeader))
    }

    func test_validateMetadata_overwritesOldMessagesMismatch_returnsFalse() throws {
        let fileHeader = FileHeader(
            version: 1,
            maximumBytes: 1000,
            overwritesOldMessages: true,
            offsetInFileOfOldestMessage: FileHeader.expectedEndOfHeaderInFile,
            offsetInFileAtEndOfNewestMessage: 500)

        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: false,
            version: 1)

        XCTAssertFalse(sut.validateMetadata(against: fileHeader))
    }

    func test_validateMetadata_noMismatches_returnsTrue() throws {
        let fileHeader = FileHeader(
            version: 1,
            maximumBytes: 1000,
            overwritesOldMessages: true,
            offsetInFileOfOldestMessage: FileHeader.expectedEndOfHeaderInFile,
            offsetInFileAtEndOfNewestMessage: 500)

        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 1)

        XCTAssertTrue(sut.validateMetadata(against: fileHeader))
    }

    // MARK: Private

    private func createHeaderHandle(
        maximumBytes: Bytes = 500,
        overwritesOldMessages: Bool = true,
        version: UInt8 = FileHeader.version)
        throws
        -> CacheHeaderHandle
    {
        try CacheHeaderHandle(
            forReadingFrom: testFileLocation,
            maximumBytes: maximumBytes,
            overwritesOldMessages: overwritesOldMessages,
            version: version)
    }

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheHeaderHandleTests")
}
