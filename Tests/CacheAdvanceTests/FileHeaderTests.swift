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
import Testing

@testable import CacheAdvance

struct FileHeaderTests {
	// MARK: Behavior Tests

	@Test
	func initFromData_returnsNilWhenDataIsOfIncorrectLength() throws {
		#expect(FileHeader(from: Data(repeating: 0, count: 8)) == nil)
	}

	@Test
	func initFromData_readsZerodData() throws {
		let fileHeader = FileHeader(from: Data(repeating: 0, count: Int(FileHeader.expectedEndOfHeaderInFile)))
		#expect(fileHeader?.version == 0)
		#expect(fileHeader?.maximumBytes == 0)
		#expect(fileHeader?.overwritesOldMessages == false)
		#expect(fileHeader?.offsetInFileOfOldestMessage == 0)
		#expect(fileHeader?.offsetInFileAtEndOfNewestMessage == 0)
	}

	@Test
	func initFromData_readsOutExpectedData() throws {
		let fileHeader = createFileHeader()

		let fileHeaderFromData = FileHeader(from: fileHeader.asData)
		#expect(fileHeader.version == fileHeaderFromData?.version)
		#expect(fileHeader.maximumBytes == fileHeaderFromData?.maximumBytes)
		#expect(fileHeader.overwritesOldMessages == fileHeaderFromData?.overwritesOldMessages)
		#expect(fileHeader.offsetInFileOfOldestMessage == fileHeaderFromData?.offsetInFileOfOldestMessage)
		#expect(fileHeader.offsetInFileAtEndOfNewestMessage == fileHeaderFromData?.offsetInFileAtEndOfNewestMessage)
	}

	@Test
	func expectedEndOfHeaderInFile_hasCorrectLengthForHeaderVersion1() {
		#expect(FileHeader.expectedEndOfHeaderInFile == 64, "Header length has changed from expected 64 bytes for header version 1. This represents a breaking change.")
	}

	@Test
	func expectedEndOfHeaderInFile_hasExpectedLength() {
		#expect(UInt64(createFileHeader().asData.count) == FileHeader.expectedEndOfHeaderInFile)
	}

	// MARK: Private

	private func createFileHeader(
		version: UInt8 = FileHeader.version,
		maximumBytes: Bytes = 500,
		overwritesOldMessages: Bool = false,
		offsetInFileOfOldestMessage: UInt64 = 20,
		offsetInFileAtEndOfNewestMessage: UInt64 = 400
	) -> FileHeader {
		FileHeader(
			version: version,
			maximumBytes: maximumBytes,
			overwritesOldMessages: overwritesOldMessages,
			offsetInFileOfOldestMessage: offsetInFileOfOldestMessage,
			offsetInFileAtEndOfNewestMessage: offsetInFileAtEndOfNewestMessage
		)
	}
}
