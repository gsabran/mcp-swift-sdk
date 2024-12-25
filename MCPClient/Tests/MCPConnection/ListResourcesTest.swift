
import JSONRPC
import SwiftTestingUtils
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class ListResourcesTests: MCPClientConnectionTest {

    @Test("list resources")
    func test_listResources() async throws {
      let resources = try await assert(
        executing: {
          try await self.sut.listResources()
        },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "resources/list",
            "params": {}
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "resources": [
                {
                  "uri": "file:///project/src/main.rs",
                  "name": "main.rs",
                  "description": "Primary application entry point",
                  "mimeType": "text/x-rust"
                }
              ]
            }
          }
          """)
      #expect(resources.map { $0.name } == ["main.rs"])
    }

    @Test("list resources with pagination")
    func test_listResources_withPagination() async throws {
      let resources = try await assert(
        executing: { try await self.sut.listResources() },
        triggers: [
          .request("""
            {
              "id" : 1,
              "jsonrpc" : "2.0",
              "method" : "resources/list",
              "params" : {}
            }
            """),
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "resources": [
                  {
                    "uri": "file:///project/src/main.rs",
                    "name": "main.rs",
                    "description": "Primary application entry point",
                    "mimeType": "text/x-rust"
                  }
                ],
                "nextCursor": "next-page-cursor"
              }
            }
            """),
          .request("""
            {
              "id" : 2,
              "jsonrpc" : "2.0",
              "method" : "resources/list",
              "params" : {
                "cursor": "next-page-cursor"
              }
            }
            """),
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 2,
              "result": {
                "resources": [
                  {
                    "uri": "file:///project/src/utils.rs",
                    "name": "utils.rs",
                    "description": "Some utils functions application entry point",
                    "mimeType": "text/x-rust"
                  }
                ]
              }
            }
            """),
        ])
      #expect(resources.map { $0.name } == ["main.rs", "utils.rs"])
    }

    @Test("receiving resources list changed notification")
    func test_receivingResourcesListChangedNotification() async throws {
      let notificationReceived = expectation(description: "Notification received")
      Task {
        for await notification in await sut.notifications {
          switch notification {
          case .resourceListChanged:
            notificationReceived.fulfill()
          default:
            Issue.record("Unexpected notification: \(notification)")
          }
        }
      }

      transport.receive(message: """
        {
          "jsonrpc": "2.0",
          "method": "notifications/resources/list_changed"
        }
        """)
      try await fulfillment(of: [notificationReceived])
    }
  }
}
