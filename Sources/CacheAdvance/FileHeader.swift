//
//  Created by Dan Federman on 12/26/19.
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

struct FileHeader {

    init(
        version: UInt8 = FileHeader.version,
        maximumBytes: Bytes,
        overwritesOldMessages: Bool,
        offsetInFileOfOldestMessage: UInt64,
        offsetInFileAtEndOfNewestMessage: UInt64)
    {
        self.version = version
        self.maximumBytes = maximumBytes
        self.overwritesOldMessages = overwritesOldMessages
        self.offsetInFileOfOldestMessage = offsetInFileOfOldestMessage
        self.offsetInFileAtEndOfNewestMessage = offsetInFileAtEndOfNewestMessage
    }

    let version: UInt8
    let maximumBytes: Bytes
    let overwritesOldMessages: Bool
    let offsetInFileOfOldestMessage: UInt64
    let offsetInFileAtEndOfNewestMessage: UInt64

    var asData: Data {
        Data(version)
            + Data(maximumBytes)
            + Data(overwritesOldMessages)
            + Data(offsetInFileOfOldestMessage)
            + Data(offsetInFileAtEndOfNewestMessage)
    }

    /// The expected version of the header.
    /// Whenever the format of the header changes, update this value.
    static let version: UInt8 = 1

    /// Calculates the offset in the file where the header should end.
    static var expectedEndOfHeaderInFile: UInt64 {
        // Header format:
        // [headerVersion:UInt8][maximumBytes:UInt64][overwritesOldMessages:Bool][offsetInFileOfOldestMessage:UInt64][offsetInFileAtEndOfNewestMessage:UInt64]
        UInt64(UInt8.storageLength) // headerVersion
            + UInt64(Bytes.storageLength) // maximumBytes
            + UInt64(Bool.storageLength) // overwriteOldMessages
            + UInt64(UInt64.storageLength) // offsetInFileOfOldestMessage
            + UInt64(UInt64.storageLength) // offsetInFileAtEndOfNewestMessage
    }
}
