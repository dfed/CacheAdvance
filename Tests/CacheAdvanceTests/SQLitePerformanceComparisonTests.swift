//
//  Created by Dan Federman on 4/23/20.
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

import SQLite3
import XCTest

@testable import CacheAdvance

final class SQLitePerformanceComparisonTests: XCTestCase {

    // MARK: XCTestCase

    override func tearDown() {
        sqlite3_close(db)

        super.tearDown()
    }

    // MARK: Performance Tests

    func test_performance_createDatabaseAndAppendSingleMessage() {
        measure {
            createDatabase()
            insertMessage("test message")
        }
    }

    func test_performance_sqlite_append() {
        createDatabase()
        measure {
            for message in LorumIpsum.messages {
                insertMessage(message)
            }
        }
    }

    func test_performance_sqlite_messages() {
        createDatabase()
        for message in LorumIpsum.messages {
            insertMessage(message)
        }
        measure {
            let _ = readMessages()
        }
    }

    // MARK: Behavior Tests

    func test_readMessages_sqlite_canReadInsertedMessages() {
        createDatabase()
        for message in LorumIpsum.messages {
            insertMessage(message)
        }

        XCTAssertEqual(readMessages(), LorumIpsum.messages)
    }

    // MARK: Private

    func createDatabase() {
        if let db = db {
            sqlite3_close(db)
        }
        try? FileManager.default.removeItem(at: testFileLocation)
        guard sqlite3_open(NSString(string: testFileLocation.path).utf8String, &db) == SQLITE_OK else {
            XCTFail("Failed to open database")
            return
        }
        var createTableStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "CREATE TABLE Messages(Message BLOB);", -1, &createTableStatement, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare database")
            return
        }
        guard sqlite3_step(createTableStatement) == SQLITE_DONE else {
            XCTFail("Failed to create database")
            return
        }
        sqlite3_finalize(createTableStatement)
    }

    func insertMessage(_ message: TestableMessage) {
        guard let messageData = try? encoder.encode(message),
            let messageDataPointer = messageData.withUnsafeBytes({ $0.baseAddress }) else {
            XCTFail("Could not encode message")
            return
        }

        let insertStatementString = "INSERT INTO Messages(Message) VALUES (?);"
        var insertStatement: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare message")
            return
        }
        sqlite3_bind_blob(insertStatement, 1, messageDataPointer, Int32(messageData.count), nil)
        guard sqlite3_step(insertStatement) == SQLITE_DONE else {
            XCTFail("Failed to insert message")
            return
        }
        sqlite3_finalize(insertStatement)
    }

    func readMessages() -> [TestableMessage] {
        let rawQuery = "SELECT * FROM Messages;"
        var query: OpaquePointer?
        guard sqlite3_prepare_v2(db, rawQuery, -1, &query, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare read")
            return []
        }
        defer {
            sqlite3_finalize(query)
        }
        var logs = [TestableMessage]()
        while sqlite3_step(query) == SQLITE_ROW {
            guard let messageDataPointer = sqlite3_column_blob(query, 0) else {
                XCTFail("Failed to retrieve message blob")
                return []
            }
            let messageLength = sqlite3_column_bytes(query, 0)
            let messageData = Data(bytes: messageDataPointer, count: Int(messageLength))
            guard let message = try? decoder.decode(TestableMessage.self, from: messageData) else {
                XCTFail("Failed to decode message")
                return []
            }
            logs.append(message)
        }

        return logs
    }

    private var db: OpaquePointer?

    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("SQLiteTests")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

}
