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
// This import works when working within the generated CacheAdvance.xcodeproj used in CI.
#import <CADCacheAdvance/CADCacheAdvance-Swift.h>
#import <LorumIpsum/LorumIpsum-Swift.h>
#else
// This import works when working within Package.swift.
@import CADCacheAdvance;
@import LorumIpsum;
#endif
@import XCTest;

/// Tests that exercise the API of CADCacheAdvance.
/// - Note: Since CADCacheAdvance is a thin wrapper on CacheAdvance<Data>, these tests are intended to do nothing more than exercise the API.
@interface CADCacheAdvanceTests : XCTestCase
@end

@implementation CADCacheAdvanceTests

// MARK: Behavior Tests

- (void)test_fileURL_returnsUnderlyingFileURL;
{
    CADCacheAdvance *const cache = [self createCacheThatOverwitesOldMessages:YES];
    XCTAssertEqualObjects(cache.fileURL, [self testFileLocation]);
}

- (void)test_isWritable_returnsTrueForAWritableCache;
{
    CADCacheAdvance *const cache = [self createCacheThatOverwitesOldMessages:YES];
    XCTAssertTrue(cache.isWritable);
}

- (void)test_isEmpty_returnsTrueForAnEmptyCache;
{
    CADCacheAdvance *const cache = [self createCacheThatOverwitesOldMessages:YES];
    XCTAssertTrue(cache.isEmpty);
}

- (void)test_isEmpty_returnsFalseForANonEmptyCache;
{
    CADCacheAdvance *const cache = [self createCacheThatOverwitesOldMessages:YES];
    NSError *error = nil;
    [cache appendMessage:[@"Test" dataUsingEncoding:NSUTF8StringEncoding]
                   error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(cache.isEmpty);
}

- (void)test_messagesAndReturnError_returnsAppendedMessage;
{
    CADCacheAdvance *const cache = [self createCacheThatOverwitesOldMessages:YES];
    NSData *const message = [@"Test" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    [cache appendMessage:message
                   error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([cache messagesAndReturnError:nil], @[message]);
}

// MARK: Performance Tests

- (void)test_performance_append_fillableCache;
{
    CADCacheAdvance *const cache = [self createCacheThatOverwitesOldMessages:NO];
    // Fill the cache before the test starts.
    for (NSString *const message in CADLorumIpsum.messages) {
        [cache appendMessage:[message dataUsingEncoding:NSUTF8StringEncoding]
                       error:nil];
    }

    [self measureBlock:^{
        for (NSString *const message in CADLorumIpsum.messages) {
            [cache appendMessage:[message dataUsingEncoding:NSUTF8StringEncoding]
                           error:nil];
        }
    }];
}

- (void)test_performance_messages_fillableCache;
{
    CADCacheAdvance *const cache = [self createCacheThatOverwitesOldMessages:NO];
    // Fill the cache before the test starts.
    for (NSString *const message in CADLorumIpsum.messages) {
        [cache appendMessage:[message dataUsingEncoding:NSUTF8StringEncoding]
                       error:nil];
    }

    [self measureBlock:^{
        (void)[cache messagesAndReturnError:nil];
    }];
}

// MARK: Private

- (CADCacheAdvance *)createCacheThatOverwitesOldMessages:(BOOL)overwritesOldMessages;
{
    [NSFileManager.defaultManager createFileAtPath:[self testFileLocation].path
                                          contents:nil
                                        attributes:nil];
    NSError *error = nil;
    CADCacheAdvance *const cache = [[CADCacheAdvance alloc]
                                    initWithFileURL:self.testFileLocation
                                    maximumBytes:1000000
                                    shouldOverwriteOldMessages:overwritesOldMessages
                                    error:&error];
    XCTAssertNil(error, "Failed to create cache due to %@", error);
    return cache;
}

- (NSURL *)testFileLocation;
{
    return [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:@"CADCacheAdvanceTests"];
}

@end
