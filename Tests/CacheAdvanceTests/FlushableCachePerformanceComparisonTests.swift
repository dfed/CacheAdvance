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
        try? Data().write(to: testFileLocation)
    }

    // MARK: Behavior Tests

    func test_readMessages_canReadInsertedMessages() throws {
        let cache = FlushableCache<TestableMessage>(location: testFileLocation)
        for message in LorumIpsum.messages {
            try cache.appendMessage(message)
        }

        XCTAssertEqual(try cache.messages(), LorumIpsum.messages)
    }

    // MARK: Performance Tests

    func test_performance_json_createDatabaseAndAppendSingleMessage() throws {
        measure {
            let cache = FlushableCache<TestableMessage>(location: testFileLocation)
            try? cache.appendMessage("test message")
        }
    }

    func test_performance_json_appendAndFlushOnEachMessage() throws {
        measure {
            // Delete the existing cache.
            try? Data().write(to: testFileLocation)

            let cache = FlushableCache<TestableMessage>(location: testFileLocation)
            for message in LorumIpsum.messages {
                try? cache.appendMessage(message)
                try? cache.flushMessages()
            }
        }
    }

    func test_performance_json_appendAndFlushEvery50Messages() throws {
        measure {
            // Delete the existing cache.
            try? Data().write(to: testFileLocation)

            let cache = FlushableCache<TestableMessage>(location: testFileLocation)
            for (index, message) in LorumIpsum.messages.enumerated() {
                try? cache.appendMessage(message)
                if index % 50 == 0 {
                    try? cache.flushMessages()
                }
            }
        }
    }

    func test_performance_json_messages() throws {
        let cache = FlushableCache<TestableMessage>(location: testFileLocation)
        for message in LorumIpsum.messages {
            try cache.appendMessage(message)
        }
        try cache.flushMessages()
        measure {
            let freshCache = FlushableCache<TestableMessage>(location: testFileLocation)
            _ = try? freshCache.messages()
        }
    }

    // MARK: Private

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("SQLiteTests")

}

/// A simple in-memory cache that can be flushed to disk.
class FlushableCache<T: Codable> {

    // MARK: Initialization

    init(location: URL) {
        self.location = location
    }

    // MARK: Internal

    func appendMessage(_ message: T) throws {
        _messages = try messages() + [message]
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

    // MARK: Private

    private var _messages: [T]?

    private let location: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

}
