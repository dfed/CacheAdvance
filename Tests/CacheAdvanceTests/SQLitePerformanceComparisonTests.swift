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

final class SQLitePerformanceComparisonTests: XCTestCase {

    // MARK: XCTestCase

    override func tearDown() {
        sqlite3_close(db)

        super.tearDown()
    }

    // MARK: Behavior Tests

    func test_performance_append_sqlite() throws {
        measure {
            createDatabase()
            for message in LorumIpsum.messages {
                insertMessage(message.value)
            }
        }
    }

    func test_performance_messages_sqlite() throws {
        createDatabase()
        for message in LorumIpsum.messages {
            insertMessage(message.value)
        }
        measure {
            let _ = readMessages()
        }
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
        guard sqlite3_prepare_v2(db, "CREATE TABLE Messages(Message TEXT);", -1, &createTableStatement, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare database")
            return
        }
        guard sqlite3_step(createTableStatement) == SQLITE_DONE else {
            XCTFail("Failed to create database")
            return
        }
        sqlite3_finalize(createTableStatement)
    }

    func insertMessage(_ message: String) {
        let insertStatementString = "INSERT INTO Messages(Message) VALUES ('\(message)');"
        var insertStatement: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare message")
            return
        }
        sqlite3_bind_text(insertStatement, 2, NSString(string: message).utf8String, -1, nil)
        guard sqlite3_step(insertStatement) == SQLITE_DONE else {
            XCTFail("Failed to insert message")
            return
        }
        sqlite3_finalize(insertStatement)
    }

    func readMessages() -> [String] {
        let rawQuery = "SELECT * FROM Messages;"
        var query: OpaquePointer?
        guard sqlite3_prepare_v2(db, rawQuery, -1, &query, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare read")
            return []
        }
        defer {
            sqlite3_finalize(query)
        }
        var logs = [String]()
        while sqlite3_step(query) == SQLITE_ROW {
            let log = String(cString: sqlite3_column_text(query, 0))
            logs.append(log)
        }

        return logs
    }

    private var db: OpaquePointer?
    private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("SQLiteTests")
}
