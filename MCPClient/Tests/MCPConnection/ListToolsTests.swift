
import JSONRPC
import SwiftTestingUtils
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class ListToolsTests: MCPClientConnectionTest {

    @Test("list tools")
    func test_listTools() async throws {
      let tools = try await assert(
        executing: {
          try await self.sut.listTools()
        },
        sends: """
          {
            "id" : 1,
            "jsonrpc" : "2.0",
            "method" : "tools/list",
            "params" : {}
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "tools": [
                {
                  "name": "get_weather",
                  "description": "Get current weather information for a location",
                  "inputSchema": {
                    "type": "object",
                    "properties": {
                      "location": {
                        "type": "string",
                        "description": "City name or zip code"
                      }
                    },
                    "required": ["location"]
                  }
                }
              ],
              "nextCursor": null
            }
          }
          """)
      #expect(tools.map { $0.name } == ["get_weather"])
    }

    @Test("list tools with pagination")
    func test_listTools_withPagination() async throws {
      let tools = try await assert(
        executing: { try await self.sut.listTools() },
        triggers: [
          .request("""
            {
              "id" : 1,
              "jsonrpc" : "2.0",
              "method" : "tools/list",
              "params" : {}
            }
            """),
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "tools": [
                  {
                    "name": "get_weather",
                    "description": "Get current weather information for a location",
                    "inputSchema": {
                      "type": "object",
                      "properties": {
                        "location": {
                          "type": "string",
                          "description": "City name or zip code"
                        }
                      },
                      "required": ["location"]
                    }
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
              "method" : "tools/list",
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
                "tools": [
                  {
                    "name": "get_time",
                    "description": "Get current time information for a location",
                    "inputSchema": {
                      "type": "object",
                      "properties": {
                        "location": {
                          "type": "string",
                          "description": "City name or zip code"
                        }
                      },
                      "required": ["location"]
                    }
                  }
                ],
                "nextCursor": null
              }
            }
            """),
        ])

      #expect(tools.map { $0.name } == ["get_weather", "get_time"])
    }

    @Test("receiving list tool changed notification")
    func test_receivingListToolChangedNotification() async throws {
      let notificationReceived = expectation(description: "Notification received")
      Task {
        for await notification in await sut.notifications {
          switch notification {
          case .toolListChanged:
            notificationReceived.fulfill()
          default:
            Issue.record("Unexpected notification: \(notification)")
          }
        }
      }

      transport.receive(message: """
        {
          "jsonrpc": "2.0",
          "method": "notifications/tools/list_changed"
        }
        """)
      try await fulfillment(of: [notificationReceived])
    }
  }
}
