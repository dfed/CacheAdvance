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
import Testing

@testable import CacheAdvance

struct EncodableMessageTests {
	// MARK: Behavior Tests

	@Test
	func encodedData_encodesCorrectSize() throws {
		let message = TestableMessage("This is a test")
		let data = try encoder.encode(message)
		let encodedMessage = EncodableMessage<TestableMessage, MessageSpan>(message: message, encoder: encoder)
		let encodedData = try encodedMessage.encodedData()

		let prefix = encodedData.subdata(in: 0..<MessageSpan.storageLength)
		#expect(MessageSpan(prefix) == MessageSpan(data.count))
	}

	@Test
	func encodedData_isOfCorrectLength() throws {
		let message = TestableMessage("This is a test")
		let data = try encoder.encode(message)
		let encodedMessage = EncodableMessage<TestableMessage, MessageSpan>(message: message, encoder: encoder)
		let encodedData = try encodedMessage.encodedData()
		#expect(encodedData.count == data.count + MessageSpan.storageLength)
	}

	@Test
	func encodedData_hasDataPostfix() throws {
		let message = TestableMessage("This is a test")
		let data = try encoder.encode(message)
		let encodedMessage = EncodableMessage<TestableMessage, MessageSpan>(message: message, encoder: encoder)
		let encodedData = try encodedMessage.encodedData()
		#expect(encodedData.advanced(by: MessageSpan.storageLength) == data)
	}

	@Test
	func encodedData_whenMessageDataTooLarge_throwsError() throws {
		let encodedMessage = EncodableMessage<Data, UInt8>(message: Data(count: Int(UInt8.max)), encoder: encoder)
		#expect(throws: CacheAdvanceError.messageLargerThanCacheCapacity) {
			try encodedMessage.encodedData()
		}
	}

	// MARK: Private

	private let encoder = JSONEncoder()
}
