
import JSONRPC
import MCPShared
import SwiftTestingUtils
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class ClientInitializationTests: MCPClientConnectionTest {

    @Test("initialize connection")
    func test_initializeConnection() async throws {
      let initializationResult = try await assert(
        executing: {
          try await self.sut.initialize()
        },
        sends: """
          {
            "id" : 1,
            "jsonrpc" : "2.0",
            "method" : "initialize",
            "params" : {
              "capabilities" : {
                "roots" : {
                  "listChanged" : true
                },
                "sampling" : {}
              },
              "clientInfo" : {
                "name" : "TestClient",
                "version" : "1.0.0"
              },
              "protocolVersion" : "\(MCP.protocolVersion)"
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "protocolVersion": "2024-11-05",
              "capabilities": {
                "logging": {},
                "prompts": {
                  "listChanged": true
                },
                "resources": {
                  "subscribe": true,
                  "listChanged": true
                },
                "tools": {
                  "listChanged": true
                }
              },
              "serverInfo": {
                "name": "ExampleServer",
                "version": "1.0.0"
              }
            }
          }
          """)
      #expect(initializationResult.serverInfo.name == "ExampleServer")
    }

    @Test("initialize with error")
    func test_initializeWithError() async throws {
      await assert(
        executing: { _ = try await self.sut.initialize() },
        sends: """
          {
            "id" : 1,
            "jsonrpc" : "2.0",
            "method" : "initialize",
            "params" : {
              "capabilities" : {
                "roots" : {
                  "listChanged" : true
                },
                "sampling" : {}
              },
              "clientInfo" : {
                "name" : "TestClient",
                "version" : "1.0.0"
              },
              "protocolVersion" : "\(MCP.protocolVersion)"
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "error": {
              "code": -32602,
              "message": "Unsupported protocol version",
              "data": {
                "supported": ["2024-11-05"],
                "requested": "1.0.0"
              }
            }
          }
          """) { error in
          guard let notificationError = try? #require(error as? JSONRPCResponseError<JSONRPC.JSONValue>) else {
            Issue.record("unexpected error type \(error)")
            return
          }

          #expect(notificationError.code == -32602)
          #expect(notificationError.message == "Unsupported protocol version")
          #expect(notificationError.data == [
            "supported": ["2024-11-05"],
            "requested": "1.0.0",
          ])
        }
    }

    @Test("initialization acknowledgement")
    func test_initializationAcknowledgement() async throws {
      let notificationReceived = expectation(description: "notification received")

      transport.expect(messages: [
        { sendMessage in
          sendMessage("""
            {
              "jsonrpc" : "2.0",
              "method" : "notifications/initialized",
              "params" : null
            }
            """)
          notificationReceived.fulfill()
        },
      ])

      try await sut.acknowledgeInitialization()
      try await fulfillment(of: [notificationReceived])
    }

    @Test("deinitialization")
    func test_deinitializationReleasesReferencedObjects() async throws {
      // initialize the MCP connection. This will create a JRPC session.
      try await test_initializeConnection()

      // Get pointers to values that we want to see dereferenced when MCPClientConnection is dereferenced
      weak var weakTransport = transport
      #expect(weakTransport != nil)

      // Replace the values referenced by this test class.
      transport = MockTransport()
      sut = try await MCPClientConnection(
        info: sut.info,
        capabilities: sut.capabilities,
        transport: transport.dataChannel)

      // Verifies that the referenced objects are released.
      #expect(weakTransport == nil)
    }
  }
}
