
import MCPShared

#if DEBUG
// TODO: move to a test helper package

/// A mock `MCPClientConnection` that can be used in tests.
class MockMCPClientConnection: MCPClientConnectionInterface {

  // MARK: Lifecycle

  required init(info: Implementation, capabilities: ClientCapabilities, transport _: Transport = .noop) throws {
    self.info = info
    self.capabilities = capabilities

    var sendNotificationToStream: (ServerNotification) -> Void = { _ in }
    notifications = AsyncStream<ServerNotification>() { continuation in
      sendNotificationToStream = { continuation.yield($0) }
    }
    self.sendNotificationToStream = sendNotificationToStream

    var sendRequestToStream: (HandleServerRequest) -> Void = { _ in }
    requestsToHandle = AsyncStream<HandleServerRequest>() { continuation in
      sendRequestToStream = { continuation.yield($0) }
    }
    self.sendRequestToStream = sendRequestToStream
  }

  // MARK: Internal

  /// Send a server notification.
  private(set) var sendNotificationToStream: ((ServerNotification) -> Void) = { _ in }
  /// Send a server request to the handler.
  private(set) var sendRequestToStream: ((HandleServerRequest) -> Void) = { _ in }

  let info: Implementation
  let capabilities: ClientCapabilities

  var notifications: AsyncStream<ServerNotification>

  var requestsToHandle: AsyncStream<HandleServerRequest>

  /// This function is called when `initialize` is called
  var initializeStub: (() async throws -> InitializeRequest.Result)?

  /// This function is called when `acknowledgeInitialization` is called
  var acknowledgeInitializationStub: (() async throws -> Void)?

  /// This function is called when `ping` is called
  var pingStub: (() async throws -> Void)?

  /// This function is called when `listPrompts` is called
  var listPromptsStub: (() async throws -> [Prompt])?

  /// This function is called when `getPrompt` is called
  var getPromptStub: ((GetPromptRequest.Params) async throws -> GetPromptRequest.Result)?

  /// This function is called when `listResources` is called
  var listResourcesStub: (() async throws -> [Resource])?

  /// This function is called when `readResource` is called
  var readResourceStub: ((ReadResourceRequest.Params) async throws -> ReadResourceRequest.Result)?

  /// This function is called when `subscribeToUpdateToResource` is called
  var subscribeToUpdateToResourceStub: ((SubscribeRequest.Params) async throws -> Void)?

  /// This function is called when `unsubscribeToUpdateToResource` is called
  var unsubscribeToUpdateToResourceStub: ((UnsubscribeRequest.Params) async throws -> Void)?

  /// This function is called when `listResourceTemplates` is called
  var listResourceTemplatesStub: (() async throws -> [ResourceTemplate])?

  /// This function is called when `listTools` is called
  var listToolsStub: (() async throws -> [Tool])?

  /// This function is called when `call` is called
  var callToolStub: ((String, JSON?, ProgressToken?) async throws -> CallToolRequest.Result)?

  /// This function is called when `requestCompletion` is called
  var requestCompletionStub: ((CompleteRequest.Params) async throws -> CompleteRequest.Result)?

  /// This function is called when `setLogLevel` is called
  var setLogLevelStub: ((SetLevelRequest.Params) async throws -> SetLevelRequest.Result)?

  /// This function is called when `log` is called
  var logStub: ((LoggingMessageNotification.Params) async throws -> Void)?

  func initialize() async throws -> InitializeRequest.Result {
    if let initializeStub {
      return try await initializeStub()
    }
    throw MockMCPClientConnectionError.notImplemented(function: "initialize")
  }

  func acknowledgeInitialization() async throws {
    if let acknowledgeInitializationStub {
      return try await acknowledgeInitializationStub()
    }
    throw MockMCPClientConnectionError.notImplemented(function: "acknowledgeInitialization")
  }

  func ping() async throws {
    if let pingStub {
      return try await pingStub()
    }
    throw MockMCPClientConnectionError.notImplemented(function: "ping")
  }

  func listPrompts() async throws -> [Prompt] {
    if let listPromptsStub {
      return try await listPromptsStub()
    }
    throw MockMCPClientConnectionError.notImplemented(function: "listPrompts")
  }

  func getPrompt(_ params: GetPromptRequest.Params) async throws -> GetPromptRequest.Result {
    if let getPromptStub {
      return try await getPromptStub(params)
    }
    throw MockMCPClientConnectionError.notImplemented(function: "getPrompt")
  }

  func listResources() async throws -> [Resource] {
    if let listResourcesStub {
      return try await listResourcesStub()
    }
    throw MockMCPClientConnectionError.notImplemented(function: "listResources")
  }

  func readResource(_ params: ReadResourceRequest.Params) async throws -> ReadResourceRequest.Result {
    if let readResourceStub {
      return try await readResourceStub(params)
    }
    throw MockMCPClientConnectionError.notImplemented(function: "readResource")
  }

  func subscribeToUpdateToResource(_ params: SubscribeRequest.Params) async throws {
    if let subscribeToUpdateToResourceStub {
      return try await subscribeToUpdateToResourceStub(params)
    }
    throw MockMCPClientConnectionError.notImplemented(function: "subscribeToUpdateToResource")
  }

  func unsubscribeToUpdateToResource(_ params: UnsubscribeRequest.Params) async throws {
    if let unsubscribeToUpdateToResourceStub {
      return try await unsubscribeToUpdateToResourceStub(params)
    }
    throw MockMCPClientConnectionError.notImplemented(function: "unsubscribeToUpdateToResource")
  }

  func listResourceTemplates() async throws -> [ResourceTemplate] {
    if let listResourceTemplatesStub {
      return try await listResourceTemplatesStub()
    }
    throw MockMCPClientConnectionError.notImplemented(function: "listResourceTemplates")
  }

  func listTools() async throws -> [Tool] {
    if let listToolsStub {
      return try await listToolsStub()
    }
    throw MockMCPClientConnectionError.notImplemented(function: "listTools")
  }

  func call(toolName: String, arguments: JSON?, progressToken: ProgressToken?) async throws -> CallToolRequest.Result {
    if let callToolStub {
      return try await callToolStub(toolName, arguments, progressToken)
    }
    throw MockMCPClientConnectionError.notImplemented(function: "callTool")
  }

  func requestCompletion(_ params: CompleteRequest.Params) async throws -> CompleteRequest.Result {
    if let requestCompletionStub {
      return try await requestCompletionStub(params)
    }
    throw MockMCPClientConnectionError.notImplemented(function: "requestCompletion")
  }

  func setLogLevel(_ params: SetLevelRequest.Params) async throws -> SetLevelRequest.Result {
    if let setLogLevelStub {
      return try await setLogLevelStub(params)
    }
    throw MockMCPClientConnectionError.notImplemented(function: "setLogLevel")
  }

  func log(_ params: LoggingMessageNotification.Params) async throws {
    if let logStub {
      return try await logStub(params)
    }
    throw MockMCPClientConnectionError.notImplemented(function: "log")
  }
}

enum MockMCPClientConnectionError: Error {
  case notImplemented(function: String)
}

extension Transport {
  static var noop: Transport {
    .init(writeHandler: { _ in }, dataSequence: DataSequence { _ in })
  }
}
#endif
