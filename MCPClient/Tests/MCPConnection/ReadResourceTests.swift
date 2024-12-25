
import JSONRPC
import SwiftTestingUtils
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class ReadResourceTests: MCPClientConnectionTest {

    @Test("read one resource")
    func test_readOneResource() async throws {
      let resources = try await assert(
        executing: {
          try await self.sut.readResource(.init(uri: "file:///project/src/main.rs"))
        },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "resources/read",
            "params": {
              "uri": "file:///project/src/main.rs"
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "contents": [
                {
                  "uri": "file:///project/src/main.rs",
                  "mimeType": "text/x-rust",
                  "text": "fn main() {\\n    println!(\\"Hello world!\\");\\n}"
                }
              ]
            }
          }
          """)
      #expect(resources.contents.map { $0.text?.text } == ["fn main() {\n    println!(\"Hello world!\");\n}"])
    }

    @Test("read resources of different types")
    func test_readResourcesOfDifferentTypes() async throws {
      let resources = try await assert(
        executing: {
          try await self.sut.readResource(.init(uri: "file:///project/src/*"))
        },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "resources/read",
            "params": {
              "uri": "file:///project/src/*"
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "contents": [
                {
                  "uri": "file:///project/src/main.rs",
                  "mimeType": "text/x-rust",
                  "text": "fn main() {\\n    println!(\\"Hello world!\\");\\n}"
                },
                {
                  "uri": "file:///project/src/main.rs",
                  "mimeType": "image/jpeg",
                  "blob": "base64-encoded-image-data"
                }
              ]
            }
          }
          """)
      #expect(resources.contents.map { $0.text?.text } == ["fn main() {\n    println!(\"Hello world!\");\n}", nil])
      #expect(resources.contents.map { $0.blob?.mimeType } == [nil, "image/jpeg"])
    }

    @Test("error when reading resource")
    func test_errorWhenReadingResource() async throws {
      await assert(
        executing: { try await self.sut.readResource(.init(uri: "file:///nonexistent.txt")) },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "resources/read",
            "params": {
              "uri": "file:///nonexistent.txt"
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "error": {
              "code": -32002,
              "message": "Resource not found",
              "data": {
                "uri": "file:///nonexistent.txt"
              }
            }
          }
          """,
        andFailsWith: { error in
          guard let error = error as? JSONRPCResponseError<JSONValue> else {
            Issue.record("Unexpected error type: \(error)")
            return
          }

          #expect(error.code == -32002)
          #expect(error.message == "Resource not found")
          #expect(error.data == .hash([
            "uri": .string("file:///nonexistent.txt"),
          ]))
        })
    }

    @Test("subscribing to resource updates")
    func test_subscribingToResourceUpdates() async throws {
      try await assert(
        executing: { try await self.sut.subscribeToUpdateToResource(.init(uri: "file:///project/src/main.rs")) },
        triggers: [
          .request("""
            {
              "id" : 1,
              "jsonrpc" : "2.0",
              "method" : "resources/subscribe",
              "params" : {
                "uri" : "file:///project/src/main.rs"
              }
            }
            """),
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {}
            }
            """),
        ])
    }

    @Test("unsubscribing to resource updates")
    func test_unsubscribingToResourceUpdates() async throws {
      try await assert(
        executing: { try await self.sut.unsubscribeToUpdateToResource(.init(uri: "file:///project/src/main.rs")) },
        triggers: [
          .request("""
            {
              "id" : 1,
              "jsonrpc" : "2.0",
              "method" : "resources/unsubscribe",
              "params" : {
                "uri" : "file:///project/src/main.rs"
              }
            }
            """),
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {}
            }
            """),
        ])
    }

    @Test("receiving resource update notification")
    func test_receivingResourceUpdateNotification() async throws {
      let notificationReceived = expectation(description: "Notification received")
      Task {
        for await notification in await self.sut.notifications {
          switch notification {
          case .resourceUpdated(let updateNotification):
            #expect(updateNotification.uri == "file:///project/src/main.rs")
            notificationReceived.fulfill()

          default:
            Issue.record("Unexpected notification: \(notification)")
          }
        }
      }
      transport.receive(message: """
        {
          "jsonrpc": "2.0",
          "method": "notifications/resources/updated",
          "params": {
            "uri": "file:///project/src/main.rs"
          }
        }
        """)
      try await fulfillment(of: [notificationReceived])
    }

  }
}
