//
//  Created by Dan Federman on 11/9/19.
//  Copyright © 2019 Dan Federman.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS"BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Testing
import XCTest

@testable import CacheAdvance

@Suite(.serialized)
struct CacheAdvanceTests {
	// MARK: Initialization

	init() {
		clearCacheFile()
	}

	// MARK: Behavior Tests

	@Test
	func isEmpty_returnsTrueWhenCacheIsEmpty() throws {
		let cache = try createCache(overwritesOldMessages: false)

		#expect(try cache.isEmpty())
	}

	@Test
	func isEmpty_returnsFalseWhenCacheHasASingleMessage() throws {
		let message: TestableMessage = "This is a test"
		let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
		try cache.append(message: message)

		#expect(try !cache.isEmpty())
	}

	@Test
	func isEmpty_returnsFalseWhenOpenedOnCacheThatHasASingleMessage() throws {
		let message: TestableMessage = "This is a test"
		let cache = try createCache(overwritesOldMessages: false)
		try cache.append(message: message)

		let sameCache = try createCache(overwritesOldMessages: false)

		#expect(try !sameCache.isEmpty())
	}

	@Test
	func isEmpty_returnsFalseWhenCacheThatDoesNotOverwriteIsFull() throws {
		let message: TestableMessage = "This is a test"
		let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
		try cache.append(message: message)

		#expect(try !cache.isEmpty())
	}

	@Test
	func isEmpty_returnsFalseWhenCacheThatOverwritesIsFull() throws {
		let cache = try createCache(overwritesOldMessages: true)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		#expect(try !cache.isEmpty())
	}

	@Test
	func isEmpty_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
		let originalHeader = try createHeaderHandle(
			overwritesOldMessages: false,
			version: 0
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createCache(overwritesOldMessages: false)
		#expect(throws: CacheAdvanceError.incompatibleHeader(persistedVersion: 0)) {
			try sut.isEmpty()
		}
	}

	@Test
	func messages_canReadEmptyCacheThatDoesNotOverwriteOldestMessages() throws {
		let cache = try createCache(overwritesOldMessages: false)

		let messages = try cache.messages()
		#expect(messages == [])
	}

	@Test
	func messages_canReadEmptyCacheThatOverwritesOldestMessages() throws {
		let cache = try createCache(overwritesOldMessages: true)

		let messages = try cache.messages()
		#expect(messages == [])
	}

	@Test
	func messages_whenOffsetInFileAtEndOfNewestMessageIsBeyondEndOfNewestMessageButBeforeEndOfFile_throwsFileCorrupted() throws {
		let message: TestableMessage = "This is a test"
		let requiredByteCount = try requiredByteCount(for: [message])
		let maximumBytes = requiredByteCount + 2
		let header = try CacheHeaderHandle(
			forReadingFrom: testFileLocation,
			maximumBytes: maximumBytes,
			overwritesOldMessages: true
		)

		func makeCache() throws -> CacheAdvance<TestableMessage> {
			try CacheAdvance<TestableMessage>(
				fileURL: testFileLocation,
				writer: FileHandle(forWritingTo: testFileLocation),
				reader: CacheReader(
					forReadingFrom: testFileLocation),
				header: header,
				decoder: JSONDecoder(),
				encoder: JSONEncoder()
			)
		}
		let writingCache = try makeCache()
		try writingCache.append(message: message)

		// Make the file corrupted by setting the offset at end of newest message to be further in the file.
		// This could happen if a crash occurred during a write of `header.offsetInFileAtEndOfNewestMessage` on a big-endian device.
		// Big-endian devices write the most significant digits first, meaning that if we were offsetInFileAtEndOfNewestMessage from 00001010 to 00010000, it would be possible to crash with the following bytes written to disk: 00011010.
		// The 00011010 value is a larger value what we intended to write, which would lead to file corruption.
		try header.updateOffsetInFileAtEndOfNewestMessage(
			to: requiredByteCount + 1)

		// Create a new cache instance that uses the corrupted data persisted to disk
		let corruptedReadingCache = try makeCache()

		#expect(throws: CacheAdvanceError.fileCorrupted) {
			try corruptedReadingCache.messages()
		}
	}

	@Test
	func messages_whenOffsetInFileAtEndOfNewestMessageIsBeyondEndOfFile_throwsFileCorrupted() throws {
		let message: TestableMessage = "This is a test"
		let maximumBytes = try requiredByteCount(for: [message])
		let header = try CacheHeaderHandle(
			forReadingFrom: testFileLocation,
			maximumBytes: maximumBytes,
			overwritesOldMessages: true
		)

		func makeCache() throws -> CacheAdvance<TestableMessage> {
			try CacheAdvance<TestableMessage>(
				fileURL: testFileLocation,
				writer: FileHandle(forWritingTo: testFileLocation),
				reader: CacheReader(
					forReadingFrom: testFileLocation),
				header: header,
				decoder: JSONDecoder(),
				encoder: JSONEncoder()
			)
		}
		let writingCache = try makeCache()
		try writingCache.append(message: message)

		// Make the file corrupted by setting the offset at end of newest message to be further in the file.
		// This could happen if a crash occurred during a write of `header.offsetInFileAtEndOfNewestMessage` on a big-endian device.
		// Big-endian devices write the most significant digits first, meaning that if we were offsetInFileAtEndOfNewestMessage from 00001010 to 00010000, it would be possible to crash with the following bytes written to disk: 00011010.
		// The 00011010 value is a larger value what we intended to write, which would lead to file corruption.
		try header.updateOffsetInFileAtEndOfNewestMessage(
			to: header.offsetInFileAtEndOfNewestMessage + 1)

		// Create a new cache instance that uses the corrupted data persisted to disk
		let corruptedReadingCache = try makeCache()

		#expect(throws: CacheAdvanceError.fileCorrupted) {
			try corruptedReadingCache.messages()
		}
	}

	@Test
	func messages_whenOffsetInFileAtEndOfNewestMessageIsBeforeEndOfNewestMessage_throwsFileCorrupted() throws {
		let message: TestableMessage = "This is a test"
		let maximumBytes = try requiredByteCount(for: [message])
		let header = try CacheHeaderHandle(
			forReadingFrom: testFileLocation,
			maximumBytes: maximumBytes,
			overwritesOldMessages: true
		)

		func makeCache() throws -> CacheAdvance<TestableMessage> {
			try CacheAdvance<TestableMessage>(
				fileURL: testFileLocation,
				writer: FileHandle(forWritingTo: testFileLocation),
				reader: CacheReader(
					forReadingFrom: testFileLocation),
				header: header,
				decoder: JSONDecoder(),
				encoder: JSONEncoder()
			)
		}
		let writingCache = try makeCache()
		try writingCache.append(message: message)

		// Make the file corrupted by setting the offset at end of newest message to be earlier in the file.
		// This could happen if a crash occurred during a write of `header.offsetInFileAtEndOfNewestMessage` on a little-endian device.
		// Little-endian devices write the lest significant digits first, meaning that if we were offsetInFileAtEndOfNewestMessage from 01010000 to 00001000, it would be possible to crash with the following bytes written to disk: 00010000.
		// The 00010000 value is a smaller value what we intended to write, which would lead to file corruption.
		try header.updateOffsetInFileAtEndOfNewestMessage(
			to: header.offsetInFileAtEndOfNewestMessage - 1)

		// Create a new cache instance that uses the corrupted data persisted to disk
		let corruptedReadingCache = try makeCache()

		#expect(throws: CacheAdvanceError.fileCorrupted) {
			try corruptedReadingCache.messages()
		}
	}

	@Test
	func isWritable_returnsTrueWhenStaticHeaderMetadataMatches() throws {
		let originalCache = try createCache(overwritesOldMessages: false)
		#expect(try originalCache.isWritable())

		let sut = try createCache(overwritesOldMessages: false)
		#expect(try sut.isWritable())
	}

	@Test
	func isWritable_returnsFalseWhenHeaderVersionDoesNotMatch() throws {
		let originalHeader = try createHeaderHandle(
			overwritesOldMessages: false,
			version: 0
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createCache(overwritesOldMessages: false)
		#expect(try !sut.isWritable())
	}

	@Test
	func isWritable_returnsFalseWhenMaximumBytesDoesNotMatch() throws {
		let originalCache = try createCache(overwritesOldMessages: false)
		#expect(try originalCache.isWritable())

		let sut = try createCache(
			sizedToFit: TestableMessage.lorumIpsum.dropLast(),
			overwritesOldMessages: false
		)
		#expect(try !sut.isWritable())
	}

	@Test
	func isWritable_returnsFalseWhenOverwritesOldMessagesDoesNotMatch() throws {
		let originalCache = try createCache(overwritesOldMessages: false)
		#expect(try originalCache.isWritable())

		let sut = try createCache(overwritesOldMessages: true)
		#expect(try !sut.isWritable())
	}

	@Test
	func append_singleMessageThatFits_canBeRetrieved() throws {
		let message: TestableMessage = "This is a test"
		let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
		try cache.append(message: message)

		let messages = try cache.messages()
		#expect(messages == [message])
	}

	@Test
	func append_singleMessageThatDoesNotFit_throwsError() throws {
		let message: TestableMessage = "This is a test"
		let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false, maximumByteSubtractor: 1)

		#expect(throws: CacheAdvanceError.messageLargerThanCacheCapacity) {
			try cache.append(message: message)
		}

		let messages = try cache.messages()
		#expect(messages == [], "Expected failed first write to result in an empty cache")
	}

	@Test
	func append_singleMessageThrowsIfDoesNotFitAndCacheRolls() throws {
		let message: TestableMessage = "This is a test"
		let cache = try createCache(sizedToFit: [message], overwritesOldMessages: true, maximumByteSubtractor: 1)

		#expect(throws: CacheAdvanceError.messageLargerThanCacheCapacity) {
			try cache.append(message: message)
		}

		let messages = try cache.messages()
		#expect(messages == [], "Expected failed first write to result in an empty cache")
	}

	@Test
	func append_multipleMessagesCanBeRetrieved() throws {
		let cache = try createCache(overwritesOldMessages: false)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		let messages = try cache.messages()
		#expect(messages == TestableMessage.lorumIpsum)
	}

	@Test
	func append_multipleMessagesCanBeRetrievedTwiceFromNonOverwritingCache() throws {
		let cache = try createCache(overwritesOldMessages: false)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		#expect(try cache.messages() == cache.messages())
	}

	@Test
	func append_multipleMessagesCanBeRetrievedTwiceFromOverwritingCache() throws {
		let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: 3)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		#expect(try cache.messages() == cache.messages())
	}

	@Test
	func append_dropsLastMessageIfCacheDoesNotRollAndLastMessageDoesNotFit() throws {
		let cache = try createCache(overwritesOldMessages: false)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		#expect(throws: CacheAdvanceError.messageLargerThanRemainingCacheSize) {
			try cache.append(message: "This message won't fit")
		}

		let messages = try cache.messages()
		#expect(messages == TestableMessage.lorumIpsum)
	}

	@Test
	func append_dropsOldestMessageIfCacheRollsAndLastMessageDoesNotFitAndIsShorterThanOldestMessage() throws {
		let cache = try createCache(overwritesOldMessages: true)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		// Append a message that is shorter than the first message in TestableMessage.lorumIpsum.
		let shortMessage: TestableMessage = "Short message"
		try cache.append(message: shortMessage)

		let messages = try cache.messages()
		#expect(messages == Array(TestableMessage.lorumIpsum.dropFirst()) + [shortMessage])
	}

	@Test
	func append_dropsFirstTwoMessagesIfCacheRollsAndLastMessageDoesNotFitAndIsLargerThanOldestMessage() throws {
		let cache = try createCache(overwritesOldMessages: true)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		// Append a message that is slightly longer than the first message in TestableMessage.lorumIpsum.
		let barelyLongerMessage = TestableMessage(stringLiteral: TestableMessage.lorumIpsum[0].value + "hi")
		try cache.append(message: barelyLongerMessage)

		let messages = try cache.messages()
		#expect(messages == Array(TestableMessage.lorumIpsum.dropFirst(2)) + [barelyLongerMessage])
	}

	@Test
	func append_inAnOverwritingCacheEvictsMinimumPossibleNumberOfMessages() throws {
		let message: TestableMessage = "test-message"
		let maxMessagesBeforeOverwriting = [message, message, message]
		let cache = try createCache(
			sizedToFit: maxMessagesBeforeOverwriting,
			overwritesOldMessages: true
		)
		for message in maxMessagesBeforeOverwriting {
			try cache.append(message: message)
		}

		// All of our messages have been stored and our cache is full.

		// The byte layout in the cache should now be as follows:
		// [header][length|test-message][length|test-message][length|test-message]
		//         ^ reading handle                                               ^ writing handle

		// When we read messages, we read from the current position of the reading handle – which is at the start of the oldest persisted message –
		// up until the current position of the writing handle – which is at the end of the newest persisted message. This algorithm implies that if
		// the reading handle and the writing handle are at the same position in the file, then the file is empty. Therefore, when writing a message
		// and overwriting, we must ensure that we do not accidentally write a message such that the reading handle and the writing handle end up in
		// the same position.

		// Prove to ourselves we've stored all of the messages.
		#expect(try cache.messages() == maxMessagesBeforeOverwriting)

		// Append one more message of the same size.
		try cache.append(message: message)

		// Because we can not have the writing handle in the same position as the writing handle, the byte layout in the cache should now be as follows:
		// [header][length|test-message]                     [length|test-message]
		//                              ^ writing handle     ^ reading handle

		// In other words, we had to evict a single message in order to ensure that our writing and reading handles did not point at the same byte.
		// If more messages have been dropped, that indicates that our `prepareReaderForWriting` method has a bug.
		#expect(try cache.messages() == [message, message])
	}

	@Test
	func append_dropsOldMessagesAsNecessary() throws {
		for maximumByteDivisor in stride(from: 1, to: 50, by: 0.1) {
			let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
			for message in TestableMessage.lorumIpsum {
				try cache.append(message: message)
			}

			let messages = try cache.messages()
			#expect(expectedMessagesInOverwritingCache(givenOriginal: TestableMessage.lorumIpsum, newMessageCount: messages.count) == messages)

			// Prepare ourselves for the next run.
			clearCacheFile()
		}
	}

	@Test
	func append_canWriteMessagesToCacheCreatedByADifferentCache() throws {
		let cache = try createCache(overwritesOldMessages: false)
		for message in TestableMessage.lorumIpsum.dropLast() {
			try cache.append(message: message)
		}

		let cachedMessages = try cache.messages()
		let secondCache = try createCache(overwritesOldMessages: false)
		try secondCache.append(message: TestableMessage.lorumIpsum.last!)
		#expect(try cachedMessages + [TestableMessage.lorumIpsum.last!] == secondCache.messages())
	}

	@Test
	func append_canWriteMessagesToCacheCreatedByADifferentOverridingCache() throws {
		for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
			let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
			for message in TestableMessage.lorumIpsum.dropLast() {
				try cache.append(message: message)
			}

			let cachedMessages = try cache.messages()

			let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)

			// Check that we can retrieve the messages from the first cache.
			#expect(try !secondCache.isEmpty())

			try secondCache.append(message: TestableMessage.lorumIpsum.last!)
			let secondCacheMessages = try secondCache.messages()

			#expect(expectedMessagesInOverwritingCache(givenOriginal: cachedMessages + [TestableMessage.lorumIpsum.last!], newMessageCount: secondCacheMessages.count) == secondCacheMessages)

			// Prepare ourselves for the next run.
			clearCacheFile()
		}
	}

	@Test
	func append_canWriteMessagesAfterRetrievingMessages() throws {
		for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
			let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
			for message in TestableMessage.lorumIpsum.dropLast() {
				try cache.append(message: message)
			}

			let cachedMessages = try cache.messages()
			try cache.append(message: TestableMessage.lorumIpsum.last!)

			let cachedMessagesAfterAppend = try cache.messages()
			#expect(expectedMessagesInOverwritingCache(givenOriginal: cachedMessages + [TestableMessage.lorumIpsum.last!], newMessageCount: cachedMessagesAfterAppend.count) == cachedMessagesAfterAppend)

			// Prepare ourselves for the next run.
			clearCacheFile()
		}
	}

	@Test
	func append_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
		let originalHeader = try createHeaderHandle(
			overwritesOldMessages: false,
			version: 0
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createCache(
			sizedToFit: TestableMessage.lorumIpsum.dropLast(),
			overwritesOldMessages: false
		)
		#expect(throws: CacheAdvanceError.incompatibleHeader(persistedVersion: 0)) {
			try sut.append(message: TestableMessage.lorumIpsum.last!)
		}
	}

	@Test
	func append_throwsFileNotWritableWhenMaximumBytesDoesNotMatch() throws {
		let originalCache = try createCache(overwritesOldMessages: false)
		#expect(try originalCache.isWritable())

		let sut = try createCache(
			sizedToFit: TestableMessage.lorumIpsum.dropLast(),
			overwritesOldMessages: false
		)
		#expect(throws: CacheAdvanceError.fileNotWritable) {
			try sut.append(message: TestableMessage.lorumIpsum.last!)
		}
	}

	@Test
	func append_throwsFileNotWritableWhenOverwritesOldMessagesDoesNotMatch() throws {
		let originalCache = try createCache(overwritesOldMessages: false)
		#expect(try originalCache.isWritable())

		let sut = try createCache(overwritesOldMessages: true)
		#expect(throws: CacheAdvanceError.fileNotWritable) {
			try sut.append(message: TestableMessage.lorumIpsum.last!)
		}
	}

	@Test
	func messages_canReadMessagesWrittenByADifferentCache() throws {
		let cache = try createCache(overwritesOldMessages: false)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		let secondCache = try createCache(overwritesOldMessages: false)
		#expect(try cache.messages() == secondCache.messages())
	}

	@Test
	func messages_canReadMessagesWrittenByADifferentFullCache() throws {
		let cache = try createCache(overwritesOldMessages: false, maximumByteSubtractor: 1)
		for message in TestableMessage.lorumIpsum.dropLast() {
			try cache.append(message: message)
		}
		#expect(throws: CacheAdvanceError.messageLargerThanRemainingCacheSize) {
			try cache.append(message: TestableMessage.lorumIpsum.last!)
		}

		let secondCache = try createCache(overwritesOldMessages: false, maximumByteSubtractor: 1)
		#expect(try cache.messages() == secondCache.messages())
	}

	@Test
	func messages_canReadMessagesWrittenByADifferentOverwritingCache() throws {
		for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
			let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
			for message in TestableMessage.lorumIpsum {
				try cache.append(message: message)
			}

			let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
			#expect(try cache.messages() == secondCache.messages())

			// Prepare ourselves for the next run.
			clearCacheFile()
		}
	}

	@Test
	func messages_cacheThatDoesNotOverwrite_canReadMessagesWrittenByAnOverwritingCache() throws {
		let cache = try createCache(overwritesOldMessages: false)
		for message in TestableMessage.lorumIpsum {
			try cache.append(message: message)
		}

		let secondCache = try createCache(overwritesOldMessages: true)
		#expect(try cache.messages() == secondCache.messages())
	}

	@Test
	func messages_cacheThatOverwrites_canReadMessagesWrittenByAnOverwritingCacheWithDifferentMaximumBytes() throws {
		for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
			let cache = try createCache(overwritesOldMessages: true)
			for message in TestableMessage.lorumIpsum {
				try cache.append(message: message)
			}

			let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
			#expect(try cache.messages() == secondCache.messages())

			// Prepare ourselves for the next run.
			clearCacheFile()
		}
	}

	@Test
	func messages_cacheThatOverwrites_canReadMessagesWrittenByANonOverwritingCache() throws {
		for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
			let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
			for message in TestableMessage.lorumIpsum {
				try cache.append(message: message)
			}

			let secondCache = try createCache(overwritesOldMessages: false)
			#expect(try cache.messages() == secondCache.messages())

			// Prepare ourselves for the next run.
			clearCacheFile()
		}
	}

	@Test
	func messages_cacheThatDoesNotOverwrite_canReadMessagesWrittenByAnOverwritingCacheWithDifferentMaximumBytes() throws {
		for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
			let cache = try createCache(overwritesOldMessages: false)
			for message in TestableMessage.lorumIpsum {
				try cache.append(message: message)
			}

			let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
			#expect(try cache.messages() == secondCache.messages())

			// Prepare ourselves for the next run.
			clearCacheFile()
		}
	}

	@Test
	func messages_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
		let originalHeader = try createHeaderHandle(
			overwritesOldMessages: false,
			version: 0
		)
		try originalHeader.synchronizeHeaderData()

		let sut = try createCache(overwritesOldMessages: false)
		#expect(throws: CacheAdvanceError.incompatibleHeader(persistedVersion: 0)) {
			try sut.messages()
		}
	}

	// MARK: Private

	private func requiredByteCount<T: Codable>(for messages: [T]) throws -> UInt64 {
		let encoder = JSONEncoder()
		return try FileHeader.expectedEndOfHeaderInFile
			+ messages.reduce(0) { allocatedSize, message in
				let encodableMessage = EncodableMessage<T, MessageSpan>(message: message, encoder: encoder)
				let data = try encodableMessage.encodedData()
				return allocatedSize + UInt64(data.count)
			}
	}

	private func createHeaderHandle(
		sizedToFit messages: [TestableMessage] = TestableMessage.lorumIpsum,
		overwritesOldMessages: Bool,
		maximumByteDivisor: Double = 1,
		maximumByteSubtractor: Bytes = 0,
		version: UInt8 = FileHeader.version,
		zeroOutExistingFile: Bool = true
	) throws -> CacheHeaderHandle {
		if zeroOutExistingFile { clearCacheFile() }
		return try CacheHeaderHandle(
			forReadingFrom: testFileLocation,
			maximumBytes: Bytes(Double(requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
			overwritesOldMessages: overwritesOldMessages,
			version: version
		)
	}

	private func createCache(
		sizedToFit messages: [TestableMessage] = TestableMessage.lorumIpsum,
		overwritesOldMessages: Bool,
		maximumByteDivisor: Double = 1,
		maximumByteSubtractor: Bytes = 0
	) throws -> CacheAdvance<TestableMessage> {
		try createCache(
			maximumByes: Bytes(Double(requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
			overwritesOldMessages: overwritesOldMessages
		)
	}

	private func createCache(
		maximumByes: Bytes,
		overwritesOldMessages: Bool
	) throws -> CacheAdvance<TestableMessage> {
		try CacheAdvance<TestableMessage>(
			fileURL: testFileLocation,
			maximumBytes: maximumByes,
			shouldOverwriteOldMessages: overwritesOldMessages
		)
	}

	private func expectedMessagesInOverwritingCache(
		givenOriginal messages: [TestableMessage],
		newMessageCount: Int
	) -> [TestableMessage] {
		Array(messages.dropFirst(messages.count - newMessageCount))
	}

	private func clearCacheFile() {
		#expect(FileManager.default.createFile(
			atPath: testFileLocation.path,
			contents: nil,
			attributes: nil
		))
	}

	private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheAdvanceTests")
}

// MARK: - CacheAdvancePerformanceTests

final class CacheAdvancePerformanceTests: XCTestCase {
	// MARK: XCTestCase

	override func setUp() {
		super.setUp()
		clearCacheFile()
	}

	// MARK: Performance Tests

	func test_performance_createCacheAndAppendSingleMessage() throws {
		guard performanceTestsEnabled else { return }
		measure {
			clearCacheFile()

			guard let sut = try? createCache(maximumByes: 100, overwritesOldMessages: true) else {
				XCTFail("Could not create cache")
				return
			}
			try? sut.append(message: "test message")
		}
	}

	func test_performance_append_fillableCache() throws {
		guard performanceTestsEnabled else { return }
		let maximumBytes = try Bytes(Double(requiredByteCount(for: TestableMessage.lorumIpsum)))
		// Create a cache that won't run out of room over multiple test runs
		guard let sut = try? createCache(maximumByes: maximumBytes * 10, overwritesOldMessages: false) else {
			XCTFail("Could not create cache")
			return
		}
		// Force the cache to set up before we start writing messages.
		_ = try sut.isWritable()
		measure {
			for message in TestableMessage.lorumIpsum {
				try? sut.append(message: message)
			}
		}
	}

	func test_performance_append_overwritingCache() throws {
		guard performanceTestsEnabled else { return }
		let sut = try createCache(overwritesOldMessages: true)
		// Fill the cache before the test starts.
		for message in TestableMessage.lorumIpsum {
			try sut.append(message: message)
		}
		measure {
			for message in TestableMessage.lorumIpsum {
				try? sut.append(message: message)
			}
		}
	}

	func test_performance_messages_fillableCache() throws {
		guard performanceTestsEnabled else { return }
		let sut = try createCache(overwritesOldMessages: false)
		for message in TestableMessage.lorumIpsum {
			try sut.append(message: message)
		}
		measure {
			guard (try? sut.messages()) != nil else {
				XCTFail("Could not read messages")
				return
			}
		}
	}

	func test_performance_messages_overwritingCache() throws {
		guard performanceTestsEnabled else { return }
		let sut = try createCache(overwritesOldMessages: true)
		for message in TestableMessage.lorumIpsum + TestableMessage.lorumIpsum {
			try sut.append(message: message)
		}
		measure {
			guard (try? sut.messages()) != nil else {
				XCTFail("Could not read messages")
				return
			}
		}
	}

	// MARK: Private

	private func requiredByteCount<T: Codable>(for messages: [T]) throws -> UInt64 {
		let encoder = JSONEncoder()
		return try FileHeader.expectedEndOfHeaderInFile
			+ messages.reduce(0) { allocatedSize, message in
				let encodableMessage = EncodableMessage<T, MessageSpan>(message: message, encoder: encoder)
				let data = try encodableMessage.encodedData()
				return allocatedSize + UInt64(data.count)
			}
	}

	private func createCache(
		sizedToFit messages: [TestableMessage] = TestableMessage.lorumIpsum,
		overwritesOldMessages: Bool,
		maximumByteDivisor: Double = 1,
		maximumByteSubtractor: Bytes = 0
	) throws -> CacheAdvance<TestableMessage> {
		try createCache(
			maximumByes: Bytes(Double(requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
			overwritesOldMessages: overwritesOldMessages
		)
	}

	private func createCache(
		maximumByes: Bytes,
		overwritesOldMessages: Bool
	) throws -> CacheAdvance<TestableMessage> {
		try CacheAdvance<TestableMessage>(
			fileURL: testFileLocation,
			maximumBytes: maximumByes,
			shouldOverwriteOldMessages: overwritesOldMessages
		)
	}

	private func clearCacheFile() {
		XCTAssertTrue(FileManager.default.createFile(
			atPath: testFileLocation.path,
			contents: nil,
			attributes: nil
		))
	}

	private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheAdvancePerformanceTests")
}
