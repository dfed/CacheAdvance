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

public enum CacheAdvanceReadError: Error, Equatable {
    /// Thrown when the cache file is of an unexpected format.
    /// A corrupted file should be deleted. Corruption can occur if an application crashes while writing to the file.
    case fileCorrupted
}

public enum CacheAdvanceWriteError: Error, Equatable {
    /// Thrown when the message being appended is larger than maximum bytes.
    case messageDataTooLarge
}