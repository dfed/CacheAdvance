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
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import XCTest

@testable import CacheAdvance

final class EncodableMessageTests: XCTestCase {

    // MARK: Behavior Tests

    func test_encodedData_encodesCorrectSize() throws {
        let message = "This is a test"
        let data = try encoder.encode(message)
        let encodedMessage = EncodableMessage<String>(message: message, encoder: encoder)
        let encodedData = try encodedMessage.encodedData()

        let prefix = encodedData.subdata(in: 0..<MessageSpan.storageLength)
        XCTAssertEqual(MessageSpan(prefix), MessageSpan(data.count))
    }

    func test_encodedData_isOfCorrectLength() throws {
        let message = "This is a test"
        let data = try encoder.encode(message)
        let encodedMessage = EncodableMessage<String>(message: message, encoder: encoder)
        let encodedData = try encodedMessage.encodedData()
        XCTAssertEqual(encodedData.count, data.count + MessageSpan.storageLength)
    }

    func test_encodedData_hasDataPostfix() throws {
        let message = "This is a test"
        let data = try encoder.encode(message)
        let encodedMessage = EncodableMessage<String>(message: message, encoder: encoder)
        let encodedData = try encodedMessage.encodedData()
        XCTAssertEqual(encodedData.advanced(by: MessageSpan.storageLength), data)
    }

    // MARK: Private

    private let encoder = JSONEncoder()

}
