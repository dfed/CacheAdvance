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

import SwiftTryCatch
import XCTest

final class SwiftTryCatchTests: XCTestCase {

    func test_try_catchesObjectiveCFailure() {
        let doomedFileHandle = FileHandle(fileDescriptor: 101)
        var didCatch = false
        SwiftTryCatch.try({
            // This will raise an exception.
            doomedFileHandle.readData(ofLength: 5)
        }, catch: { exception in
            XCTAssertNotNil(exception)
            didCatch = true
        })
        XCTAssertTrue(didCatch)
    }

    func test_try_stopsExecutingOnRaise() {
        let doomedFileHandle = FileHandle(fileDescriptor: 101)
        var didStopAfterRaisedException = false
        SwiftTryCatch.try({
            didStopAfterRaisedException = true
            // This will raise an exception.
            doomedFileHandle.readData(ofLength: 5)
            didStopAfterRaisedException = false
        }, catch: { _ in })

        XCTAssertTrue(didStopAfterRaisedException)
    }

    func test_try_doesNotExecuteCatchIfNoExceptionThrown() {
        var didCatch = false
        SwiftTryCatch.try({
            // Nothing to do here.
        }, catch: { exception in
            didCatch = true
        })
        XCTAssertFalse(didCatch)
    }

    func test_try_executesTryBeforeCatch() {
        let doomedFileHandle = FileHandle(fileDescriptor: 101)
        var tryExecuteCount = 0
        var catchExecuteCount = 0
        SwiftTryCatch.try({
            tryExecuteCount += 1
            // This will raise an exception.
            doomedFileHandle.readData(ofLength: 5)
        }, catch: { exception in
            XCTAssertEqual(tryExecuteCount, 1)
            catchExecuteCount += 1
        })
        XCTAssertEqual(catchExecuteCount, 1)
    }

}
