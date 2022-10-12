//
//  Created by Dan Federman on 11/9/19.
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

final class CacheAdvanceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearCacheFile()
    }

    // MARK: Behavior Tests

    func test_isEmpty_returnsTrueWhenCacheIsEmpty() throws {
        let cache = try createCache(overwritesOldMessages: false)

        XCTAssertTrue(try cache.isEmpty())
    }

    func test_isEmpty_returnsFalseWhenCacheHasASingleMessage() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
        try cache.append(message: message)

        XCTAssertFalse(try cache.isEmpty())
    }

    func test_isEmpty_returnsFalseWhenOpenedOnCacheThatHasASingleMessage() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(overwritesOldMessages: false)
        try cache.append(message: message)

        let sameCache = try createCache(overwritesOldMessages: false)

        XCTAssertFalse(try sameCache.isEmpty())
    }

    func test_isEmpty_returnsFalseWhenCacheThatDoesNotOverwriteIsFull() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
        try cache.append(message: message)

        XCTAssertFalse(try cache.isEmpty())
    }

    func test_isEmpty_returnsFalseWhenCacheThatOverwritesIsFull() throws {
        let cache = try createCache(overwritesOldMessages: true)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        XCTAssertFalse(try cache.isEmpty())
    }

    func test_isEmpty_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(overwritesOldMessages: false)
        XCTAssertThrowsError(try sut.isEmpty()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.incompatibleHeader(persistedVersion: 0))
        }
    }

    func test_messages_canReadEmptyCacheThatDoesNotOverwriteOldestMessages() throws {
        let cache = try createCache(overwritesOldMessages: false)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [])
    }

    func test_messages_canReadEmptyCacheThatOverwritesOldestMessages() throws {
        let cache = try createCache(overwritesOldMessages: true)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [])
    }

    func test_messages_throwsFileCorruptedWhenOffsetInFileAtEndOfNewsetMessageOutOfSync() throws {
        let randomHighValue: UInt64 = 10_1000
        let header = try CacheHeaderHandle(
            forReadingFrom: testFileLocation,
            maximumBytes: randomHighValue,
            overwritesOldMessages: true)
        let cache = CacheAdvance<TestableMessage>(
            fileURL: testFileLocation,
            writer: try FileHandle(forWritingTo: testFileLocation),
            reader: try CacheReader(forReadingFrom: testFileLocation),
            header: try CacheHeaderHandle(
                forReadingFrom: testFileLocation,
                maximumBytes: header.maximumBytes,
                overwritesOldMessages: header.overwritesOldMessages),
            decoder: JSONDecoder(),
            encoder: JSONEncoder())

        // Make sure the header data is persisted before we read it as part of the `messages()` call below.
        try header.synchronizeHeaderData()
        // Our file is empty. Make the file corrupted by setting the offset at end of newest message to be further in the file.
        // This should never happen, but past versions of this repo could lead to a file having this kind of inconsistency if a crash occurred at the wrong time.
        try header.updateOffsetInFileAtEndOfNewestMessage(
            to: FileHeader.expectedEndOfHeaderInFile + 1)

        XCTAssertThrowsError(try cache.messages()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileCorrupted)
        }
    }

    func test_isWritable_returnsTrueWhenStaticHeaderMetadataMatches() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try sut.isWritable())
    }

    func test_isWritable_returnsFalseWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(overwritesOldMessages: false)
        XCTAssertFalse(try sut.isWritable())
    }

    func test_isWritable_returnsFalseWhenMaximumBytesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(
            sizedToFit: TestableMessage.lorumIpsum.dropLast(),
            overwritesOldMessages: false)
        XCTAssertFalse(try sut.isWritable())
    }

    func test_isWritable_returnsFalseWhenOverwritesOldMessagesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: true)
        XCTAssertFalse(try sut.isWritable())
    }

    func test_append_singleMessageThatFits_canBeRetrieved() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false)
        try cache.append(message: message)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [message])
    }

    func test_append_singleMessageThatDoesNotFit_throwsError() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: false, maximumByteSubtractor: 1)

        XCTAssertThrowsError(try cache.append(message: message)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.messageLargerThanCacheCapacity)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, [], "Expected failed first write to result in an empty cache")
    }

    func test_append_singleMessageThrowsIfDoesNotFitAndCacheRolls() throws {
        let message: TestableMessage = "This is a test"
        let cache = try createCache(sizedToFit: [message], overwritesOldMessages: true, maximumByteSubtractor: 1)

        XCTAssertThrowsError(try cache.append(message: message)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.messageLargerThanCacheCapacity)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, [], "Expected failed first write to result in an empty cache")
    }

    func test_append_multipleMessagesCanBeRetrieved() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, TestableMessage.lorumIpsum)
    }

    func test_append_multipleMessagesCanBeRetrievedTwiceFromNonOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        XCTAssertEqual(try cache.messages(), try cache.messages())
    }

    func test_append_multipleMessagesCanBeRetrievedTwiceFromOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: 3)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        XCTAssertEqual(try cache.messages(), try cache.messages())
    }

    func test_append_dropsLastMessageIfCacheDoesNotRollAndLastMessageDoesNotFit() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        XCTAssertThrowsError(try cache.append(message: "This message won't fit")) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.messageLargerThanRemainingCacheSize)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, TestableMessage.lorumIpsum)
    }

    func test_append_dropsOldestMessageIfCacheRollsAndLastMessageDoesNotFitAndIsShorterThanOldestMessage() throws {
        let cache = try createCache(overwritesOldMessages: true)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        // Append a message that is shorter than the first message in TestableMessage.lorumIpsum.
        let shortMessage: TestableMessage = "Short message"
        try cache.append(message: shortMessage)

        let messages = try cache.messages()
        XCTAssertEqual(messages, Array(TestableMessage.lorumIpsum.dropFirst()) + [shortMessage])
    }

    func test_append_dropsFirstTwoMessagesIfCacheRollsAndLastMessageDoesNotFitAndIsLargerThanOldestMessage() throws {
        let cache = try createCache(overwritesOldMessages: true)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        // Append a message that is slightly longer than the first message in TestableMessage.lorumIpsum.
        let barelyLongerMessage = TestableMessage(stringLiteral: TestableMessage.lorumIpsum[0].value + "hi")
        try cache.append(message: barelyLongerMessage)

        let messages = try cache.messages()
        XCTAssertEqual(messages, Array(TestableMessage.lorumIpsum.dropFirst(2)) + [barelyLongerMessage])
    }

    func test_append_inAnOverwritingCacheEvictsMinimumPossibleNumberOfMessages() throws {
        let message: TestableMessage = "test-message"
        let maxMessagesBeforeOverwriting = [message, message, message]
        let cache = try createCache(
            sizedToFit: maxMessagesBeforeOverwriting,
            overwritesOldMessages: true)
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
        XCTAssertEqual(
            try cache.messages(),
            maxMessagesBeforeOverwriting)

        // Append one more message of the same size.
        try cache.append(message: message)

        // Because we can not have the writing handle in the same position as the writing handle, the byte layout in the cache should now be as follows:
        // [header][length|test-message]                     [length|test-message]
        //                              ^ writing handle     ^ reading handle

        // In other words, we had to evict a single message in order to ensure that our writing and reading handles did not point at the same byte.
        // If more messages have been dropped, that indicates that our `prepareReaderForWriting` method has a bug.
        XCTAssertEqual(
            try cache.messages(),
            [message, message])
    }

    func test_append_dropsOldMessagesAsNecessary() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.1) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in TestableMessage.lorumIpsum {
                try cache.append(message: message)
            }

            let messages = try cache.messages()
            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: TestableMessage.lorumIpsum, newMessageCount: messages.count), messages)

            // Prepare ourselves for the next run.
            clearCacheFile()
        }
    }

    func test_append_canWriteMessagesToCacheCreatedByADifferentCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in TestableMessage.lorumIpsum.dropLast() {
            try cache.append(message: message)
        }

        let cachedMessages = try cache.messages()
        let secondCache = try createCache(overwritesOldMessages: false)
        try secondCache.append(message: TestableMessage.lorumIpsum.last!)
        XCTAssertEqual(cachedMessages + [TestableMessage.lorumIpsum.last!], try secondCache.messages())
    }

    func test_append_canWriteMessagesToCacheCreatedByADifferentOverridingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in TestableMessage.lorumIpsum.dropLast() {
                try cache.append(message: message)
            }

            let cachedMessages = try cache.messages()

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)

            // Check that we can retrieve the messages from the first cache.
            XCTAssertFalse(try secondCache.isEmpty())

            try secondCache.append(message: TestableMessage.lorumIpsum.last!)
            let secondCacheMessages = try secondCache.messages()

            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: cachedMessages + [TestableMessage.lorumIpsum.last!], newMessageCount: secondCacheMessages.count), secondCacheMessages)

            // Prepare ourselves for the next run.
            clearCacheFile()
        }
    }

    func test_append_canWriteMessagesAfterRetrievingMessages() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in TestableMessage.lorumIpsum.dropLast() {
                try cache.append(message: message)
            }

            let cachedMessages = try cache.messages()
            try cache.append(message: TestableMessage.lorumIpsum.last!)

            let cachedMessagesAfterAppend = try cache.messages()
            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: cachedMessages + [TestableMessage.lorumIpsum.last!], newMessageCount: cachedMessagesAfterAppend.count), cachedMessagesAfterAppend)

            // Prepare ourselves for the next run.
            clearCacheFile()
        }
    }

    func test_append_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(
            sizedToFit: TestableMessage.lorumIpsum.dropLast(),
            overwritesOldMessages: false)
        XCTAssertThrowsError(try sut.append(message: TestableMessage.lorumIpsum.last!)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.incompatibleHeader(persistedVersion: 0))
        }
    }

    func test_append_throwsFileNotWritableWhenMaximumBytesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(
            sizedToFit: TestableMessage.lorumIpsum.dropLast(),
            overwritesOldMessages: false)
        XCTAssertThrowsError(try sut.append(message: TestableMessage.lorumIpsum.last!)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileNotWritable)
        }
    }

    func test_append_throwsFileNotWritableWhenOverwritesOldMessagesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: true)
        XCTAssertThrowsError(try sut.append(message: TestableMessage.lorumIpsum.last!)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileNotWritable)
        }
    }

    func test_messages_canReadMessagesWrittenByADifferentCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        let secondCache = try createCache(overwritesOldMessages: false)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_canReadMessagesWrittenByADifferentFullCache() throws {
        let cache = try createCache(overwritesOldMessages: false, maximumByteSubtractor: 1)
        for message in TestableMessage.lorumIpsum.dropLast() {
            try cache.append(message: message)
        }
        XCTAssertThrowsError(try cache.append(message: TestableMessage.lorumIpsum.last!))

        let secondCache = try createCache(overwritesOldMessages: false, maximumByteSubtractor: 1)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_canReadMessagesWrittenByADifferentOverwritingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in TestableMessage.lorumIpsum {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())

            // Prepare ourselves for the next run.
            clearCacheFile()
        }
    }

    func test_messages_cacheThatDoesNotOverwrite_canReadMessagesWrittenByAnOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in TestableMessage.lorumIpsum {
            try cache.append(message: message)
        }

        let secondCache = try createCache(overwritesOldMessages: true)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_cacheThatOverwrites_canReadMessagesWrittenByAnOverwritingCacheWithDifferentMaximumBytes() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true)
            for message in TestableMessage.lorumIpsum {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())

            // Prepare ourselves for the next run.
            clearCacheFile()
        }
    }

    func test_messages_cacheThatOverwrites_canReadMessagesWrittenByANonOverwritingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in TestableMessage.lorumIpsum {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: false)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())

            // Prepare ourselves for the next run.
            clearCacheFile()
        }
    }

    func test_messages_cacheThatDoesNotOverwrite_canReadMessagesWrittenByAnOverwritingCacheWithDifferentMaximumBytes() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: false)
            for message in TestableMessage.lorumIpsum {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())

            // Prepare ourselves for the next run.
            clearCacheFile()
        }
    }

    func test_messages_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(overwritesOldMessages: false)
        XCTAssertThrowsError(try sut.messages()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.incompatibleHeader(persistedVersion: 0))
        }
    }

    // MARK: Performance Tests

    func test_performance_createCacheAndAppendSingleMessage() throws {
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
        let maximumBytes = Bytes(Double(try requiredByteCount(for: TestableMessage.lorumIpsum)))
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

    private func createHeaderHandle(
        sizedToFit messages: [TestableMessage] = TestableMessage.lorumIpsum,
        overwritesOldMessages: Bool,
        maximumByteDivisor: Double = 1,
        maximumByteSubtractor: Bytes = 0,
        version: UInt8 = FileHeader.version,
        zeroOutExistingFile: Bool = true)
        throws
        -> CacheHeaderHandle
    {
        if zeroOutExistingFile { clearCacheFile() }
        return try CacheHeaderHandle(
            forReadingFrom: testFileLocation,
            maximumBytes: Bytes(Double(try requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
            overwritesOldMessages: overwritesOldMessages,
            version: version)
    }

    private func createCache(
        sizedToFit messages: [TestableMessage] = TestableMessage.lorumIpsum,
        overwritesOldMessages: Bool,
        maximumByteDivisor: Double = 1,
        maximumByteSubtractor: Bytes = 0)
        throws
        -> CacheAdvance<TestableMessage>
    {
        try createCache(
            maximumByes: Bytes(Double(try requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
            overwritesOldMessages: overwritesOldMessages)
    }

    private func createCache(
        maximumByes: Bytes,
        overwritesOldMessages: Bool)
        throws
        -> CacheAdvance<TestableMessage>
    {
        try CacheAdvance<TestableMessage>(
            fileURL: testFileLocation,
            maximumBytes: maximumByes,
            shouldOverwriteOldMessages: overwritesOldMessages)
    }

    private func expectedMessagesInOverwritingCache(
        givenOriginal messages: [TestableMessage],
        newMessageCount: Int)
        -> [TestableMessage]
    {
        Array(messages.dropFirst(messages.count - newMessageCount))
    }

    private func clearCacheFile() {
        FileManager.default.createFile(
            atPath: testFileLocation.path,
            contents: nil,
            attributes: nil)
    }

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheAdvanceTests")
}
