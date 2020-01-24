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

final class CacheReaderTests: XCTestCase {

    // MARK: Behavior Tests

    func test_messages_canReadMessagesWrittenByADifferentCache() throws {
        let cache = try CacheAdvanceTests.createCache(at: Self.testFileLocation, overwritesOldMessages: false)
        for message in CacheAdvanceTests.lorumIpsumMessages {
            try cache.append(message: message)
        }

        let reader = try CacheReader(fileURL: Self.testFileLocation)
        XCTAssertEqual(try cache.messages(), try reader.messages())
    }

    func test_messages_canReadMessagesWrittenByADifferentFullCache() throws {
        let cache = try CacheAdvanceTests.createCache(at: Self.testFileLocation, overwritesOldMessages: false, maximumByteSubtractor: 1)
        for message in CacheAdvanceTests.lorumIpsumMessages.dropLast() {
            try cache.append(message: message)
        }
        XCTAssertThrowsError(try cache.append(message: CacheAdvanceTests.lorumIpsumMessages.last!))

        let reader = try CacheReader(fileURL: Self.testFileLocation)
        XCTAssertEqual(try cache.messages(), try reader.messages())
    }

    func test_messages_canReadMessagesWrittenByADifferentOverwritingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 10, by: 0.5) {
            let cache = try CacheAdvanceTests.createCache(at: Self.testFileLocation, overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in CacheAdvanceTests.lorumIpsumMessages {
                try cache.append(message: message)
            }

            let reader = try CacheReader(fileURL: Self.testFileLocation)
            XCTAssertEqual(try cache.messages(), try reader.messages())
        }
    }

    func test_messages_cacheThatDoesNotOverwrite_canReadMessagesWrittenByAnOverwritingCache() throws {
        let cache = try CacheAdvanceTests.createCache(at: Self.testFileLocation, overwritesOldMessages: false)
        for message in CacheAdvanceTests.lorumIpsumMessages {
            try cache.append(message: message)
        }

        let reader = try CacheReader(fileURL: Self.testFileLocation)
        XCTAssertEqual(try cache.messages(), try reader.messages())
    }

    func test_messages_cacheThatOverwrites_canReadMessagesWrittenByANonOverwritingCache() throws {
        for maximumByteDivisor in stride(from: 1, to: 10, by: 0.5) {
            let cache = try CacheAdvanceTests.createCache(at: Self.testFileLocation, overwritesOldMessages: true, maximumByteDivisor: maximumByteDivisor)
            for message in CacheAdvanceTests.lorumIpsumMessages {
                try cache.append(message: message)
            }

            let reader = try CacheReader(fileURL: Self.testFileLocation)
            XCTAssertEqual(try cache.messages(), try reader.messages())
        }
    }

    private static let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheReaderTests")
}
