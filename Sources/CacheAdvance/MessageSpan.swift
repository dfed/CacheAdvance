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

/// A storage unit that measures message length.
/// - Warning: If this value is changed, previously persisted message encodings will not be readable.
typealias MessageSpan = UInt32

extension MessageSpan {

    /// Initializes a MessageSpan from a data blob.
    /// - Parameter data: A data blob representing a MessageSpan. Must be of length `Data.messageSpanStorageLength`.
    init?(_ data: Data) {
        guard data.count == Data.messageSpanStorageLength else {
            // Data is of the incorrect size and can't represent a MessageSpan.
            return nil
        }
        let decodedSize = withUnsafePointer(to: data) {
            return UnsafeRawBufferPointer(start: $0, count: Data.messageSpanStorageLength)
        }
        self = NSSwapBigMessageSpanToHost(decodedSize.load(as: MessageSpan.self))
    }

}

private func NSSwapBigMessageSpanToHost(_ x: MessageSpan) -> MessageSpan {
    return NSSwapBigIntToHost(x)
}
