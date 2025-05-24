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

@Suite(.serialized)
struct CacheHeaderHandleTests: ~Copyable {
	// MARK: Initializatino

	init() {
		#expect(FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil))
	}

	deinit {
		try? FileManager.default.removeItem(at: testFileLocation)
	}

	// MARK: Behavior Tests

	@Test
	func synchronizeHeaderData_returnsSameVersionAsWasLastPersistedToDisk() throws {
		let headerHandle1 = try createHeaderHandle(version: 2)
		try headerHandle1.synchronizeHeaderData()
		try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1_000)
		try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2_000)

		let headerHandle2 = try createHeaderHandle(version: 2)
		try headerHandle2.synchronizeHeaderData()

		#expect(headerHandle2.offsetInFileAtEndOfNewestMessage == 1_000)
		#expect(headerHandle2.offsetInFileOfOldestMessage == 2_000)
	}

	@Test
	func synchronizeHeaderData_doesNotThrowWhenUnexpectedVersionIsOnDisk() throws {
		let headerHandle1 = try createHeaderHandle(version: 2)
		try headerHandle1.synchronizeHeaderData()
		let defaultOffsetInFileAtEndOfNewestMessage = headerHandle1.offsetInFileAtEndOfNewestMessage
		let defaultOffsetInFileOfOldestMessage = headerHandle1.offsetInFileOfOldestMessage
		try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1_000)
		try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2_000)
		let fileData = try Data(contentsOf: testFileLocation)

		#expect(headerHandle1.offsetInFileAtEndOfNewestMessage != defaultOffsetInFileAtEndOfNewestMessage)
		#expect(headerHandle1.offsetInFileOfOldestMessage != defaultOffsetInFileOfOldestMessage)

		let headerHandle2 = try createHeaderHandle(version: 3)
		try headerHandle2.synchronizeHeaderData()
		#expect(try Data(contentsOf: testFileLocation) == fileData, "Opening handle with different version caused file to be changed")
	}

	@Test
	func synchronizeHeaderData_doesNotThrowWhenMaximumBytesIsInconsistent() throws {
		let headerHandle1 = try createHeaderHandle(maximumBytes: 5_000)
		try headerHandle1.synchronizeHeaderData()
		let defaultOffsetInFileAtEndOfNewestMessage = headerHandle1.offsetInFileAtEndOfNewestMessage
		let defaultOffsetInFileOfOldestMessage = headerHandle1.offsetInFileOfOldestMessage
		try headerHandle1.updateOffsetInFileAtEndOfNewestMessage(to: 1_000)
		try headerHandle1.updateOffsetInFileOfOldestMessage(to: 2_000)
		let fileData = try Data(contentsOf: testFileLocation)

		#expect(headerHandle1.offsetInFileAtEndOfNewestMessage != defaultOffsetInFileAtEndOfNewestMessage)
		#expect(headerHandle1.offsetInFileOfOldestMessage != defaultOffsetInFileOfOldestMessage)

		let headerHandle2 = try createHeaderHandle(maximumBytes: 10_000)
		try headerHandle2.synchronizeHeaderData()

		#expect(try Data(contentsOf: testFileLocation) == fileData, "Opening handle with different maximumBytes caused file to be changed")
	}

	@Test
	func synchronizeHeaderData_writesHeaderWhenFileIsEmpty() throws {
		let handle = try FileHandle(forReadingFrom: testFileLocation)
		let fileData = try handle.readDataUp(toLength: 1)
		#expect(fileData.isEmpty)

		let headerHandle = try createHeaderHandle()
		try headerHandle.synchronizeHeaderData()

		// Verify that the file is now the size of the header. This means that we rewrote the file.
		try handle.seek(to: 0)
		let headerData = try handle.readDataUp(toLength: Int(FileHeader.expectedEndOfHeaderInFile))
		#expect(headerData.count == Int(FileHeader.expectedEndOfHeaderInFile))

		try handle.closeHandle()
	}

	@Test
	func synchronizeHeaderData_throwsFileCorruptedWhenFileHeaderCannotBeCreated() throws {
		// Write a file that is too short for us to parse a `FileHeader` object.
		let handle = try FileHandle(forUpdating: testFileLocation)
		handle.write(Data(repeating: 0, count: Int(FileHeader.expectedEndOfHeaderInFile) - 1))

		let headerHandle = try createHeaderHandle()
		#expect(throws: CacheAdvanceError.fileCorrupted) {
			try headerHandle.synchronizeHeaderData()
		}

		try handle.closeHandle()
	}

	@Test
	func checkFile_versionMismatch_throwsIncompatibleHeader() throws {
		let originalHeader = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 1
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 2
		)

		#expect(throws: CacheAdvanceError.incompatibleHeader(persistedVersion: 1)) {
			try sut.checkFile()
		}
	}

	@Test
	func checkFile_emptyFile_throwsFileCorrupted() throws {
		let sut = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 2
		)

		#expect(throws: CacheAdvanceError.fileCorrupted) {
			try sut.checkFile()
		}
	}

	@Test
	func canWriteToFile_maximumBytesMismatch_returnsFalse() throws {
		let originalHeader = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 1
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createHeaderHandle(
			maximumBytes: 2_000,
			overwritesOldMessages: true,
			version: 1
		)

		#expect(try !sut.canWriteToFile())
	}

	@Test
	func canWriteToFile_overwritesOldMessagesMismatch_returnsFalse() throws {
		let originalHeader = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 1
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: false,
			version: 1
		)

		#expect(try !sut.canWriteToFile())
	}

	@Test
	func canWriteToFile_versionMismatch_returnsFalse() throws {
		let originalHeader = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 1
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 2
		)

		#expect(try !sut.canWriteToFile())
	}

	@Test
	func canWriteToFile_emptyFile_returnsFalse() throws {
		let sut = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 2
		)

		#expect(throws: CacheAdvanceError.fileCorrupted) {
			try sut.canWriteToFile()
		}
	}

	@Test
	func checkFile_noMismatches_doesNotThrow() throws {
		let originalHeader = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 1
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createHeaderHandle(
			maximumBytes: 1_000,
			overwritesOldMessages: true,
			version: 1
		)

		try sut.checkFile()
	}

	// MARK: Private

	private func createHeaderHandle(
		maximumBytes: Bytes = 500,
		overwritesOldMessages: Bool = true,
		version: UInt8 = FileHeader.version
	)
		throws
		-> CacheHeaderHandle
	{
		try CacheHeaderHandle(
			forReadingFrom: testFileLocation,
			maximumBytes: maximumBytes,
			overwritesOldMessages: overwritesOldMessages,
			version: version
		)
	}

	private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheHeaderHandleTests")
}
