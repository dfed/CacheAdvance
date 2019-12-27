//
//  Created by Dan Federman on 12/25/19.
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

extension Bool {

    /// Initializes encodable data from a data blob.
    ///
    /// - Parameter data: A data blob representing encodable data. Must be of length `Self.storageLength`.
    init?(_ data: Data)  {
        guard let integerRepresentation = UInt8(data) else {
            return nil
        }
        self = integerRepresentation == 1 ? true : false
    }

    static var storageLength: Int { UInt8.storageLength }
}

extension Data {

    /// Initializes Data from a numeric value. The data will always be of length 1.
    /// - Parameter value: the value to encode as data.
    init(_ value: Bool) {
        self.init(UInt8(value ? 1 : 0))
    }

}
