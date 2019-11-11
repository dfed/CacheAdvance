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

/// A struct that encodes a message of type T into a data that can be incrementally persisted to disk.
/// A message is encoded with the following format:
/// `[messageSize][data]`
/// -  `messageSize` is length `messageSpanLength`.
/// - `data` is length `messageSize`.
struct EncodableMessage<T: Codable> {

    // MARK: Initialization

    /// Initializes an encoded message from the raw, codable source.
    /// - Parameters:
    ///   - message: The messages to encode.
    ///   - encoder: The encoder to use.
    init(message: T, encoder: JSONEncoder) {
        self.message = message
        self.encoder = encoder
    }

    // MARK: Internal

    /// The encoded message, prefixed with the size of the message blob.
    func encodedData() throws -> Data {
        let messageData = try encoder.encode(message)
        let encodedSize = Data(MessageSpan(messageData.count))
        return encodedSize + messageData
    }

    // MARK: Private

    private let message: T
    private let encoder: JSONEncoder

}
