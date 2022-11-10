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

extension FileHandle {

    // MARK: Internal

    /// A method to read data from a file handle that is safe to call in Swift from any operation system version.
    func readDataUp(toLength length: Int) throws -> Data {
        if #available(iOS 13.4, tvOS 13.4, watchOS 6.2, macOS 10.15.4, *) {
            if let data = try read(upToCount: length) {
                return data
            } else {
                return Data()
            }
        } else if #available(iOS 13.0, tvOS 13.0, watchOS 6.2, macOS 10.15, *) {
            return try __readDataUp(toLength: length)
        } else {
            return try ObjectiveC.unsafe { readData(ofLength: length) }
        }
    }

    /// A method to write data to a file handle that is safe to call in Swift from any operation system version.
    func write(data: Data) throws {
        if #available(iOS 13.4, tvOS 13.4, watchOS 6.2, macOS 10.15.4, *) {
            return try write(contentsOf: data)
        } else if #available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
            return try __write(data, error: ())
        } else {
            return try ObjectiveC.unsafe { write(data) }
        }
    }

    /// A method to seek on a file handle that is safe to call in Swift from any operation system version.
    func seek(to offset: UInt64) throws {
        if #available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
            return try seek(toOffset: offset)
        } else {
            return try ObjectiveC.unsafe { seek(toFileOffset: offset) }
        }
    }

    /// A method to close a file handle that is safe to call in Swift from any operation system version.
    func closeHandle() throws {
        if #available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
            return try close()
        } else {
            return try ObjectiveC.unsafe { closeFile() }
        }
    }

    /// A method to truncate a file handle that is safe to call in Swift from any operation system version.
    func truncate(at offset: UInt64) throws {
        if #available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
            return try truncate(atOffset: offset)
        } else {
            return try ObjectiveC.unsafe { truncateFile(atOffset: offset) }
        }
    }
}
