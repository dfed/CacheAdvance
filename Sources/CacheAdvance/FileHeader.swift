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

    // MARK: Lifecycle

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

    // MARK: Internal

    let version: UInt8
    let maximumBytes: Bytes
    let overwritesOldMessages: Bool
    let offsetInFileOfOldestMessage: UInt64
    let offsetInFileAtEndOfNewestMessage: UInt64

    var asData: Data {
        Field.allCases.reduce(Data()) { header, field in
            header + data(for: field)
        }
    }

    /// The expected version of the header.
    /// Whenever the format of the header changes, update this value.
    static let version: UInt8 = 1

    /// Calculates the offset in the file where the header should end.
    static var expectedEndOfHeaderInFile = Field.endOfHeaderMarker.expectedEndOfFieldInFile

    func data(for field: Field) -> Data {
        switch field {
            case .version:
                return Data(version)
            case .maximumBytes:
                return Data(maximumBytes)
            case .overwriteOldMessages:
                return Data(overwritesOldMessages)
            case .offsetInFileOfOldestMessage:
                return Data(offsetInFileOfOldestMessage)
            case .offsetInFileAtEndOfNewestMessage:
                return Data(offsetInFileAtEndOfNewestMessage)
            case .endOfHeaderMarker:
                return Data()
        }
    }

    enum Field: Int, CaseIterable {
        // Header format:
        // [headerVersion:UInt8][maximumBytes:UInt64][overwritesOldMessages:Bool][offsetInFileOfOldestMessage:UInt64][offsetInFileAtEndOfNewestMessage:UInt64]

        case version = 0
        case maximumBytes
        case overwriteOldMessages
        case offsetInFileOfOldestMessage
        case offsetInFileAtEndOfNewestMessage
        // This case must always be last.
        case endOfHeaderMarker

        var storageLength: Int {
            switch self {
            case .version:
                return UInt8.storageLength
            case .maximumBytes:
                return Bytes.storageLength
            case .overwriteOldMessages:
                return Bool.storageLength
            case .offsetInFileOfOldestMessage:
                return UInt64.storageLength
            case .offsetInFileAtEndOfNewestMessage:
                return UInt64.storageLength
            case .endOfHeaderMarker:
                return 0
            }
        }

        var expectedBeginningOfFieldInFile: UInt64 {
            expectedEndOfFieldInFile - UInt64(storageLength)
        }
        var expectedEndOfFieldInFile: UInt64 {
            Field.allCases.dropLast(Field.allCases.count - rawValue - 1).reduce(0) { totalOffset, currentField in
                totalOffset + UInt64(currentField.storageLength)
            }
        }
    }
}
