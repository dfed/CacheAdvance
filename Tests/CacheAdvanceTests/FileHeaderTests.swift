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

final class FileHeaderTests: XCTestCase {

    // MARK: Behavior Tests

    func test_initFromData_returnsNilWhenDataIsOfIncorrectLength() throws {
        XCTAssertNil(FileHeader(from: Data(repeating: 0, count: 8)))
    }

    func test_initFromData_readsZerodData() throws {
        let fileHeader = FileHeader(from: Data(repeating: 0, count: Int(FileHeader.expectedEndOfHeaderInFile)))
        XCTAssertEqual(fileHeader?.version, 0)
        XCTAssertEqual(fileHeader?.maximumBytes, 0)
        XCTAssertEqual(fileHeader?.overwritesOldMessages, false)
        XCTAssertEqual(fileHeader?.offsetInFileOfOldestMessage, 0)
        XCTAssertEqual(fileHeader?.offsetInFileAtEndOfNewestMessage, 0)
    }

    func test_initFromData_readsOutExpectedData() throws {
        let fileHeader = createFileHeader()

        let fileHeaderFromData = FileHeader(from: fileHeader.asData)
        XCTAssertEqual(fileHeader.version, fileHeaderFromData?.version)
        XCTAssertEqual(fileHeader.maximumBytes, fileHeaderFromData?.maximumBytes)
        XCTAssertEqual(fileHeader.overwritesOldMessages, fileHeaderFromData?.overwritesOldMessages)
        XCTAssertEqual(fileHeader.offsetInFileOfOldestMessage, fileHeaderFromData?.offsetInFileOfOldestMessage)
        XCTAssertEqual(fileHeader.offsetInFileAtEndOfNewestMessage, fileHeaderFromData?.offsetInFileAtEndOfNewestMessage)
    }

    // MARK: Private

    private func createFileHeader(
        version: UInt8 = FileHeader.version,
        maximumBytes: Bytes = 500,
        overwritesOldMessages: Bool = false,
        offsetInFileOfOldestMessage: UInt64 = 20,
        offsetInFileAtEndOfNewestMessage: UInt64 = 400)
        -> FileHeader
    {
        FileHeader(
            version: version,
            maximumBytes: maximumBytes,
            overwritesOldMessages: overwritesOldMessages,
            offsetInFileOfOldestMessage: offsetInFileOfOldestMessage,
            offsetInFileAtEndOfNewestMessage: offsetInFileAtEndOfNewestMessage)
    }

}
