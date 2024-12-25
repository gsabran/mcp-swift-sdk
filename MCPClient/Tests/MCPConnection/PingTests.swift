
import JSONRPC
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class PingTests: MCPClientConnectionTest {

    @Test("sending ping")
    func sendingPing() async throws {
      try await assert(
        executing: {
          try await self.sut.ping()
        },
        sends: """
          {
            "id" : 1,
            "jsonrpc" : "2.0",
            "method" : "ping",
            "params" : null
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

    @Test("receiving ping")
    func receivingPing() async throws {
      try await assert(
        receiving: """
          {
            "jsonrpc" : "2.0",
            "id" : 1,
            "method" : "ping"
          }
          """,
        respondsWith: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {}
          }
          """)
    }

  }
}
