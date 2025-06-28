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

#if !os(Linux)
	import SQLite3
	import Testing
	import XCTest

	@testable import CacheAdvance

	final class SQLitePerformanceComparisonTests: XCTestCase {
		// MARK: XCTestCase

		override func setUp() {
			super.setUp()

			// Delete the existing cache.
			try? FileManager.default.removeItem(at: testFileLocation)
		}

		// MARK: Performance Tests

		func test_performance_sqlite_createDatabaseAndAppendSingleMessage() {
			measure {
				// Delete any existing database.
				try? FileManager.default.removeItem(at: testFileLocation)

				let cache = SQLiteCache<TestableMessage>(
					location: testFileLocation,
					maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
					shouldOverwriteMessages: false
				)

				cache.appendMessage("test message")
			}
		}

		func test_performance_sqlite_append_fillableCache() {
			// Create a cache that won't run out of room over multiple test runs.
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count * 10),
				shouldOverwriteMessages: false
			)
			cache.createDatabaseIfNecessay()

			measure {
				for message in TestableMessage.lorumIpsum {
					cache.appendMessage(message)
				}
			}
		}

		func test_performance_sqlite_append_overwritingCache() {
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
				shouldOverwriteMessages: true
			)

			// Fill the cache before the test starts.
			for message in TestableMessage.lorumIpsum {
				cache.appendMessage(message)
			}
			measure {
				for message in TestableMessage.lorumIpsum {
					cache.appendMessage(message)
				}
			}
		}

		func test_performance_sqlite_messages_fillableCache() {
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
				shouldOverwriteMessages: false
			)
			for message in TestableMessage.lorumIpsum {
				cache.appendMessage(message)
			}
			measure {
				_ = cache.messages()
			}
		}

		func test_performance_sqlite_messages_overwritingCache() {
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
				shouldOverwriteMessages: true
			)
			for message in TestableMessage.lorumIpsum + TestableMessage.lorumIpsum {
				cache.appendMessage(message)
			}
			measure {
				_ = cache.messages()
			}
		}

		// MARK: Private

		private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("SQLiteTests")
	}

	// MARK: - SQLiteCacheTests

	@Suite(.serialized)
	struct SQLiteCacheTests {
		// MARK: Initialization

		init() {
			// Delete the existing cache.
			try? FileManager.default.removeItem(at: testFileLocation)
		}

		// MARK: Behavior Tests

		@Test
		func append_sqlite_fillableCache_canMaintainMaxCount() {
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
				shouldOverwriteMessages: false
			)
			for message in TestableMessage.lorumIpsum + TestableMessage.lorumIpsum {
				cache.appendMessage(message)
			}

			#expect(cache.messages().count == TestableMessage.lorumIpsum.count)
		}

		@Test
		func messages_sqlite_fillableCache_canReadInsertedMessages() {
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
				shouldOverwriteMessages: true
			)
			for message in TestableMessage.lorumIpsum {
				cache.appendMessage(message)
			}

			#expect(cache.messages() == TestableMessage.lorumIpsum)
		}

		@Test
		func append_sqlite_overwritingCache_canMaintainMaxCount() {
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
				shouldOverwriteMessages: true
			)
			for message in TestableMessage.lorumIpsum + TestableMessage.lorumIpsum {
				cache.appendMessage(message)
			}

			#expect(cache.messages().count == TestableMessage.lorumIpsum.count)
		}

		@Test
		func append_sqlite_overwritingCache_storesOnlyMostRecentMessages() {
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
				shouldOverwriteMessages: true
			)
			for message in TestableMessage.lorumIpsum {
				cache.appendMessage(message)
			}
			cache.appendMessage(#function)

			#expect(cache.messages() == Array(TestableMessage.lorumIpsum.dropFirst()) + [#function])
		}

		@Test
		func messages_sqlite_overwritingCache_canReadInsertedMessages() {
			let cache = SQLiteCache<TestableMessage>(
				location: testFileLocation,
				maxMessageCount: Int32(TestableMessage.lorumIpsum.count),
				shouldOverwriteMessages: true
			)
			for message in TestableMessage.lorumIpsum {
				cache.appendMessage(message)
			}

			#expect(cache.messages() == TestableMessage.lorumIpsum)
		}

		// MARK: Private

		private let testFileLocation = FileManager.default.temporaryDirectory.appendingPathComponent("SQLiteTests")
	}

	// MARK: - SQLiteCache

	private class SQLiteCache<T: Codable> {
		// MARK: Initialization

		init(
			location: URL,
			maxMessageCount: Int32,
			shouldOverwriteMessages: Bool
		) {
			self.location = location
			self.maxMessageCount = maxMessageCount
			self.shouldOverwriteMessages = shouldOverwriteMessages
		}

		deinit {
			if let db {
				sqlite3_close(db)
			}
		}

		// MARK: Internal

		func createDatabaseIfNecessay() {
			guard db == nil else {
				return
			}
			XCTAssertEqual(sqlite3_open(NSString(string: location.path).utf8String, &db), SQLITE_OK)
			var createTableStatement: OpaquePointer?
			XCTAssertEqual(sqlite3_prepare_v2(db, "CREATE TABLE Messages(Message BLOB);", -1, &createTableStatement, nil), SQLITE_OK)
			XCTAssertEqual(sqlite3_step(createTableStatement), SQLITE_DONE)
			sqlite3_finalize(createTableStatement)
		}

		func appendMessage(_ message: T) {
			createDatabaseIfNecessay()
			guard let messageData = try? encoder.encode(message),
			      let messageDataPointer = messageData.withUnsafeBytes({ $0.baseAddress })
			else {
				XCTFail("Could not encode message")
				return
			}

			if messageCount() == maxMessageCount {
				guard shouldOverwriteMessages else {
					// We do not have room for this message.
					return
				}
				// Delete the first message to make room for this message.
				let rawDeleteQuery = "DELETE FROM Messages ORDER BY rowid LIMIT 1;"
				var deleteQuery: OpaquePointer?
				XCTAssertEqual(sqlite3_prepare_v2(db, rawDeleteQuery, -1, &deleteQuery, nil), SQLITE_OK)
				defer {
					sqlite3_finalize(deleteQuery)
				}

				XCTAssertEqual(sqlite3_step(deleteQuery), SQLITE_DONE)
			}

			let insertStatementString = "INSERT INTO Messages(Message) VALUES (?);"
			var insertStatement: OpaquePointer?

			XCTAssertEqual(sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil), SQLITE_OK)
			sqlite3_bind_blob(insertStatement, 1, messageDataPointer, Int32(messageData.count), nil)
			XCTAssertEqual(sqlite3_step(insertStatement), SQLITE_DONE)
			sqlite3_finalize(insertStatement)
		}

		func messages() -> [T] {
			createDatabaseIfNecessay()
			let rawQuery = "SELECT * FROM Messages;"
			var query: OpaquePointer?
			XCTAssertEqual(sqlite3_prepare_v2(db, rawQuery, -1, &query, nil), SQLITE_OK)
			defer {
				sqlite3_finalize(query)
			}
			var logs = [T]()
			while sqlite3_step(query) == SQLITE_ROW {
				guard let messageDataPointer = sqlite3_column_blob(query, 0) else {
					XCTFail("Failed to retrieve message blob")
					return []
				}
				let messageLength = sqlite3_column_bytes(query, 0)
				let messageData = Data(bytes: messageDataPointer, count: Int(messageLength))
				guard let message = try? decoder.decode(T.self, from: messageData) else {
					XCTFail("Failed to decode message")
					return []
				}
				logs.append(message)
			}

			return logs
		}

		// MARK: Private

		private var db: OpaquePointer?
		private let location: URL
		private let maxMessageCount: Int32
		private let shouldOverwriteMessages: Bool
		private let encoder = JSONEncoder()
		private let decoder = JSONDecoder()

		private func messageCount() -> Int32 {
			let rawCountQuery = "SELECT COUNT(*) FROM Messages;"
			var countQuery: OpaquePointer?
			XCTAssertEqual(sqlite3_prepare_v2(db, rawCountQuery, -1, &countQuery, nil), SQLITE_OK)
			defer {
				sqlite3_finalize(countQuery)
			}

			XCTAssertEqual(sqlite3_step(countQuery), SQLITE_ROW)

			return sqlite3_column_int(countQuery, 0)
		}
	}
#endif
