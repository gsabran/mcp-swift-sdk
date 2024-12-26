
import Foundation
import MCPShared
import SwiftTestingUtils
import Testing
@testable import MCPClient

// MARK: - MCPClientTestSuite.Initialization

extension MCPClientTestSuite {

  class Initialization: MCPClientTest {
    @Test("initialization")
    func test_initialization() async throws {
      let initializationRequestIsSent = expectation(description: "initialization request is sent")
      let initializationIsAcknowledged = expectation(description: "initialization is acknowledged")

      connection.initializeStub = {
        initializationRequestIsSent.fulfill()
        return .init(
          protocolVersion: MCP.protocolVersion,
          capabilities: .init(),
          serverInfo: .init(name: "test-server", version: MCP.protocolVersion))
      }

      connection.acknowledgeInitializationStub = {
        initializationIsAcknowledged.fulfill()
      }

      _ = try await createMCPClient()
      try await fulfillment(of: [initializationRequestIsSent, initializationIsAcknowledged])
    }

    @Test("initialization with capabilities")
    func test_initializationWithCapabilities_sendsCorrectCapabilities() async throws {
      let transport = MockTransport()
      let client = try await MCPClientConnectionTest.assert(executing: {
        try await MCPClient(
          info: Implementation(name: "test-client", version: "1.0.0"),
          transport: transport.dataChannel,
          capabilities: ClientCapabilityHandlers(
            roots: .init(info: .init(listChanged: true), handler: { _ in .init(roots: []) }),
            sampling: .init(handler: { _ in .init(role: .user, content: .text(.init(text: "hello")), model: "claude") })))
      }, triggers: [
        .request("""
          {
            "id" : 1,
            "jsonrpc" : "2.0",
            "method" : "initialize",
            "params" : {
              "capabilities" : {
                "roots" : {
                  "listChanged" : true
                },
                "sampling" : {

                }
              },
              "clientInfo" : {
                "name" : "test-client",
                "version" : "1.0.0"
              },
              "protocolVersion" : "2024-11-05"
            }
          }
          """),
        .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "serverInfo": {
                  "name": "ExampleServer",
                  "version": "1.0.0"
                }
              }
            }
          """),
        .request("""
          {
            "jsonrpc" : "2.0",
            "method" : "notifications/initialized",
            "params" : null
          }
          """),
      ], with: transport)

      let clientCapabilities = await(client.connection as? MCPClientConnection)?.capabilities
      #expect(clientCapabilities?.roots?.listChanged == true)
      #expect(clientCapabilities?.sampling != nil)
    }

    @Test("deinitialization")
    func test_deinitialization() async throws {
      let initializationRequestIsSent = expectation(description: "initialization request is sent")
      let initializationIsAcknowledged = expectation(description: "initialization is acknowledged")

      var connection: MockMCPClientConnection? = try! MockMCPClientConnection(
        info: .init(name: name, version: version),
        capabilities: capabilities)

      connection?.initializeStub = {
        initializationRequestIsSent.fulfill()
        return .init(
          protocolVersion: MCP.protocolVersion,
          capabilities: .init(),
          serverInfo: .init(name: "test-server", version: MCP.protocolVersion))
      }

      connection?.acknowledgeInitializationStub = {
        initializationIsAcknowledged.fulfill()
      }
      weak var connectionReference = connection

      var client: MCPClient? = try await createMCPClient(connection: connection!)
      _ = client
      try await fulfillment(of: [initializationRequestIsSent, initializationIsAcknowledged])

      connection = nil
      // The client is still referenced, the connection should be kept alive.
      #expect(connectionReference != nil)

      // Dereference the client. The connection should be released.
      client = nil

      // The test fails when executed in parallel with other tests, while the memory graph shows no retention when this happens.
      // Doing this otherwise non ideal queue hop seems to fix this issue.
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
          continuation.resume(returning: ())
        }
      }

      #expect(connectionReference == nil)
    }
  }

}
