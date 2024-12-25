
import JSONRPC
import MCPShared
import SwiftTestingUtils
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class LoggingTests: MCPClientConnectionTest {
    @Test("setting log level")
    func test_settingLogLevel() async throws {
      _ = try await assert(
        executing: {
          try await self.sut.setLogLevel(SetLevelRequest.Params(level: .debug))
        },
        sends: """
          {
            "id" : 1,
            "jsonrpc" : "2.0",
            "method" : "logging/setLevel",
            "params" : {
              "level" : "debug"
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {}
          }
          """)
    }

    @Test("send a log")
    func test_sendALog() async throws {
      try await assert(
        executing: {
          try await self.sut.log(LoggingMessageNotification.Params(level: .debug, data: .string("Up and running!")))
        },
        triggers: [.request("""
          {
            "jsonrpc" : "2.0",
            "method" : "notifications/message",
            "params" : {
              "data" : "Up and running!",
              "level" : "debug"
            }
          }
          """)])
    }

    @Test("receive a server log notification")
    func test_receivesServerLogNotification() async throws {
      let notificationReceived = expectation(description: "Notification received")
      Task {
        for await notification in await sut.notifications {
          switch notification {
          case .loggingMessage(let message):
            #expect(message.level == .error)
            #expect(message.data == .object([
              "error": .string("Connection failed"),
              "details": .object([
                "host": .string("localhost"),
                "port": .number(5432),
              ]),
            ]))
            notificationReceived.fulfill()

          default:
            Issue.record("Unexpected notification: \(notification)")
          }
        }
      }

      transport.receive(message: """
        {
          "jsonrpc": "2.0",
          "method": "notifications/message",
          "params": {
            "level": "error",
            "logger": "database",
            "data": {
              "error": "Connection failed",
              "details": {
                "host": "localhost",
                "port": 5432
              }
            }
          }
        }
        """)
      try await fulfillment(of: [notificationReceived])
    }

  }
}
