//
//  Created by Dan Federman on 11/9/19.
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

/// A struct that encodes a message of type T into data.
/// A message is encoded with the following format:
/// `[messageSize][data]`
/// -  `messageSize` is a big-endian encoded `MessageSpan` of length `messageSpanStorageLength`.
/// - `data` is length `messageSize`.
struct EncodableMessage<T: Codable> {

    // MARK: Initialization

    /// Initializes an encoded message from the raw, codable source.
    /// - Parameters:
    ///   - message: The messages to encode.
    ///   - encoder: The encoder to use.
    init(message: T, encoder: MessageEncoder) {
        self.message = message
        self.encoder = encoder
    }

    // MARK: Internal

    /// The encoded message, prefixed with the size of the message blob.
    func encodedData() throws -> Data {
        let messageData = try encoder.encode(message)
        guard messageData.count < MessageSpan.max else {
            // We can't encode the length this message in a MessageSpan.
            throw CacheAdvanceError.messageLargerThanCacheCapacity
        }
        let encodedSize = Data(MessageSpan(messageData.count))
        return encodedSize + messageData
    }

    // MARK: Private

    private let message: T
    private let encoder: MessageEncoder

}
