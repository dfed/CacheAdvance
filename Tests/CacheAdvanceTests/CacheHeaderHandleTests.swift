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
        XCTAssertTrue(FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil))
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

    func test_synchronizeHeaderData_doesNotThrowWhenUnexpectedVersionIsOnDisk() throws {
        let headerHandle1 = try createHeaderHandle(version: 2)
        try headerHandle1.synchronizeHeaderData()
        let defaultOffsetInFileAtEndOfNewestMessage = headerHandle1.offsetInFileAtEndOfNewestMessage
        let defaultOffsetInFileOfOldestMessage = headerHandle1.offsetInFileOfOldestMessage
        try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1000)
        try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2000)
        let fileData = try Data(contentsOf: testFileLocation)

        XCTAssertNotEqual(headerHandle1.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertNotEqual(headerHandle1.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)

        let headerHandle2 = try createHeaderHandle(version: 3)
        XCTAssertNoThrow(try headerHandle2.synchronizeHeaderData())
        XCTAssertEqual(try Data(contentsOf: testFileLocation), fileData, "Opening handle with different version caused file to be changed")
    }

    func test_synchronizeHeaderData_doesNotThrowWhenMaximumBytesIsInconsistent() throws {
        let headerHandle1 = try createHeaderHandle(maximumBytes: 5000)
        try headerHandle1.synchronizeHeaderData()
        let defaultOffsetInFileAtEndOfNewestMessage = headerHandle1.offsetInFileAtEndOfNewestMessage
        let defaultOffsetInFileOfOldestMessage = headerHandle1.offsetInFileOfOldestMessage
        try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1000)
        try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2000)
        let fileData = try Data(contentsOf: testFileLocation)

        XCTAssertNotEqual(headerHandle1.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertNotEqual(headerHandle1.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)

        let headerHandle2 = try createHeaderHandle(maximumBytes: 10000)
        XCTAssertNoThrow(try headerHandle2.synchronizeHeaderData())

        XCTAssertEqual(try Data(contentsOf: testFileLocation), fileData, "Opening handle with different maximumBytes caused file to be changed")
    }

    func test_synchronizeHeaderData_writesHeaderWhenFileIsEmpty() throws {
        let handle = try FileHandle(forReadingFrom: testFileLocation)
        let fileData = try handle.readDataUp(toLength: 1)
        XCTAssertTrue(fileData.isEmpty)

        let headerHandle = try createHeaderHandle()
        try headerHandle.synchronizeHeaderData()

        // Verify that the file is now the size of the header. This means that we rewrote the file.
        try handle.seek(to: 0)
        let headerData = try handle.readDataUp(toLength: Int(FileHeader.expectedEndOfHeaderInFile))
        XCTAssertEqual(headerData.count, Int(FileHeader.expectedEndOfHeaderInFile))

        try handle.closeHandle()
    }

    func test_synchronizeHeaderData_throwsFileCorruptedWhenFileHeaderCannotBeCreated() throws {
        // Write a file that is too short for us to parse a `FileHeader` object.
        let handle = try FileHandle(forUpdating: testFileLocation)
        handle.write(Data(repeating: 0, count: Int(FileHeader.expectedEndOfHeaderInFile) - 1))

        let headerHandle = try createHeaderHandle()
        XCTAssertThrowsError(try headerHandle.synchronizeHeaderData()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileCorrupted)
        }

        try handle.closeHandle()
    }

    func test_checkFile_versionMismatch_throwsIncompatibleHeader() throws {
        let originalHeader = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 1)
        try originalHeader.synchronizeHeaderData()

        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 2)

        XCTAssertThrowsError(try sut.checkFile()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.incompatibleHeader(persistedVersion: 1))
        }
    }

    func test_checkFile_emptyFile_throwsFileCorrupted() throws {
        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 2)

        XCTAssertThrowsError(try sut.checkFile()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileCorrupted)
        }
    }

    func test_canWriteToFile_maximumBytesMismatch_returnsFalse() throws {
        let originalHeader = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 1)
        try originalHeader.synchronizeHeaderData()

        let sut = try createHeaderHandle(
            maximumBytes: 2000,
            overwritesOldMessages: true,
            version: 1)

        XCTAssertFalse(try sut.canWriteToFile())
    }

    func test_canWriteToFile_overwritesOldMessagesMismatch_returnsFalse() throws {
        let originalHeader = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 1)
        try originalHeader.synchronizeHeaderData()

        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: false,
            version: 1)

        XCTAssertFalse(try sut.canWriteToFile())
    }

    func test_canWriteToFile_versionMismatch_returnsFalse() throws {
        let originalHeader = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 1)
        try originalHeader.synchronizeHeaderData()

        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 2)

        XCTAssertFalse(try sut.canWriteToFile())
    }

    func test_canWriteToFile_emptyFile_returnsFalse() throws {
        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 2)

        XCTAssertThrowsError(try sut.canWriteToFile()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileCorrupted)
        }
    }

    func test_checkFile_noMismatches_doesNotThrow() throws {
        let originalHeader = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 1)
        try originalHeader.synchronizeHeaderData()

        let sut = try createHeaderHandle(
            maximumBytes: 1000,
            overwritesOldMessages: true,
            version: 1)

        XCTAssertNoThrow(try sut.checkFile())
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
