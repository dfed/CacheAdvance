//
//  Created by Dan Federman on 12/20/19.
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

struct TestableMessage: Codable, ExpressibleByStringLiteral, Equatable {
	typealias StringLiteralType = String

	init(stringLiteral value: Self.StringLiteralType) {
		self.value = value
	}

	let value: String

	static let lorumIpsum = LorumIpsum.messages.map { TestableMessage(stringLiteral: $0) }
}
