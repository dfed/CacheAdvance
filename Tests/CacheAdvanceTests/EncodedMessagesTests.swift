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

final class EncodedMessageTests: XCTestCase {

    func test_encodedMessage_encodesCorrectSize() {
        let data = Data("This is a test".utf8)
        let encodedMessage = EncodedMessages<String>.EncodedMessageIterator.encodedMessage(from: data)
        let encodedSizePrefix = EncodedMessages<String>.EncodedMessageIterator.sizePrefix(atOffset: 0, in: encodedMessage)
        XCTAssertEqual(encodedSizePrefix, UInt32(data.count))
    }

    func test_encodedMessage_isOfCorrectLength() {
        let data = Data("This is a test".utf8)
        let encodedMessage = EncodedMessages<String>.EncodedMessageIterator.encodedMessage(from: data)
        XCTAssertEqual(encodedMessage.count, data.count + MessageSizeLength)
    }

    func test_encodedMessage_hasDataPostfix() {
        let data = Data("This is a test".utf8)
        let encodedMessage = EncodedMessages<String>.EncodedMessageIterator.encodedMessage(from: data)
        XCTAssertEqual(encodedMessage.advanced(by: MessageSizeLength), data)
    }

    func test_endOfNextMessage_isCorrect() {
        let data = Data("This is a test".utf8)
        let encodedMessage = EncodedMessages<String>.EncodedMessageIterator.encodedMessage(from: data)
        XCTAssertEqual(EncodedMessages<String>.EncodedMessageIterator.endOfNextMessage(atOffset: 0, in: encodedMessage), encodedMessage.count)
    }

    func test_decodedMessages_isEqualToInputMessages() throws {
        let messages = [
            "This is a test",
            "It might work",
            "I sincerely hope it does",
            "If it doesn't, this test should catch it",
            "Which is what matters, in the end",
        ]
        let encodedMessages = try EncodedMessages<String>(
            messages: messages,
            encoder: JSONEncoder())

        XCTAssertEqual(messages, encodedMessages.decodedMessages)
    }

}
