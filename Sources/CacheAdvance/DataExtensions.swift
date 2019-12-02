//
//  Created by Dan Federman on 11/10/19.
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

extension Data {

    /// The width of an encoded byte count.
    static let bytesStorageLength = MemoryLayout<Bytes>.size

    /// The width of an encoded message span.
    static let messageSpanStorageLength = MemoryLayout<MessageSpan>.size

    /// A marker written at the end of the newest message written to disk.
    static let endOfNewestMessageMarker = Data(MessageSpan.zero)

    /// Initializes Data from a MessageSpan value. The data will always be of length `Data.messageSpanStorageLength`.
    /// - Parameter value: the value to encode as data.
    init(_ value: MessageSpan) {
        var valueToEncode = value.bigEndian
        self.init(bytes: &valueToEncode, count: Data.messageSpanStorageLength)
    }

    /// Initializes Data from a Bytes value. The data will always be of length `Data.bytesStorageLength`.
    /// - Parameter value: the value to encode as data.
    init(_ value: Bytes) {
        var valueToEncode = value.bigEndian
        self.init(bytes: &valueToEncode, count: Data.bytesStorageLength)
    }
}
