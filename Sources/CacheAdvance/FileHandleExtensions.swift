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
		#if os(Linux)
			if let data = try read(upToCount: length) {
				data
			} else {
				Data()
			}
		#else
			if #available(iOS 13.4, tvOS 13.4, watchOS 6.2, macOS 10.15.4, *) {
				if let data = try read(upToCount: length) {
					data
				} else {
					Data()
				}
			} else {
				try __readDataUp(toLength: length)
			}
		#endif
	}

	/// A method to write data to a file handle that is safe to call in Swift from any operation system version.
	func write(data: Data) throws {
		#if os(Linux)
			try write(contentsOf: data)
		#else
			if #available(iOS 13.4, tvOS 13.4, watchOS 6.2, macOS 10.15.4, *) {
				try write(contentsOf: data)
			} else {
				try __write(data, error: ())
			}
		#endif
	}

	/// A method to seek on a file handle that is safe to call in Swift from any operation system version.
	func seek(to offset: UInt64) throws {
		try seek(toOffset: offset)
	}

	/// A method to close a file handle that is safe to call in Swift from any operation system version.
	func closeHandle() throws {
		try close()
	}

	/// A method to truncate a file handle that is safe to call in Swift from any operation system version.
	func truncate(at offset: UInt64) throws {
		try truncate(atOffset: offset)
	}
}
