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

    func test_messages_canReadEmptyCacheThatDoesNotOverwriteOldestMessages() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: 50,
            shouldOverwriteOldMessages: false)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [])
    }

    func test_messages_canReadEmptyCacheThatOverwritesOldestMessages() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: 50,
            shouldOverwriteOldMessages: true)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [])
    }

    func test_append_singleMessageThatFits_canBeRetrieved() throws {
        let message = TestableMessage("This is a test")
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: [message], cacheWillOverwriteOldestMessages: false),
            shouldOverwriteOldMessages: false)
        try cache.append(message: message)

        let messages = try cache.messages()
        XCTAssertEqual(messages, [message])
    }

    func test_append_singleMessageThatDoesNotFit_throwsError() throws {
        let message = TestableMessage("This is a test")
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: [message], cacheWillOverwriteOldestMessages: false) - 1,
            shouldOverwriteOldMessages: false)

        XCTAssertThrowsError(try cache.append(message: message)) {
            XCTAssertEqual($0 as? CacheAdvanceWriteError, CacheAdvanceWriteError.messageDataTooLarge)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, [], "Expected failed first write to result in an empty cache")
    }

    func test_append_singleMessageThrowsIfDoesNotFitAndCacheRolls() throws {
        let message = TestableMessage("This is a test")
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: [message], cacheWillOverwriteOldestMessages: true) - 1,
            shouldOverwriteOldMessages: true)

        XCTAssertThrowsError(try cache.append(message: message)) {
            XCTAssertEqual($0 as? CacheAdvanceWriteError, CacheAdvanceWriteError.messageDataTooLarge)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, [], "Expected failed first write to result in an empty cache")
    }

    func test_append_multipleMessagesCanBeRetrieved() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: lorumIpsumMessages, cacheWillOverwriteOldestMessages: false),
            shouldOverwriteOldMessages: false)
        for message in lorumIpsumMessages {
            try cache.append(message: message)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, lorumIpsumMessages)
    }

    func test_append_multipleMessagesCanBeRetrievedTwiceFromNonOverwritingCache() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: lorumIpsumMessages, cacheWillOverwriteOldestMessages: false),
            shouldOverwriteOldMessages: false)
        for message in lorumIpsumMessages {
            try cache.append(message: message)
        }

        XCTAssertEqual(try cache.messages(), try cache.messages())
    }

    func test_append_multipleMessagesCanBeRetrievedTwiceFromOverwritingCache() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: lorumIpsumMessages, cacheWillOverwriteOldestMessages: true) / 3,
            shouldOverwriteOldMessages: true)
        for message in lorumIpsumMessages {
            try cache.append(message: message)
        }

        XCTAssertEqual(try cache.messages(), try cache.messages())
    }

    func test_append_dropsLastMessageIfCacheDoesNotRollAndLastMessageDoesNotFit() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: lorumIpsumMessages, cacheWillOverwriteOldestMessages: false),
            shouldOverwriteOldMessages: false)
        for message in lorumIpsumMessages {
            try cache.append(message: message)
        }

        XCTAssertThrowsError(try cache.append(message: TestableMessage("This message won't fit"))) {
            XCTAssertEqual($0 as? CacheAdvanceWriteError, CacheAdvanceWriteError.messageDataTooLarge)
        }

        let messages = try cache.messages()
        XCTAssertEqual(messages, lorumIpsumMessages)
    }

    func test_append_dropsOldestMessageIfCacheRollsAndLastMessageDoesNotFitAndIsShorterThanOldestMessage() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: lorumIpsumMessages, cacheWillOverwriteOldestMessages: true),
            shouldOverwriteOldMessages: true)
        for message in lorumIpsumMessages {
            try cache.append(message: message)
        }

        // Append a message that is shorter than the first message in lorumIpsumMessages.
        let shortMessage = TestableMessage("Short message")
        try cache.append(message: shortMessage)

        let messages = try cache.messages()
        XCTAssertEqual(messages, Array(lorumIpsumMessages.dropFirst()) + [shortMessage])
    }

    func test_append_dropsFirstTwoMessagesIfCacheRollsAndLastMessageDoesNotFitAndIsLargerThanOldestMessage() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: lorumIpsumMessages, cacheWillOverwriteOldestMessages: true),
            shouldOverwriteOldMessages: true)
        for message in lorumIpsumMessages {
            try cache.append(message: message)
        }

        // Append a message that is slightly longer than the first message in lorumIpsumMessages.
        let barelyLongerMessage = TestableMessage(lorumIpsumMessages[0].description + "hi")
        try cache.append(message: barelyLongerMessage)

        let messages = try cache.messages()
        XCTAssertEqual(messages, Array(lorumIpsumMessages.dropFirst(2)) + [barelyLongerMessage])
    }

    func test_append_dropsOldMessagesAsNecessary() throws {
        let cache = try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: lorumIpsumMessages, cacheWillOverwriteOldestMessages: true) / 3,
            shouldOverwriteOldMessages: true)
        for message in lorumIpsumMessages {
            try cache.append(message: message)
        }

        let messages = try cache.messages()
        XCTAssertEqual(Array(lorumIpsumMessages.dropFirst(lorumIpsumMessages.count - messages.count)), messages)
    }

    func test_messages_canReadMessagesWrittenByADifferentCache() throws {
        func createCache() throws -> CacheAdvance<TestableMessage> {
            return try CacheAdvance<TestableMessage>(
            file: testFileLocation,
            maximumBytes: try requiredByteCount(for: lorumIpsumMessages, cacheWillOverwriteOldestMessages: true) / 3,
            shouldOverwriteOldMessages: true)
        }
        let cache = try createCache()
        for message in lorumIpsumMessages {
            try cache.append(message: message)
        }

        let secondCache = try createCache()
        XCTAssertEqual(try cache.messages(), try secondCache.messages())
    }

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("CacheAdvanceTests")
    private let lorumIpsumMessages = [
        TestableMessage("Lorem ipsum dolor sit amet,"),
        TestableMessage("consectetur adipiscing elit."),
        TestableMessage("Etiam sagittis neque massa,"),
        TestableMessage("id auctor urna elementum at."),
        TestableMessage("Phasellus sit amet mauris posuere,"),
        TestableMessage("aliquet eros nec,"),
        TestableMessage("posuere odio."),
        TestableMessage("Ut in neque egestas,"),
        TestableMessage("vehicula massa non,"),
        TestableMessage("consequat augue."),
        TestableMessage("Pellentesque mattis blandit velit,"),
        TestableMessage("ut accumsan velit mollis sed."),
        TestableMessage("Praesent ac vehicula metus."),
        TestableMessage("Praesent eu purus justo."),
        TestableMessage("Maecenas arcu risus,"),
        TestableMessage("egestas vitae commodo eu,"),
        TestableMessage("gravida non ipsum."),
        TestableMessage("Mauris nec ipsum et lacus rhoncus dictum."),
        TestableMessage("Fusce sagittis magna quis iaculis venenatis."),
        TestableMessage("Nullam placerat odio id nulla porttitor,"),
        TestableMessage("ultrices varius nulla varius."),
        TestableMessage("Duis in tellus mauris."),
        TestableMessage("Praesent tristique sem vel nisi gravida hendrerit."),
        TestableMessage("Nullam sit amet vulputate risus,"),
        TestableMessage("id tempus tortor."),
        TestableMessage("Vivamus lacus tortor,"),
        TestableMessage("varius malesuada metus ut,"),
        TestableMessage("sagittis dapibus neque."),
        TestableMessage("Duis fermentum est id justo tempus ornare."),
        TestableMessage("Praesent vulputate ut ligula sit amet gravida."),
        TestableMessage("Integer convallis ipsum vitae purus vulputate lobortis."),
        TestableMessage("Curabitur condimentum ligula eu pharetra suscipit."),
        TestableMessage("Vestibulum imperdiet sem ac eros gravida accumsan."),
        TestableMessage("Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas."),
        TestableMessage("Orci varius natoque penatibus et magnis dis parturient montes,"),
        TestableMessage("nascetur ridiculus mus."),
        TestableMessage("Nunc at odio dolor."),
        TestableMessage("Curabitur vel risus cursus,"),
        TestableMessage("aliquet quam consequat,"),
        TestableMessage("egestas metus."),
        TestableMessage("In ut lacus lacus."),
        TestableMessage("Fusce quis mollis velit."),
        TestableMessage("Nullam lobortis urna luctus convallis luctus."),
        TestableMessage("Etiam in tristique lorem."),
        TestableMessage("Donec vulputate odio felis."),
        TestableMessage("Sed tortor enim,"),
        TestableMessage("facilisis eget consequat ac,"),
        TestableMessage("vehicula a arcu."),
        TestableMessage("Curabitur vehicula magna eu posuere finibus."),
        TestableMessage("Nulla felis ipsum,"),
        TestableMessage("dictum id nisi quis,"),
        TestableMessage("suscipit laoreet metus."),
        TestableMessage("Nam malesuada nunc ut turpis ullamcorper,"),
        TestableMessage("sit amet interdum elit dignissim."),
        TestableMessage("Etiam nec lectus sed dolor pretium accumsan ut at urna."),
        TestableMessage("Nullam diam enim,"),
        TestableMessage("hendrerit in sagittis sit amet,"),
        TestableMessage("dignissim sit amet erat."),
        TestableMessage("Nam a ex a lectus bibendum convallis id nec urna."),
        TestableMessage("Donec venenatis leo quam,"),
        TestableMessage("quis iaculis neque convallis a."),
        TestableMessage("Praesent et venenatis enim,"),
        TestableMessage("nec finibus sem."),
        TestableMessage("Sed id lorem non nulla dapibus aliquet vel sed risus."),
        TestableMessage("Aliquam pellentesque elit id dui ullamcorper pellentesque."),
        TestableMessage("In iaculis sollicitudin leo eu bibendum."),
        TestableMessage("Nam condimentum neque sed ultricies sollicitudin."),
        TestableMessage("Sed auctor consequat mollis."),
        TestableMessage("Maecenas hendrerit dignissim leo eget semper."),
        TestableMessage("Aenean et felis sed erat consectetur porttitor."),
        TestableMessage("Vivamus velit tellus,"),
        TestableMessage("dictum et leo suscipit,"),
        TestableMessage("venenatis sollicitudin neque."),
        TestableMessage("Sed gravida varius viverra."),
        TestableMessage("In rutrum tellus at faucibus volutpat."),
        TestableMessage("Duis bibendum purus eu scelerisque lacinia."),
        TestableMessage("Orci varius natoque penatibus et magnis dis parturient montes,"),
        TestableMessage("nascetur ridiculus mus."),
        TestableMessage("Morbi a viverra elit."),
        TestableMessage("Donec egestas felis nunc,"),
        TestableMessage("nec tempor magna consequat vulputate."),
        TestableMessage("Vestibulum vel quam magna."),
        TestableMessage("Quisque sed magna ante."),
        TestableMessage("Sed vel lacus vel tellus blandit malesuada nec faucibus sem."),
        TestableMessage("Praesent bibendum bibendum arcu eget ultricies."),
        TestableMessage("Cras elit risus,"),
        TestableMessage("semper in varius ut,"),
        TestableMessage("aliquam ornare massa."),
        TestableMessage("Pellentesque aliquet nisi in dignissim faucibus."),
        TestableMessage("Curabitur libero lectus,"),
        TestableMessage("euismod a eros in,"),
        TestableMessage("tincidunt venenatis lectus."),
        TestableMessage("Nunc volutpat pulvinar posuere."),
        TestableMessage("Etiam placerat urna dolor,"),
        TestableMessage("accumsan sodales dui maximus vel."),
        TestableMessage("Aenean in velit commodo,"),
        TestableMessage("dapibus dui efficitur,"),
        TestableMessage("tristique erat."),
        TestableMessage("Quisque pharetra vehicula imperdiet."),
        TestableMessage("In massa orci,"),
        TestableMessage("porttitor at maximus vel,"),
        TestableMessage("ullamcorper eget purus."),
        TestableMessage("Curabitur pulvinar vestibulum euismod."),
        TestableMessage("Nulla posuere orci ut dapibus commodo."),
        TestableMessage("Etiam pharetra arcu eu ante consectetur,"),
        TestableMessage("sed euismod nulla venenatis."),
        TestableMessage("Cras elementum nisl et turpis ultricies,"),
        TestableMessage("nec tempor urna iaculis."),
        TestableMessage("Suspendisse a lectus non dolor venenatis bibendum."),
        TestableMessage("Cras mauris tellus,"),
        TestableMessage("ultrices a convallis sit amet,"),
        TestableMessage("faucibus ut dolor."),
        TestableMessage("Etiam congue tincidunt nunc,"),
        TestableMessage("vel ornare ante convallis id."),
        TestableMessage("Fusce egestas lacus id arcu vulputate,"),
        TestableMessage("sed fringilla sapien interdum."),
        TestableMessage("Cras ac ipsum vitae neque rhoncus consectetur."),
        TestableMessage("Nunc consequat erat id nulla vulputate,"),
        TestableMessage("id malesuada lacus sodales."),
        TestableMessage("Donec aliquam lorem vitae ipsum ullamcorper,"),
        TestableMessage("ut hendrerit eros dignissim."),
        TestableMessage("Duis vehicula,"),
        TestableMessage("mi ac congue molestie,"),
        TestableMessage("est nisl facilisis lectus,"),
        TestableMessage("eget finibus ante neque ac tortor."),
        TestableMessage("Mauris eget ante in felis maximus molestie."),
        TestableMessage("Sed ullamcorper aliquam felis,"),
        TestableMessage("id molestie eros commodo at."),
        TestableMessage("Etiam a molestie arcu."),
        TestableMessage("Donec mollis viverra neque eget blandit."),
        TestableMessage("Phasellus at felis et tellus aliquam semper ut ut nisl."),
        TestableMessage("Nulla volutpat ultricies lacus,"),
        TestableMessage("quis accumsan quam commodo id."),
        TestableMessage("Curabitur sagittis dui nisi,"),
        TestableMessage("vitae ullamcorper nulla sagittis id."),
        TestableMessage("Morbi pellentesque fringilla mattis."),
        TestableMessage("Quisque sollicitudin et purus a tempus."),
        TestableMessage("Nunc volutpat sapien sed vulputate dapibus."),
        TestableMessage("Vestibulum fermentum nisi vitae elit fringilla imperdiet."),
        TestableMessage("Phasellus convallis velit quis viverra pellentesque."),
        TestableMessage("Duis sit amet laoreet nunc."),
        TestableMessage("Vestibulum magna odio,"),
        TestableMessage("aliquam feugiat urna quis,"),
        TestableMessage("interdum condimentum sapien."),
        TestableMessage("Donec varius ipsum non mattis hendrerit."),
        TestableMessage("Fusce a laoreet ligula."),
        TestableMessage("Cras efficitur posuere ante quis ullamcorper."),
        TestableMessage("Donec ut varius quam,"),
        TestableMessage("sit amet bibendum ipsum."),
        TestableMessage("Proin molestie,"),
        TestableMessage("nulla blandit hendrerit laoreet,"),
        TestableMessage("erat sapien mattis odio,"),
        TestableMessage("eu egestas erat est id nulla."),
        TestableMessage("Integer pulvinar feugiat justo a mollis."),
        TestableMessage("Maecenas nisi nisl,"),
        TestableMessage("lacinia eget convallis eu,"),
        TestableMessage("hendrerit sit amet quam."),
        TestableMessage("Vestibulum mattis velit eu sapien maximus pellentesque."),
        TestableMessage("Vivamus venenatis,"),
        TestableMessage("ex at condimentum mollis,"),
        TestableMessage("odio turpis elementum dui,"),
        TestableMessage("sed accumsan odio sem a nibh."),
        TestableMessage("Suspendisse sed tincidunt urna,"),
        TestableMessage("quis aliquam risus."),
        TestableMessage("Maecenas vitae lacinia ante."),
        TestableMessage("Nulla quis est mi."),
        TestableMessage("Nunc non maximus nulla."),
        TestableMessage("Phasellus placerat elit ac pretium pharetra."),
        TestableMessage("Nunc nibh dolor,"),
        TestableMessage("convallis non ultrices in,"),
        TestableMessage("pharetra a massa."),
        TestableMessage("In hac habitasse platea dictumst."),
        TestableMessage("Integer mattis luctus metus,"),
        TestableMessage("eget pretium elit semper a."),
        TestableMessage("In interdum congue nibh vel porttitor."),
        TestableMessage("Phasellus eu viverra turpis,"),
        TestableMessage("ut molestie metus."),
        TestableMessage("Suspendisse quis eros mollis,"),
        TestableMessage("cursus enim in,"),
        TestableMessage("malesuada diam."),
        TestableMessage("Nullam in metus vulputate,"),
        TestableMessage("finibus nisi ut,"),
        TestableMessage("pellentesque tortor."),
        TestableMessage("Mauris rutrum,"),
        TestableMessage("lectus ullamcorper elementum dignissim,"),
        TestableMessage("orci neque condimentum dolor,"),
        TestableMessage("quis tempus ante urna ac dui."),
        TestableMessage("Vestibulum dui elit,"),
        TestableMessage("pulvinar at velit non,"),
        TestableMessage("maximus semper tortor."),
        TestableMessage("Ut eu neque sit amet nulla aliquet commodo nec fermentum purus."),
        TestableMessage("Mauris ut urna a est sollicitudin condimentum id in enim."),
        TestableMessage("Aliquam porttitor libero id laoreet placerat."),
        TestableMessage("Etiam euismod libero eget risus placerat,"),
        TestableMessage("quis egestas sapien lacinia."),
        TestableMessage("Donec eget augue dignissim,"),
        TestableMessage("ultrices elit eget,"),
        TestableMessage("dictum nibh."),
        TestableMessage("In ultricies risus vel nisi convallis fermentum."),
        TestableMessage("Etiam tempor nisi nulla,"),
        TestableMessage("eu pulvinar nisl pretium ut."),
        TestableMessage("Cras ullamcorper enim nisl,"),
        TestableMessage("at tempus arcu sagittis quis."),
    ]

    private func requiredByteCount<T: Codable>(for messages: [T], cacheWillOverwriteOldestMessages: Bool) throws -> UInt64 {
        let encoder = JSONEncoder()
        let messageSpanSuffixLength = cacheWillOverwriteOldestMessages ? Bytes(MessageSpan.storageLength + Bytes.storageLength) : Bytes(MessageSpan.storageLength)
        return try messageSpanSuffixLength + messages.reduce(0) { allocatedSize, message in
            let encodableMessage = EncodableMessage(message: message, encoder: encoder)
            let data = try encodableMessage.encodedData()
            return allocatedSize + UInt64(data.count)
        }
    }

}
