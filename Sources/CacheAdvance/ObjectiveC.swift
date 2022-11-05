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
#if SWIFT_PACKAGE_MANAGER
// Swift Package Manager defines multiple modules, while other distribution mechanisms do not.
// We only need to import SwiftTryCatch if this project is being built with Swift Package Manager.
import SwiftTryCatch
#endif

/// A class that enables Objective-C code that would normally be unsafe to call from Swift to be safe.
final class ObjectiveC {

    /// Attempts to execute work that may raise an Objective-C exception.
    /// If an exception is raised, it is caught, and then thrown as a Swift `Error`.
    ///
    /// - Parameter work: Work that may raise an Objective-C exception.
    static func unsafe<T>(_ work: () -> T) throws -> T {
        var result: Result<T, Error> = .failure(ObjectiveCTryFailure())
        SwiftTryCatch.try({
            result = .success(work())
        }, catch: { exception in
            result = .failure(ObjectiveCError(
                exceptionName: exception.name,
                reason: exception.reason))
        })

        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}

/// A sentinel error to indicate that our Objective-C try/catch block didn't work as intended.
struct ObjectiveCTryFailure: Error {}

/// A `throw`able NSException.
struct ObjectiveCError: Error {
    let exceptionName: NSExceptionName
    let reason: String?
}
