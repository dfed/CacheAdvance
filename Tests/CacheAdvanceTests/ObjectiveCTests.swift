//
//  SwiftTryCatch.h
//
//  Created by Dan Federman on 12/20/19.
//  Copyright (c) 2019 Dan Federman.
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

final class ObjectiveCTests: XCTestCase {

    func test_unsafe_throwsObjectiveCExceptionOnRaise() {
        let doomedFileHandle = FileHandle(fileDescriptor: 101)
        var didThrow = false
        do {
            _ = try ObjectiveC.unsafe {
                // This will raise an exception.
                doomedFileHandle.readData(ofLength: 5)
            }
        }
        catch {
            didThrow = true
        }
        XCTAssertTrue(didThrow)
    }

    func test_unsafe_doesNotThrowWhenNoExceptionRaise() {
        var didThrow = false
        do {
            _ = try ObjectiveC.unsafe { _ = didThrow }
        }
        catch {
            didThrow = true
        }
        XCTAssertFalse(didThrow)
    }

    func test_unsafe_returnsExpectedValueWhenNoExceptionRaised() {
        XCTAssertTrue(try ObjectiveC.unsafe { true })
    }

}
