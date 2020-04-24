//
//  Created by Dan Federman on 4/24/20.
//  Copyright © 2020 Dan Federman.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS"BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if GENERATED_XCODE_PROJECT
// These imports work when working within the generated CacheAdvance.xcodeproj used in CI.
#import <CADCacheAdvance/CADCacheAdvance-Swift.h>
#import <XCTest/XCTest.h>
#else
// These imports work when working within Package.swift.
@import CADCacheAdvance;
@import XCTest;
#endif

/// Tests that exercise the API of CADCacheAdvance.
/// - Note: Since CADCacheAdvance is a thin wrapper on CacheAdvance<Data>, these tests are intended to do nothing more than exercise the API.
@interface CADCacheAdvanceTests : XCTestCase
@end

@implementation CADCacheAdvanceTests

- (void)test_fileURL_returnsUnderlyingFileURL;
{
    CADCacheAdvance *const cache = [self createCache];
    XCTAssertEqualObjects(cache.fileURL, [self testFileLocation]);
}

- (void)test_isWritable_returnsTrueForAWritableCache;
{
    CADCacheAdvance *const cache = [self createCache];
    XCTAssertTrue(cache.isWritable);
}

- (void)test_isEmpty_returnsTrueForAnEmptyCache;
{
    CADCacheAdvance *const cache = [self createCache];
    XCTAssertTrue(cache.isEmpty);
}

- (void)test_isEmpty_returnsFalseForANonEmptyCache;
{
    CADCacheAdvance *const cache = [self createCache];
    NSError *error = nil;
    [cache appendMessage:@"Test"
                error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(cache.isEmpty);
}

- (void)test_messageDataAndReturnError_returnsAppendedMessage;
{
    CADCacheAdvance *const cache = [self createCache];
    NSData *const data = [@"Test" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    [cache appendData:data
                error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([cache messageDataAndReturnError:nil], @[data]);
}

- (void)test_messagesAndReturnError_returnsAppendedMessage;
{
    CADCacheAdvance *const cache = [self createCache];
    NSString *const message = @"Test";
    NSError *error = nil;
    [cache appendMessage:message
                   error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([cache messagesAndReturnError:nil], @[message]);
}

// MARK: Private

- (CADCacheAdvance *)createCache;
{
    [NSFileManager.defaultManager createFileAtPath:[self testFileLocation].path
                                          contents:nil
                                        attributes:nil];
    NSError *error = nil;
    CADCacheAdvance *const cache = [[CADCacheAdvance alloc]
                                    initWithFileURL:self.testFileLocation
                                    maximumBytes:1000000
                                    shouldOverwriteOldMessages:YES
                                    error:&error];
    XCTAssertNil(error, "Failed to create cache due to %@", error);
    return cache;
}

- (NSURL *)testFileLocation;
{
    return [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:@"CADCacheAdvanceTests"];
}

@end
