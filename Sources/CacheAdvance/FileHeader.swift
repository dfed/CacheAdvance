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

    init?(from data: Data) {
        guard data.count == FileHeader.expectedEndOfHeaderInFile else {
            return nil
        }

        let versionData = data.subdata(in: FileHeader.Field.version.rangeOfFieldInFile)
        let maximumBytesData = data.subdata(in: FileHeader.Field.maximumBytes.rangeOfFieldInFile)
        let overwritesOldMessagesData = data.subdata(in: FileHeader.Field.overwriteOldMessages.rangeOfFieldInFile)
        let offsetInFileOfOldestMessageData = data.subdata(in: FileHeader.Field.offsetInFileOfOldestMessage.rangeOfFieldInFile)
        let offsetInFileAtEndOfNewestMessageData = data.subdata(in: FileHeader.Field.offsetInFileAtEndOfNewestMessage.rangeOfFieldInFile)

        let version = UInt8(versionData)
        let maximumBytes = Bytes(maximumBytesData)
        let overwritesOldMessages = Bool(overwritesOldMessagesData)
        let offsetInFileOfOldestMessage = UInt64(offsetInFileOfOldestMessageData)
        let offsetInFileAtEndOfNewestMessage = UInt64(offsetInFileAtEndOfNewestMessageData)

        self = FileHeader(
            version: version,
            maximumBytes: maximumBytes,
            overwritesOldMessages: overwritesOldMessages,
            offsetInFileOfOldestMessage: offsetInFileOfOldestMessage,
            offsetInFileAtEndOfNewestMessage: offsetInFileAtEndOfNewestMessage)
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
    /// Whenever there is a breaking change to the header format, update this value.
    static let version: UInt8 = 1

    /// Calculates the offset in the file where the header should end.
    static var expectedEndOfHeaderInFile = Field(rawValue: Field.allCases.endIndex)!.expectedEndOfFieldInFile

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
        case .reservedSpace:
            return Data(repeating: 0, count: field.storageLength)
        }
    }

    enum Field: Int, CaseIterable {
        // Header format:
        // [headerVersion:UInt8][maximumBytes:UInt64][overwritesOldMessages:Bool][offsetInFileOfOldestMessage:UInt64][offsetInFileAtEndOfNewestMessage:UInt64][reservedSpace]

        case version = 1
        case maximumBytes
        case overwriteOldMessages
        case offsetInFileOfOldestMessage
        case offsetInFileAtEndOfNewestMessage
        case reservedSpace

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
            case .reservedSpace:
                // Subtract from this value every time another additive field is added.
                // We currently have a total of 64 bytes reserved for the header.
                // We're currently using only 26 of them.
                return 38
            }
        }

        var rangeOfFieldInFile: Range<Int> {
            Int(expectedBeginningOfFieldInFile)..<Int(expectedEndOfFieldInFile)
        }
        var expectedBeginningOfFieldInFile: UInt64 {
            expectedEndOfFieldInFile - UInt64(storageLength)
        }
        var expectedEndOfFieldInFile: UInt64 {
            Field.allCases.dropLast(Field.allCases.count - rawValue).reduce(0) { totalOffset, currentField in
                totalOffset + UInt64(currentField.storageLength)
            }
        }
    }
}
