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

    /// The width of the encoded message size.
    static let messageSpanLength = MemoryLayout<MessageSpan>.size

    /// A marker written at the end of the newest message written to disk.
    static let endOfNewestMessageMarker = Data(MessageSpan.zero)

    /// The width of the encoded oldest message offset.
    static let offsetOfFirstMessageLength = MemoryLayout<Bytes>.size

    /// Initializes Data from a MessageSpan. The data will always be of length Data.messageSpanLength.
    /// - Parameter value: the MessageSpan to encode as data.
    init(_ value: MessageSpan) {
        var valueToEncode = value.bigEndian
        self.init(bytes: &valueToEncode, count: Data.messageSpanLength)
    }

    init(_ value: Bytes) {
        var valueToEncode = value.bigEndian
        self.init(bytes: &valueToEncode, count: Data.offsetOfFirstMessageLength)
    }
}
