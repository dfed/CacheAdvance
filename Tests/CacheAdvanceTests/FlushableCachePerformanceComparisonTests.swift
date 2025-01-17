//
//  Created by Dan Federman on 4/26/20.
//  Copyright © 2020 Dan Federman.
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

import XCTest

final class FlushableCachePerformanceComparisonTests: XCTestCase {

    // MARK: XCTestCase

    override func setUp() {
        super.setUp()

        // Delete the existing cache.
        XCTAssertTrue(FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil))
    }

    // MARK: Behavior Tests

    func test_append_flushableCache_fillableCache_canMaintainMaxCount() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: false)
        for message in TestableMessage.lorumIpsum + TestableMessage.lorumIpsum {
            try cache.appendMessage(message)
        }

        XCTAssertEqual(try cache.messages().count, TestableMessage.lorumIpsum.count)
    }

    func test_messages_flushableCache_fillableCache_canReadInsertedMessages() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: true)
        for message in TestableMessage.lorumIpsum {
            try cache.appendMessage(message)
        }

        XCTAssertEqual(try cache.messages(), TestableMessage.lorumIpsum)
    }

    func test_append_flushableCache_overwritingCache_canMaintainMaxCount() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: true)
        for message in TestableMessage.lorumIpsum + TestableMessage.lorumIpsum {
            try cache.appendMessage(message)
        }

        XCTAssertEqual(try cache.messages().count, TestableMessage.lorumIpsum.count)
    }

    func test_append_flushableCache_overwritingCache_storesOnlyMostRecentMessages() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: true)
        for message in TestableMessage.lorumIpsum {
            try cache.appendMessage(message)
        }
        try cache.appendMessage(#function)

        XCTAssertEqual(try cache.messages(), Array(TestableMessage.lorumIpsum.dropFirst()) + [#function])
    }

    func test_messages_flushableCache_overwritingCache_canReadInsertedMessages() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: true)
        for message in TestableMessage.lorumIpsum {
            try cache.appendMessage(message)
        }

        XCTAssertEqual(try cache.messages(), TestableMessage.lorumIpsum)
    }

    // MARK: Performance Tests

    func test_performance_flushableCache_createCacheAndAppendSingleMessageAndFlush() {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: false)
        measure {
            try? cache.appendMessage("test message")
            try? cache.flushMessages()

            // Prepare ourselves for the next run.
            cache.dropMessages()
        }
    }

    func test_performance_flushableCache_appendAndFlush_fillableCache() {
         let cache = FlushableCache<TestableMessage>(
             location: testFileLocation,
             maxMessageCount: TestableMessage.lorumIpsum.count,
             shouldOverwriteMessages: false)
        measure {
            for message in TestableMessage.lorumIpsum {
                try? cache.appendMessage(message)
                try? cache.flushMessages()
            }

            // Prepare ourselves for the next run.
            cache.dropMessages()
        }
    }

    func test_performance_flushableCache_appendAndFlush_overwritingCache() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: true)

        // Fill the cache before the test starts.
        for message in TestableMessage.lorumIpsum {
            try cache.appendMessage(message)
        }
        measure {
            for message in TestableMessage.lorumIpsum {
                try? cache.appendMessage(message)
                try? cache.flushMessages()
            }
        }
    }

    func test_performance_flushableCache_appendAndFlushEvery50Messages_fillableCache() {
          let cache = FlushableCache<TestableMessage>(
              location: testFileLocation,
              maxMessageCount: TestableMessage.lorumIpsum.count,
              shouldOverwriteMessages: false)
         measure {
            for (index, message) in TestableMessage.lorumIpsum.enumerated() {
                try? cache.appendMessage(message)
                if index % 50 == 0 {
                    try? cache.flushMessages()
                }
            }

            // Prepare ourselves for the next run.
            cache.dropMessages()
        }
    }

    func test_performance_flushableCache_appendAndFlushEvery50Messages_overwritingCache() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: true)

        // Fill the cache before the test starts.
        for message in TestableMessage.lorumIpsum {
            try cache.appendMessage(message)
        }
        measure {
            for (index, message) in TestableMessage.lorumIpsum.enumerated() {
                try? cache.appendMessage(message)
                if index % 50 == 0 {
                    try? cache.flushMessages()
                }
            }
        }
    }

    func test_performance_flushableCache_messages_fillableCache() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: false)
        for message in TestableMessage.lorumIpsum {
            try cache.appendMessage(message)
        }
        try cache.flushMessages()
        measure {
            let freshCache = FlushableCache<TestableMessage>(
                location: testFileLocation,
                maxMessageCount: TestableMessage.lorumIpsum.count,
                shouldOverwriteMessages: false)
            _ = try? freshCache.messages()
        }
    }

    func test_performance_flushableCache_messages_overwritingCache() throws {
        let cache = FlushableCache<TestableMessage>(
            location: testFileLocation,
            maxMessageCount: TestableMessage.lorumIpsum.count,
            shouldOverwriteMessages: true)
        for message in TestableMessage.lorumIpsum + TestableMessage.lorumIpsum {
            try? cache.appendMessage(message)
        }
        try cache.flushMessages()
        measure {
            let freshCache = FlushableCache<TestableMessage>(
                location: testFileLocation,
                maxMessageCount: TestableMessage.lorumIpsum.count,
                shouldOverwriteMessages: true)
            _ = try? freshCache.messages()
        }
    }

    // MARK: Private

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("SQLiteTests")
}

/// A simple in-memory cache that can be flushed to disk.
class FlushableCache<T: Codable> {

    // MARK: Initialization

    init(
        location: URL,
        maxMessageCount: Int,
        shouldOverwriteMessages: Bool)
    {
        self.location = location
        self.maxMessageCount = maxMessageCount
        self.shouldOverwriteMessages = shouldOverwriteMessages
    }

    // MARK: Internal

    func appendMessage(_ message: T) throws {
        var updatedMessages = try messages() + [message]
        if updatedMessages.count > maxMessageCount {
            guard shouldOverwriteMessages else {
                // We do not have room for this message.
                return
            }
            updatedMessages = Array(updatedMessages.dropFirst())
        }

        _messages = updatedMessages
    }

    func messages() throws -> [T] {
        if let _messages = _messages {
            return _messages
        } else {
            let persistedData = try Data(contentsOf: location)
            guard !persistedData.isEmpty else {
                _messages = []
                return []
            }
            let persistedMessages = try decoder.decode([T].self, from: persistedData)
            _messages = persistedMessages
            return persistedMessages
        }
    }

    func flushMessages() throws {
        try encoder.encode(try messages()).write(to: location)
    }

    func dropMessages() {
        _messages = []
    }

    // MARK: Private

    private var _messages: [T]?

    private let location: URL
    private let maxMessageCount: Int
    private let shouldOverwriteMessages: Bool
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

}
