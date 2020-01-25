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

public enum CacheAdvanceError: Error, Equatable {
    /// Thrown when the message being appended is too large to be stored in a cache of this size.
    case messageLargerThanCacheCapacity
    /// Thrown when a message being appended to a cache that does not overwrite old messages is too large to store in the remaining space.
    case messageLargerThanRemainingCacheSize
    /// Thrown when a cache's persisted header is incompatible with the current implementation.
    case incompatibleHeader
    /// Thrown when the cache file's persisted static header data is inconsistent with the metadata with which the cache was initialized.
    case fileNotWritable
    /// Thrown when the cache file is of an unexpected format.
    /// A corrupted file should be deleted. Corruption can occur if an application crashes while writing to the file.
    case fileCorrupted
}
