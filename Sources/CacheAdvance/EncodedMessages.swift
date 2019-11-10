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

/// The width of the encoded message size. If this value is changed, any previously persisted message encodings will not be readible.
let MessageSizeLength = MemoryLayout<UInt32>.size

/// A struct that encodes messages of type T into a data that can be incrementally persisted to disk.
/// Each message is encoded as a data blob, where the first `MessageSizeLength` of the blob
/// describes the length of the message.
struct EncodedMessages<T: Codable>: Sequence {

    // MARK: Initialization

    /// Initializes an encoded message from the raw, codable source.
    /// - Parameters:
    ///   - message: The messages to encode.
    ///   - encoder: The encoder to use.
    init(messages: [T], encoder: JSONEncoder) throws {
        data = try messages.map {
            let messageData = try encoder.encode($0)
            return EncodedMessageIterator.encodedMessage(from: messageData)
        }.reduce(Data()) { return $0 + $1 }
    }

    /// Initializes an encoded message from data.
    /// - Parameter data: The data from which to extract messages.
    init(data: Data) {
        self.data = data
    }

    // MARK: Sequence

    func makeIterator() -> EncodedMessageIterator {
        return EncodedMessageIterator(data: data, decoder: JSONDecoder())
    }

    // MARK: Internal

    /// `data` as DispatchData
    var dispatchData: DispatchData {
        data.withUnsafeBytes {
            DispatchData(bytes: UnsafeRawBufferPointer(start: $0.baseAddress, count: $0.count))
        }
    }

    /// An array of messages that have been decoded from the stored `data`.
    var decodedMessages: [T] {
        var messages = [T]()
        for message in self {
            messages.append(message)
        }
        return messages
    }

    // MARK: Private

    /// The encoded message, prefixed with the size of the message blob.
    private let data: Data

    struct EncodedMessageIterator: IteratorProtocol {

        init(data: Data, decoder: JSONDecoder) {
            self.data = data
            self.decoder = decoder
        }

        // MARK: IteratorProtocol

        mutating func next() -> T? {
            guard offset < data.count else {
                return nil
            }
            guard let next = try? nextMessage() else {
                // Something went wrong?
                return nil
            }
            offset += endOfNextMessage()
            return next
        }

        // MARK: Internal

        static func encodedMessage(from data: Data) -> Data {
            var size = UInt32(data.count)
            let encodedSize = Data(bytes: &size, count: MessageSizeLength)
            return encodedSize + data
        }

        static func nextMessage(atOffset offset: Int, in data: Data, using decoder: JSONDecoder) throws -> T {
            let messageData = data.subdata(in: (offset + MessageSizeLength)..<(offset + endOfNextMessage(atOffset: offset, in: data)))
            return try decoder.decode(T.self, from: messageData)
        }

        static func endOfNextMessage(atOffset offset: Int, in data: Data) -> Int {
            Int(sizePrefix(atOffset: offset, in: data)) + MessageSizeLength
        }

        static func sizePrefix(atOffset offset: Int, in data: Data) -> UInt32 {
            let prefix = data.subdata(in: offset..<(offset + MessageSizeLength))
            let decodedSize = withUnsafePointer(to: prefix) {
                return UnsafeRawBufferPointer(start: $0, count: MemoryLayout<UInt32>.size)
            }
            return decodedSize.load(as: UInt32.self)
        }

        // MARK: Private

        private func nextMessage() throws -> T {
            try EncodedMessageIterator.nextMessage(atOffset: offset, in: data, using: decoder)
        }

        private func endOfNextMessage() -> Int {
            EncodedMessageIterator.endOfNextMessage(atOffset: offset, in: data)
        }

        private var offset = 0
        private let data: Data
        private let decoder: JSONDecoder

    }

}

