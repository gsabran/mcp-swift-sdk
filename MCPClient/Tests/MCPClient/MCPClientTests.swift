
import MCPShared
import Testing
@testable import MCPClient

// MARK: - MCPClientTestSuite

@Suite("MCP Client")
class MCPClientTestSuite { }

// MARK: - MCPClientTest

class MCPClientTest {

  // MARK: Lifecycle

  init() {
    version = "1.0.0"
    name = "TestClient"
    capabilities = ClientCapabilities(
      roots: .init(listChanged: true),
      sampling: .init())

    connection = try! MockMCPClientConnection(
      info: .init(name: name, version: version),
      capabilities: capabilities)

    connection.initializeStub = {
      .init(
        protocolVersion: MCP.protocolVersion,
        capabilities: .init(
          logging: EmptyObject(),
          prompts: ListChangedCapability(listChanged: true),
          resources: CapabilityInfo(subscribe: true, listChanged: true),
          tools: ListChangedCapability(listChanged: true)),
        serverInfo: .init(name: "test-server", version: MCP.protocolVersion))
    }
    connection.acknowledgeInitializationStub = { }
    connection.listToolsStub = { [] }
    connection.listPromptsStub = { [] }
    connection.listResourcesStub = { [] }
    connection.listResourceTemplatesStub = { [] }
  }

  // MARK: Internal

  let version: String
  let capabilities: ClientCapabilities
  let name: String
  let connection: MockMCPClientConnection

  func createMCPClient(
    samplingRequestHandler: SamplingRequestHandler? = nil,
    listRootRequestHandler: ListRootsRequestHandler? = nil,
    connection: MCPClientConnectionInterface? = nil)
    async throws -> MCPClient
  {
    try await MCPClient(
      samplingRequestHandler: samplingRequestHandler,
      listRootRequestHandler: listRootRequestHandler,
      connection: connection ?? self.connection)
  }

}
