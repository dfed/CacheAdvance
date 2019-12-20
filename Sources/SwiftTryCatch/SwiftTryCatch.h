//
//  SwiftTryCatch.h
//
//  Created by William Falcon on 10/10/14.
//  Copyright (c) 2014 William Falcon.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SwiftTryCatch : NSObject

/**
 Provides try catch functionality for swift by wrapping around Objective-C
 */

+ (void)try:(__attribute__((noescape)) void(^ _Nonnull)(void))try catch:(__attribute__((noescape)) void(^ _Nonnull)(NSException *exception))catch finally:(__attribute__((noescape)) void(^ _Nullable)(void))finally;
@end

NS_ASSUME_NONNULL_END
