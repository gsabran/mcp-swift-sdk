
import JSONRPC
import SwiftTestingUtils
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class ListPromptsTests: MCPClientConnectionTest {

    @Test("list prompts")
    func test_listPrompts() async throws {
      let prompts = try await assert(
        executing: {
          try await self.sut.listPrompts()
        },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "prompts/list",
            "params": {}
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "prompts": [
                {
                  "name": "code_review",
                  "description": "Asks the LLM to analyze code quality and suggest improvements",
                  "arguments": [
                    {
                      "name": "code",
                      "description": "The code to review",
                      "required": true
                    }
                  ]
                }
              ]
            }
          }
          """)
      #expect(prompts.map { $0.name } == ["code_review"])
    }

    @Test("list prompts with pagination")
    func test_listPrompts_withPagination() async throws {
      let prompts = try await assert(
        executing: { try await self.sut.listPrompts() },
        triggers: [
          .request("""
            {
              "id" : 1,
              "jsonrpc" : "2.0",
              "method" : "prompts/list",
              "params" : {}
            }
            """),
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "prompts": [
                  {
                    "name": "code_review",
                    "description": "Asks the LLM to analyze code quality and suggest improvements",
                    "arguments": [
                      {
                        "name": "code",
                        "description": "The code to review",
                        "required": true
                      }
                    ]
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
              "method" : "prompts/list",
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
                "prompts": [
                  {
                    "name": "test_code",
                    "description": "Asks the LLM to write a unit test for the code",
                    "arguments": [
                      {
                        "name": "code",
                        "description": "The code to test",
                        "required": true
                      }
                    ]
                  }
                ]
              }
            }
            """),
        ])
      #expect(prompts.map { $0.name } == ["code_review", "test_code"])
    }

    @Test("receiving prompts list changed notification")
    func test_receivingPromptsListChangedNotification() async throws {
      let notificationReceived = expectation(description: "Notification received")
      Task {
        for await notification in await sut.notifications {
          switch notification {
          case .promptListChanged:
            notificationReceived.fulfill()
          default:
            Issue.record("Unexpected notification: \(notification)")
          }
        }
      }

      transport.receive(message: """
        {
          "jsonrpc": "2.0",
          "method": "notifications/prompts/list_changed"
        }
        """)
      try await fulfillment(of: [notificationReceived])
    }
  }
}
