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

        let sameCache = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)

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
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        XCTAssertFalse(try cache.isEmpty())
    }

    func test_isEmpty_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(
            overwritesOldMessages: false,
            zeroOutExistingFile: false)
        XCTAssertThrowsError(try sut.isEmpty()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.incompatibleHeader)
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

    func test_isWritable_returnsTrueWhenStaticHeaderMetadataMatches() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
        XCTAssertTrue(try sut.isWritable())
    }

    func test_isWritable_returnsFalseWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
        XCTAssertFalse(try sut.isWritable())
    }

    func test_isWritable_returnsFalseWhenMaximumBytesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(
            sizedToFit: LorumIpsum.messages.dropLast(),
            overwritesOldMessages: false,
            zeroOutExistingFile: false)
        XCTAssertFalse(try sut.isWritable())
    }

    func test_isWritable_returnsFalseWhenOverwritesOldMessagesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: true, zeroOutExistingFile: false)
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
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, LorumIpsum.messages)
    }

    func test_append_multipleMessagesCanBeRetrievedTwiceFromNonOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        XCTAssertEqual(try cache.messages(), try cache.messages())
    }

    func test_append_multipleMessagesCanBeRetrievedTwiceFromOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: 3)
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        XCTAssertEqual(try cache.messages(), try cache.messages())
    }

    func test_append_dropsLastMessageIfCacheDoesNotRollAndLastMessageDoesNotFit() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        XCTAssertThrowsError(try cache.append(message: "This message won't fit")) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.messageLargerThanRemainingCacheSize)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, LorumIpsum.messages)
    }

    func test_append_dropsOldestMessageIfCacheRollsAndLastMessageDoesNotFitAndIsShorterThanOldestMessage() throws {
        let cache = try createCache(overwritesOldMessages: true)
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        // Append a message that is shorter than the first message in LorumIpsum.messages.
        let shortMessage: TestableMessage = "Short message"
        try cache.append(message: shortMessage)

        let messages = try cache.messages()
        XCTAssertEqual(messages, Array(LorumIpsum.messages.dropFirst()) + [shortMessage])
    }

    func test_append_dropsFirstTwoMessagesIfCacheRollsAndLastMessageDoesNotFitAndIsLargerThanOldestMessage() throws {
        let cache = try createCache(overwritesOldMessages: true)
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        // Append a message that is slightly longer than the first message in LorumIpsum.messages.
        let barelyLongerMessage = TestableMessage(stringLiteral: LorumIpsum.messages[0].value + "hi")
        try cache.append(message: barelyLongerMessage)

        let messages = try cache.messages()
        XCTAssertEqual(messages, Array(LorumIpsum.messages.dropFirst(2)) + [barelyLongerMessage])
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
        //         ^ reading handle                                              ^ writing handle

        // When we read messages, we read from the current position of the reading handle – which is at the start of the oldest persisted message –
        // up until the current position of the writing handle – which is at the end of the newest persisted message. This algorithm implies that if
        // the reading handle and the writing handle are at the same position in the file, then the file is empty. Therefore, when writing a message
        // and overwriting, we must ensure that we do not accidently write a message such that the reading handle and the writing handle end up in
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
            maxMessagesBeforeOverwriting.dropLast())
    }

    func test_append_dropsOldMessagesAsNecessary() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.1) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in LorumIpsum.messages {
                try cache.append(message: message)
            }

            let messages = try cache.messages()
            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: LorumIpsum.messages, newMessageCount: messages.count), messages)
        }
    }

    func test_append_canWriteMessagesToCacheCreatedByADifferentCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in LorumIpsum.messages.dropLast() {
            try cache.append(message: message)
        }

        let cachedMessages = try cache.messages()
        let secondCache = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
        try secondCache.append(message: LorumIpsum.messages.last!)
        XCTAssertEqual(cachedMessages + [LorumIpsum.messages.last!], try secondCache.messages())
    }

    func test_append_canWriteMessagesToCacheCreatedByADifferentOverridingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in LorumIpsum.messages.dropLast() {
                try cache.append(message: message)
            }

            let cachedMessages = try cache.messages()

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            try secondCache.append(message: LorumIpsum.messages.last!)
            let secondCacheMessages = try secondCache.messages()

            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: cachedMessages + [LorumIpsum.messages.last!], newMessageCount: secondCacheMessages.count), secondCacheMessages)
        }
    }

    func test_append_canWriteMessagesAfterRetrievingMessages() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in LorumIpsum.messages.dropLast() {
                try cache.append(message: message)
            }

            let cachedMessages = try cache.messages()
            try cache.append(message: LorumIpsum.messages.last!)

            let cachedMessagesAfterAppend = try cache.messages()
            XCTAssertEqual(expectedMessagesInOverwritingCache(givenOriginal: cachedMessages + [LorumIpsum.messages.last!], newMessageCount: cachedMessagesAfterAppend.count), cachedMessagesAfterAppend)
        }
    }

    func test_append_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(
            sizedToFit: LorumIpsum.messages.dropLast(),
            overwritesOldMessages: false,
            zeroOutExistingFile: false)
        XCTAssertThrowsError(try sut.append(message: LorumIpsum.messages.last!)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.incompatibleHeader)
        }
    }

    func test_append_throwsFileNotWritableWhenMaximumBytesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(
            sizedToFit: LorumIpsum.messages.dropLast(),
            overwritesOldMessages: false,
            zeroOutExistingFile: false)
        XCTAssertThrowsError(try sut.append(message: LorumIpsum.messages.last!)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileNotWritable)
        }
    }

    func test_append_throwsFileNotWritableWhenOverwritesOldMessagesDoesNotMatch() throws {
        let originalCache = try createCache(overwritesOldMessages: false)
        XCTAssertTrue(try originalCache.isWritable())

        let sut = try createCache(overwritesOldMessages: true, zeroOutExistingFile: false)
        XCTAssertThrowsError(try sut.append(message: LorumIpsum.messages.last!)) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.fileNotWritable)
        }
    }

    func test_messages_canReadMessagesWrittenByADifferentCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        let secondCache = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_canReadMessagesWrittenByADifferentFullCache() throws {
        let cache = try createCache(overwritesOldMessages: false, maximumByteSubtractor: 1)
        for message in LorumIpsum.messages.dropLast() {
            try cache.append(message: message)
        }
        XCTAssertThrowsError(try cache.append(message: LorumIpsum.messages.last!))

        let secondCache = try createCache(overwritesOldMessages: false, maximumByteSubtractor: 1, zeroOutExistingFile: false)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_canReadMessagesWrittenByADifferentOverwritingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in LorumIpsum.messages {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor, zeroOutExistingFile: false)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())
        }
    }

    func test_messages_cacheThatDoesNotOverwrite_canReadMessagesWrittenByAnOverwritingCache() throws {
        let cache = try createCache(overwritesOldMessages: false)
        for message in LorumIpsum.messages {
            try cache.append(message: message)
        }

        let secondCache = try createCache(overwritesOldMessages: true, zeroOutExistingFile: false)
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    func test_messages_cacheThatOverwrites_canReadMessagesWrittenByAnOverwritingCacheWithDifferentMaximumBytes() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true)
            for message in LorumIpsum.messages {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor, zeroOutExistingFile: false)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())
        }
    }

    func test_messages_cacheThatOverwrites_canReadMessagesWrittenByANonOverwritingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in LorumIpsum.messages {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: false, zeroOutExistingFile: false)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())
        }
    }

    func test_messages_cacheThatDoesNotOverwrite_canReadMessagesWrittenByAnOverwritingCacheWithDifferentMaximumBytes() throws {
        for maximumByteDivisor in stride(from: 1, to: 50, by: 0.5) {
            let cache = try createCache(overwritesOldMessages: false)
            for message in LorumIpsum.messages {
                try cache.append(message: message)
            }

            let secondCache = try createCache(overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor, zeroOutExistingFile: false)
            XCTAssertEqual(try cache.messages(), try secondCache.messages())
        }
    }

    func test_messages_throwsIncompatibleHeaderWhenHeaderVersionDoesNotMatch() throws {
        let originalHeader = try createHeaderHandle(
            overwritesOldMessages: false,
            version: 0)
        try originalHeader.synchronizeHeaderData()

        let sut = try createCache(
            overwritesOldMessages: false,
            zeroOutExistingFile: false)
        XCTAssertThrowsError(try sut.messages()) {
            XCTAssertEqual($0 as? CacheAdvanceError, CacheAdvanceError.incompatibleHeader)
        }
    }

    // MARK: Private

    private func requiredByteCount<T: Codable>(for messages: [T]) throws -> UInt64 {
        let encoder = JSONEncoder()
        return try FileHeader.expectedEndOfHeaderInFile
            + messages.reduce(0) { allocatedSize, message in
                let encodableMessage = EncodableMessage(message: message, encoder: encoder)
                let data = try encodableMessage.encodedData()
                return allocatedSize + UInt64(data.count)
        }
    }

    private func createHeaderHandle(
        sizedToFit messages: [TestableMessage] = LorumIpsum.messages,
        overwritesOldMessages: Bool,
        maximumByteDivisor: Double = 1,
        maximumByteSubtractor: Bytes = 0,
        version: UInt8 = FileHeader.version,
        zeroOutExistingFile: Bool = true)
        throws
        -> CacheHeaderHandle
    {
        if zeroOutExistingFile {
            FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil)
        }
        return try CacheHeaderHandle(
            forReadingFrom: testFileLocation,
            maximumBytes: Bytes(Double(try requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
            overwritesOldMessages: overwritesOldMessages,
            version: version)
    }

    private func createCache(
        sizedToFit messages: [TestableMessage] = LorumIpsum.messages,
        overwritesOldMessages: Bool,
        maximumByteDivisor: Double = 1,
        maximumByteSubtractor: Bytes = 0,
        zeroOutExistingFile: Bool = true)
        throws
        -> CacheAdvance<TestableMessage>
    {
        if zeroOutExistingFile {
            FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil)
        }
        return try CacheAdvance<TestableMessage>(
            fileURL: testFileLocation,
            maximumBytes: Bytes(Double(try requiredByteCount(for: messages)) / maximumByteDivisor) - maximumByteSubtractor,
            shouldOverwriteOldMessages: overwritesOldMessages)
    }

    private func expectedMessagesInOverwritingCache(
        givenOriginal messages: [TestableMessage],
        newMessageCount: Int)
        -> [TestableMessage]
    {
        Array(messages.dropFirst(messages.count - newMessageCount))
    }

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheAdvanceTests")
}
