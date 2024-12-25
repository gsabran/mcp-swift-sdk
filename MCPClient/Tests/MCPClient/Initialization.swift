
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

      var client: MCPClient? = try await createMCPClient(getConnection: { connection! })
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
