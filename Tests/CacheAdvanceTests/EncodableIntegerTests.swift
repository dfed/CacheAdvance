//
//  Created by Dan Federman on 12/3/19.
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

final class EncodableIntegerTests: XCTestCase {

    // MARK: Behavior Tests

    func test_init_canBeInitializedFromEncodedDta() {
        let expectedValue: UInt64 = 10
        XCTAssertEqual(UInt64(Data(expectedValue)), expectedValue)
    }

    func test_init_returnsNilWhenInitializedFromDataOfIncorrectLength() {
        var expectedValue: UInt64 = 10
        XCTAssertEqual(UInt64(Data(bytes: &expectedValue, count: UInt64.storageLength + 1)), nil)
    }
}
