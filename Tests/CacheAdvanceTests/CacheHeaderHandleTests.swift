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

    func test_readHeaderData_returnsSameVersionAsWasLastPersistedToDisk() throws {
        let headerHandle1 = try createHeaderHandle(version: 2)
        try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1000)
        try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2000)

        let headerHandle2 = try createHeaderHandle(version: 2)
        try headerHandle2.readHeaderData()

        XCTAssertEqual(headerHandle2.offsetInFileAtEndOfNewestMessage, headerHandle1.offsetInFileAtEndOfNewestMessage)
        XCTAssertEqual(headerHandle2.offsetInFileOfOldestMessage, headerHandle1.offsetInFileOfOldestMessage)
    }

    func test_readHeaderData_returnsDefaultVersionWhenUnexpectedVersionIsOnDisk() throws {
        let headerHandle1 = try createHeaderHandle(version: 2)
        let defaultOffsetInFileAtEndOfNewestMessage = headerHandle1.offsetInFileAtEndOfNewestMessage
        let defaultOffsetInFileOfOldestMessage = headerHandle1.offsetInFileOfOldestMessage
        try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1000)
        try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2000)

        XCTAssertNotEqual(headerHandle1.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertNotEqual(headerHandle1.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)

        let headerHandle2 = try createHeaderHandle(version: 3)
        try headerHandle2.readHeaderData()

        XCTAssertEqual(headerHandle2.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertEqual(headerHandle2.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)
    }

    func test_readHeaderData_returnsNothingWhenMaximumBytesIsInconsistent() throws {
        let headerHandle1 = try createHeaderHandle(maximumBytes: 5000)
        let defaultOffsetInFileAtEndOfNewestMessage = headerHandle1.offsetInFileAtEndOfNewestMessage
        let defaultOffsetInFileOfOldestMessage = headerHandle1.offsetInFileOfOldestMessage
        try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1000)
        try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2000)

        XCTAssertNotEqual(headerHandle1.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertNotEqual(headerHandle1.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)

        let headerHandle2 = try createHeaderHandle(maximumBytes: 10000)
        try headerHandle2.readHeaderData()

        XCTAssertEqual(headerHandle2.offsetInFileAtEndOfNewestMessage, defaultOffsetInFileAtEndOfNewestMessage)
        XCTAssertEqual(headerHandle2.offsetInFileOfOldestMessage, defaultOffsetInFileOfOldestMessage)
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
