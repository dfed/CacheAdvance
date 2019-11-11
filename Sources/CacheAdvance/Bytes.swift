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
public typealias Bytes = UInt64

extension Bytes {

    /// Initializes Bytes from a data blob.
    /// - Parameter data: A data blob representing Bytes. Must be of length `Data.oldestMessageOffsetLength`.
    init?(_ data: Data) {
        guard data.count == Data.oldestMessageOffsetLength else {
            // Data is of the incorrect size and can't represent Bytes.
            return nil
        }
        let decodedSize = withUnsafePointer(to: data) {
            return UnsafeRawBufferPointer(start: $0, count: MemoryLayout<Bytes>.size)
        }
        self = NSSwapBigBytesToHost(decodedSize.load(as: Bytes.self))
    }

}

private func NSSwapBigBytesToHost(_ x: Bytes) -> Bytes {
    return NSSwapBigLongLongToHost(x)
}
