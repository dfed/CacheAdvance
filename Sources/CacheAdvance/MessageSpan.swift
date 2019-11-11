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

/// If this value is changed, any previously persisted message encodings will not be readible.
typealias MessageSpan = UInt32

extension MessageSpan {

    /// Initializes a MessageSpan from a data blob.
    /// - Parameter data: A data blob representing a UInt32. Must be of length `Data.messageSpanLength`.
    init?(_ data: Data) {
        guard data.count == Data.messageSpanLength else {
            // Data is of the incorrect size and can't represent a UInt32.
            return nil
        }
        let decodedSize = withUnsafePointer(to: data) {
            return UnsafeRawBufferPointer(start: $0, count: MemoryLayout<MessageSpan>.size)
        }
        self = decodedSize.load(as: MessageSpan.self)
    }

}
