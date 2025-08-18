//
//  Created by Dan Federman on 8/18/25.
//  Copyright © 2025 Dan Federman.
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

/// Whether `measure` tests are enabled. We want this to be disabled in github actions because virtual runners do not have consistent performance characteristics.
let performanceTestsEnabled = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != "true"
