
import JSONRPC
import MCPShared

public typealias AnyJRPCResponse = Swift.Result<Encodable & Sendable, AnyJSONRPCResponseError>

public typealias HandleServerRequest = (ServerRequest, (AnyJRPCResponse) -> Void)

// MARK: - MCPClientConnectionInterface

/// The MCP JRPC Bridge is a stateless interface to the MCP server that provides a higher level Swift interface.
/// It does not implement any of the stateful behaviors of the MCP server, such as subscribing to changes, detecting connection health,
/// ensuring that the connection has been initialized before being used etc.
///
/// For most use cases, `MCPClient` should be a preferred interface.
public protocol MCPClientConnectionInterface {
  /// The notifications received by the server.
  var notifications: AsyncStream<ServerNotification> { get async }
  // TODO: look at moving the request handler to the init
  /// The requests received by the server that need to be responded to.
  var requestsToHandle: AsyncStream<HandleServerRequest> { get async }

  /// Creates a new MCP JRPC Bridge.
  /// This will create a new connection with the transport corresponding to the MCP server, but it will not send the initialization request as specified by the MCP protocol.
  /// The connection will be closed when this object is de-initialized.
  init(
    info: Implementation,
    capabilities: ClientCapabilities,
    transport: Transport) throws

  /// Initializes the MCP connection to the server.
  func initialize() async throws -> InitializeRequest.Result
  /// Confirms to the server that the connection has been initialized
  func acknowledgeInitialization() async throws
  /// Send a ping to the server
  func ping() async throws
  /// Get the list of available prompts. The caller is responsible for ensuring the server supports prompts.
  func listPrompts() async throws -> [Prompt]
  /// Get a specific prompt.
  func getPrompt(_ params: GetPromptRequest.Params) async throws -> GetPromptRequest.Result
  /// Get the list of available resources. The caller is responsible for ensuring the server supports resources.
  func listResources() async throws -> [Resource]
  /// Get a specific resource.
  func readResource(_ params: ReadResourceRequest.Params) async throws -> ReadResourceRequest.Result
  /// Subscribe to updates to a resource.
  func subscribeToUpdateToResource(_ params: SubscribeRequest.Params) async throws
  /// Unsubscribe to updates to a resource.
  func unsubscribeToUpdateToResource(_ params: UnsubscribeRequest.Params) async throws
  /// Get the list of available resource templates. The caller is responsible for ensuring the server supports resources.
  func listResourceTemplates() async throws -> [ResourceTemplate]
  /// Get the list of available tools. The caller is responsible for ensuring the server supports tools calling.
  func listTools() async throws -> [Tool]
  /// Call a specific tool.
  func call(
    toolName: String,
    arguments: JSON?,
    progressToken: ProgressToken?) async throws -> CallToolRequest.Result
  /// Request code/text completion.
  func requestCompletion(_ params: CompleteRequest.Params) async throws -> CompleteRequest.Result
  /// Set the log level that the server should use for this connection.
  func setLogLevel(_ params: SetLevelRequest.Params) async throws -> SetLevelRequest.Result
  /// Log a message to the server.
  func log(_ params: LoggingMessageNotification.Params) async throws
}
