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

/// A storage unit that counts bytes.
///
/// - Warning: If this value is changed, previously persisted message encodings will not be readable.
public typealias Bytes = UInt64

extension Bytes {

    /// Initializes the receiver from a data blob.
    ///
    /// - Parameter data: A data blob representing Bytes. Must be of length `Data.bytesStorageLength`.
    init?(_ data: Data) {
        guard data.count == Data.bytesStorageLength else {
            // Data is of the incorrect size and can't represent Bytes.
            return nil
        }
        let decodedSize = withUnsafePointer(to: data) {
            return UnsafeRawBufferPointer(start: $0, count: Data.bytesStorageLength)
        }
        self = NSSwapBigBytesToHost(decodedSize.load(as: Bytes.self))
    }

    /// Converts megabytes into the receiver. Will never overflow.
    ///
    /// - Parameter megabytes: The number of megabytes to convert.
    ///
    /// - Note: `megabytes` are converted to `bytes` by multiplying by 1,000,000.
    ///         This conversion matches how Apple's systems measure megabytes.
    init(megabytes: UInt8) {
        self = Bytes(megabytes) * 1000000
    }

}

private func NSSwapBigBytesToHost(_ x: Bytes) -> Bytes {
    return NSSwapBigLongLongToHost(x)
}
