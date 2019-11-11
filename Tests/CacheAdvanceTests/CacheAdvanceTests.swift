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
//  distributed under the License is distributed on an "AS IS"BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import XCTest

@testable import CacheAdvance

final class CacheAdvanceTests: XCTestCase {

    // MARK: XCTestCase

    override func setUp() {
        super.setUp()
        FileManager.default.createFile(atPath: testFileLocation.path, contents: nil, attributes: nil)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testFileLocation)
    }

    // MARK: Behavior Tests

    func test_append_singleMessageThatFitsCanBeRetrieved() throws {
        let message = "This is a test"
        let cache = try CacheAdvance<String>(
            file: testFileLocation,
            maximumBytes: requiredByteCount(for: [message], cacheWillRoll: false),
            shouldRoll: false)
        XCTAssertTrue(try cache.append(message: message))

        let cachedMessages = try cache.cachedMessages()
        XCTAssertEqual(cachedMessages, [message])
    }

    func test_append_singleMessageFailsIfDoesNotFit() throws {
        let message = "This is a test"
        let cache = try CacheAdvance<String>(
            file: testFileLocation,
            maximumBytes: requiredByteCount(for: [message], cacheWillRoll: false) - 1,
            shouldRoll: false)
        XCTAssertFalse(try cache.append(message: message))

        let cachedMessages = try cache.cachedMessages()
        XCTAssertEqual(cachedMessages, [])
    }

    func test_append_singleMessageThrowsIfDoesNotFitAndCacheRolls() throws {
        let message = "This is a test"
        let cache = try CacheAdvance<String>(
            file: testFileLocation,
            maximumBytes: requiredByteCount(for: [message], cacheWillRoll: true) - 1,
            shouldRoll: true)
        do {
            try cache.append(message: message)
            XCTFail("Appending too-big message was expected to throw")
        } catch CacheAdvanceWriteError.messageDataTooLarge {
            // We hit the expected case.
        } catch {
            XCTFail("Encountered unexpected error \(error)")
        }

        let cachedMessages = try cache.cachedMessages()
        XCTAssertEqual(cachedMessages, [])
    }

    func test_append_multipleMessagesCanBeRetrieved() throws {
        let cache = try CacheAdvance<String>(
            file: testFileLocation,
            maximumBytes: requiredByteCount(for: lorumIpsumMessages, cacheWillRoll: false),
            shouldRoll: false)
        for message in lorumIpsumMessages {
            XCTAssertTrue(try cache.append(message: message))
        }

        let cachedMessages = try cache.cachedMessages()
        XCTAssertEqual(cachedMessages, lorumIpsumMessages)
    }

    func test_append_dropsLastMessageIfCacheDoesNotRollAndLastMessageDoesNotFit() throws {
        let cache = try CacheAdvance<String>(
            file: testFileLocation,
            maximumBytes: requiredByteCount(for: lorumIpsumMessages, cacheWillRoll: false),
            shouldRoll: false)
        for message in lorumIpsumMessages {
            XCTAssertTrue(try cache.append(message: message))
        }

        XCTAssertFalse(try cache.append(message: "This message won't fit"))

        let cachedMessages = try cache.cachedMessages()
        XCTAssertEqual(cachedMessages, lorumIpsumMessages)
    }

    func test_append_dropsFirstMessageIfCacheDoesNotRollAndLastMessageDoesNotFitAndIsShorterThanFirstMessage() throws {
        let cache = try CacheAdvance<String>(
            file: testFileLocation,
            maximumBytes: requiredByteCount(for: lorumIpsumMessages, cacheWillRoll: true),
            shouldRoll: true)
        for message in lorumIpsumMessages {
            XCTAssertTrue(try cache.append(message: message))
        }

        // Append a message that is shorter than the first message in lorumIpsumMessages.
        let shortMessage = "A short message"
        XCTAssertTrue(try cache.append(message: shortMessage))

        let cachedMessages = try cache.cachedMessages()
        XCTAssertEqual(cachedMessages, Array(lorumIpsumMessages.dropFirst()) + [shortMessage])
    }

    func test_append_dropsFirstTwoMessagesIfCacheDoesNotRollAndLastMessageDoesNotFitAndIsLargerThanFirstMessage() throws {
        let cache = try CacheAdvance<String>(
            file: testFileLocation,
            maximumBytes: requiredByteCount(for: lorumIpsumMessages, cacheWillRoll: true),
            shouldRoll: true)
        for message in lorumIpsumMessages {
            XCTAssertTrue(try cache.append(message: message))
        }

        // Append a message that is slightly longer than the first message in lorumIpsumMessages.
        let barelyLongerMessage = lorumIpsumMessages[0] + "hi"
        XCTAssertTrue(try cache.append(message: barelyLongerMessage))

        let cachedMessages = try cache.cachedMessages()
        XCTAssertEqual(cachedMessages, Array(lorumIpsumMessages.dropFirst(2)) + [barelyLongerMessage])
    }

    func test_append_dropsOldMessagesAsNecessary() throws {
        let cache = try CacheAdvance<String>(
            file: testFileLocation,
            maximumBytes: requiredByteCount(for: lorumIpsumMessages, cacheWillRoll: true) / 3,
            shouldRoll: true)
        for message in lorumIpsumMessages {
            XCTAssertTrue(try cache.append(message: message))
        }

        let cachedMessages = try cache.cachedMessages()
        XCTAssertEqual(Array(lorumIpsumMessages.dropFirst(lorumIpsumMessages.count - cachedMessages.count)), cachedMessages)
    }

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheAdvanceTests")
    private let lorumIpsumMessages = [
        "Lorem ipsum dolor sit amet,",
        "consectetur adipiscing elit.",
        "Etiam sagittis neque massa,",
        "id auctor urna elementum at.",
        "Phasellus sit amet mauris posuere,",
        "aliquet eros nec,",
        "posuere odio.",
        "Ut in neque egestas,",
        "vehicula massa non,",
        "consequat augue.",
        "Pellentesque mattis blandit velit,",
        "ut accumsan velit mollis sed.",
        "Praesent ac vehicula metus.",
        "Praesent eu purus justo.",
        "Maecenas arcu risus,",
        "egestas vitae commodo eu,",
        "gravida non ipsum.",
        "Mauris nec ipsum et lacus rhoncus dictum.",
        "Fusce sagittis magna quis iaculis venenatis.",
        "Nullam placerat odio id nulla porttitor,",
        "ultrices varius nulla varius.",
        "Duis in tellus mauris.",
        "Praesent tristique sem vel nisi gravida hendrerit.",
        "Nullam sit amet vulputate risus,",
        "id tempus tortor.",
        "Vivamus lacus tortor,",
        "varius malesuada metus ut,",
        "sagittis dapibus neque.",
        "Duis fermentum est id justo tempus ornare.",
        "Praesent vulputate ut ligula sit amet gravida.",
        "Integer convallis ipsum vitae purus vulputate lobortis.",
        "Curabitur condimentum ligula eu pharetra suscipit.",
        "Vestibulum imperdiet sem ac eros gravida accumsan.",
        "Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.",
        "Orci varius natoque penatibus et magnis dis parturient montes,",
        "nascetur ridiculus mus.",
        "Nunc at odio dolor.",
        "Curabitur vel risus cursus,",
        "aliquet quam consequat,",
        "egestas metus.",
        "In ut lacus lacus.",
        "Fusce quis mollis velit.",
        "Nullam lobortis urna luctus convallis luctus.",
        "Etiam in tristique lorem.",
        "Donec vulputate odio felis.",
        "Sed tortor enim,",
        "facilisis eget consequat ac,",
        "vehicula a arcu.",
        "Curabitur vehicula magna eu posuere finibus.",
        "Nulla felis ipsum,",
        "dictum id nisi quis,",
        "suscipit laoreet metus.",
        "Nam malesuada nunc ut turpis ullamcorper,",
        "sit amet interdum elit dignissim.",
        "Etiam nec lectus sed dolor pretium accumsan ut at urna.",
        "Nullam diam enim,",
        "hendrerit in sagittis sit amet,",
        "dignissim sit amet erat.",
        "Nam a ex a lectus bibendum convallis id nec urna.",
        "Donec venenatis leo quam,",
        "quis iaculis neque convallis a.",
        "Praesent et venenatis enim,",
        "nec finibus sem.",
        "Sed id lorem non nulla dapibus aliquet vel sed risus.",
        "Aliquam pellentesque elit id dui ullamcorper pellentesque.",
        "In iaculis sollicitudin leo eu bibendum.",
        "Nam condimentum neque sed ultricies sollicitudin.",
        "Sed auctor consequat mollis.",
        "Maecenas hendrerit dignissim leo eget semper.",
        "Aenean et felis sed erat consectetur porttitor.",
        "Vivamus velit tellus,",
        "dictum et leo suscipit,",
        "venenatis sollicitudin neque.",
        "Sed gravida varius viverra.",
        "In rutrum tellus at faucibus volutpat.",
        "Duis bibendum purus eu scelerisque lacinia.",
        "Orci varius natoque penatibus et magnis dis parturient montes,",
        "nascetur ridiculus mus.",
        "Morbi a viverra elit.",
        "Donec egestas felis nunc,",
        "nec tempor magna consequat vulputate.",
        "Vestibulum vel quam magna.",
        "Quisque sed magna ante.",
        "Sed vel lacus vel tellus blandit malesuada nec faucibus sem.",
        "Praesent bibendum bibendum arcu eget ultricies.",
        "Cras elit risus,",
        "semper in varius ut,",
        "aliquam ornare massa.",
        "Pellentesque aliquet nisi in dignissim faucibus.",
        "Curabitur libero lectus,",
        "euismod a eros in,",
        "tincidunt venenatis lectus.",
        "Nunc volutpat pulvinar posuere.",
        "Etiam placerat urna dolor,",
        "accumsan sodales dui maximus vel.",
        "Aenean in velit commodo,",
        "dapibus dui efficitur,",
        "tristique erat.",
        "Quisque pharetra vehicula imperdiet.",
        "In massa orci,",
        "porttitor at maximus vel,",
        "ullamcorper eget purus.",
        "Curabitur pulvinar vestibulum euismod.",
        "Nulla posuere orci ut dapibus commodo.",
        "Etiam pharetra arcu eu ante consectetur,",
        "sed euismod nulla venenatis.",
        "Cras elementum nisl et turpis ultricies,",
        "nec tempor urna iaculis.",
        "Suspendisse a lectus non dolor venenatis bibendum.",
        "Cras mauris tellus,",
        "ultrices a convallis sit amet,",
        "faucibus ut dolor.",
        "Etiam congue tincidunt nunc,",
        "vel ornare ante convallis id.",
        "Fusce egestas lacus id arcu vulputate,",
        "sed fringilla sapien interdum.",
        "Cras ac ipsum vitae neque rhoncus consectetur.",
        "Nunc consequat erat id nulla vulputate,",
        "id malesuada lacus sodales.",
        "Donec aliquam lorem vitae ipsum ullamcorper,",
        "ut hendrerit eros dignissim.",
        "Duis vehicula,",
        "mi ac congue molestie,",
        "est nisl facilisis lectus,",
        "eget finibus ante neque ac tortor.",
        "Mauris eget ante in felis maximus molestie.",
        "Sed ullamcorper aliquam felis,",
        "id molestie eros commodo at.",
        "Etiam a molestie arcu.",
        "Donec mollis viverra neque eget blandit.",
        "Phasellus at felis et tellus aliquam semper ut ut nisl.",
        "Nulla volutpat ultricies lacus,",
        "quis accumsan quam commodo id.",
        "Curabitur sagittis dui nisi,",
        "vitae ullamcorper nulla sagittis id.",
        "Morbi pellentesque fringilla mattis.",
        "Quisque sollicitudin et purus a tempus.",
        "Nunc volutpat sapien sed vulputate dapibus.",
        "Vestibulum fermentum nisi vitae elit fringilla imperdiet.",
        "Phasellus convallis velit quis viverra pellentesque.",
        "Duis sit amet laoreet nunc.",
        "Vestibulum magna odio,",
        "aliquam feugiat urna quis,",
        "interdum condimentum sapien.",
        "Donec varius ipsum non mattis hendrerit.",
        "Fusce a laoreet ligula.",
        "Cras efficitur posuere ante quis ullamcorper.",
        "Donec ut varius quam,",
        "sit amet bibendum ipsum.",
        "Proin molestie,",
        "nulla blandit hendrerit laoreet,",
        "erat sapien mattis odio,",
        "eu egestas erat est id nulla.",
        "Integer pulvinar feugiat justo a mollis.",
        "Maecenas nisi nisl,",
        "lacinia eget convallis eu,",
        "hendrerit sit amet quam.",
        "Vestibulum mattis velit eu sapien maximus pellentesque.",
        "Vivamus venenatis,",
        "ex at condimentum mollis,",
        "odio turpis elementum dui,",
        "sed accumsan odio sem a nibh.",
        "Suspendisse sed tincidunt urna,",
        "quis aliquam risus.",
        "Maecenas vitae lacinia ante.",
        "Nulla quis est mi.",
        "Nunc non maximus nulla.",
        "Phasellus placerat elit ac pretium pharetra.",
        "Nunc nibh dolor,",
        "convallis non ultrices in,",
        "pharetra a massa.",
        "In hac habitasse platea dictumst.",
        "Integer mattis luctus metus,",
        "eget pretium elit semper a.",
        "In interdum congue nibh vel porttitor.",
        "Phasellus eu viverra turpis,",
        "ut molestie metus.",
        "Suspendisse quis eros mollis,",
        "cursus enim in,",
        "malesuada diam.",
        "Nullam in metus vulputate,",
        "finibus nisi ut,",
        "pellentesque tortor.",
        "Mauris rutrum,",
        "lectus ullamcorper elementum dignissim,",
        "orci neque condimentum dolor,",
        "quis tempus ante urna ac dui.",
        "Vestibulum dui elit,",
        "pulvinar at velit non,",
        "maximus semper tortor.",
        "Ut eu neque sit amet nulla aliquet commodo nec fermentum purus.",
        "Mauris ut urna a est sollicitudin condimentum id in enim.",
        "Aliquam porttitor libero id laoreet placerat.",
        "Etiam euismod libero eget risus placerat,",
        "quis egestas sapien lacinia.",
        "Donec eget augue dignissim,",
        "ultrices elit eget,",
        "dictum nibh.",
        "In ultricies risus vel nisi convallis fermentum.",
        "Etiam tempor nisi nulla,",
        "eu pulvinar nisl pretium ut.",
        "Cras ullamcorper enim nisl,",
        "at tempus arcu sagittis quis.",
    ]

    private func requiredByteCount<T: Codable>(for messages: [T], cacheWillRoll: Bool) -> UInt64 {
        let encoder = JSONEncoder()
        let messageSpanSuffixLength = cacheWillRoll ? 2 * Data.messageSpanLength : Data.messageSpanLength
        return UInt64(messageSpanSuffixLength)
            + messages.reduce(0) { allocatedSize, message in
                let encodableMessage = EncodableMessage(message: message, encoder: encoder)
                guard let data = try? encodableMessage.encodedData() else {
                    XCTFail("Could not encode data for message: \(message)")
                    return 0
                }
                return allocatedSize + UInt64(data.count)
        }
    }

}