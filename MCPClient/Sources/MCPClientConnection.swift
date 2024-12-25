import Foundation
import JSONRPC
import MCPShared
import MemberwiseInit
import OSLog

private let mcpLogger = Logger(subsystem: Bundle.main.bundleIdentifier.map { "\($0).mcp" } ?? "com.app.mcp", category: "mcp")

// MARK: - MCPClientConnection

public actor MCPClientConnection: MCPClientConnectionInterface {

  // MARK: Lifecycle

  public init(
    info: Implementation,
    capabilities: ClientCapabilities,
    transport: Transport)
    throws
  {
    self.info = info
    self.capabilities = capabilities
    jrpcSession = JSONRPCSession(channel: transport)

    var sendNotificationToStream: (ServerNotification) -> Void = { _ in }
    notifications = AsyncStream<ServerNotification>() { continuation in
      sendNotificationToStream = { continuation.yield($0) }
    }
    self.sendNotificationToStream = sendNotificationToStream

    // A bit hard to read... When a server request is received (sent to `askForRequestToBeHandle`), we yield it to the stream
    // where we expect someone to be listening and handling the request. The handler then calls the completion `requestContinuation`
    // which will be sent back as an async response to `askForRequestToBeHandle`.
    var askForRequestToBeHandle: ((ServerRequest) async -> AnyJRPCResponse)? = nil
    requestsToHandle = AsyncStream<HandleServerRequest>() { streamContinuation in
      askForRequestToBeHandle = { request in
        await withCheckedContinuation { (requestContinuation: CheckedContinuation<AnyJRPCResponse, Never>) in
          streamContinuation.yield((request, { response in
            requestContinuation.resume(returning: response)
          }))
        }
      }
    }
    self.askForRequestToBeHandle = askForRequestToBeHandle

    Task { await listenToIncomingMessages() }
  }

  // MARK: Public

  public private(set) var notifications: AsyncStream<ServerNotification>
  public private(set) var requestsToHandle: AsyncStream<HandleServerRequest>

  public let info: Implementation

  public let capabilities: ClientCapabilities

  public func initialize() async throws -> InitializeRequest.Result {
    let params = InitializeRequest.Params(
      protocolVersion: MCP.protocolVersion,
      capabilities: capabilities,
      clientInfo: info)

    // TODO: move this to other layer
    let initializationResponse = try await jrpcSession.send(InitializeRequest(params: params))
    assert(initializationResponse.protocolVersion == MCP.protocolVersion, "Server and client protocol version mismatch")
    return initializationResponse
  }

  public func acknowledgeInitialization() async throws {
    try await jrpcSession.send(InitializedNotification())
  }

  public func ping() async throws {
    // TODO: add timeout
    _ = try await jrpcSession.send(PingRequest())
  }

  public func listPrompts() async throws -> [Prompt] {
    try await jrpcSession.send(ListPromptsRequest.Params(), getResults: { $0.prompts }, req: ListPromptsRequest.self)
  }

  public func getPrompt(_ params: GetPromptRequest.Params) async throws -> GetPromptRequest.Result {
    try await jrpcSession.send(GetPromptRequest(params: params))
  }

  public func listResources() async throws -> [Resource] {
    try await jrpcSession.send(ListResourcesRequest.Params(), getResults: { $0.resources }, req: ListResourcesRequest.self)
  }

  public func readResource(_ params: ReadResourceRequest.Params) async throws -> ReadResourceRequest.Result {
    try await jrpcSession.send(ReadResourceRequest(params: params))
  }

  public func subscribeToUpdateToResource(_ params: SubscribeRequest.Params) async throws {
    _ = try await jrpcSession.send(SubscribeRequest(params: params))
  }

  public func unsubscribeToUpdateToResource(_ params: UnsubscribeRequest.Params) async throws {
    _ = try await jrpcSession.send(UnsubscribeRequest(params: params))
  }

  public func listResourceTemplates() async throws -> [ResourceTemplate] {
    try await jrpcSession.send(
      ListResourceTemplatesRequest.Params(),
      getResults: { $0.resourceTemplates },
      req: ListResourceTemplatesRequest.self)
  }

  public func listTools() async throws -> [Tool] {
    try await jrpcSession.send(ListToolsRequest.Params(), getResults: { $0.tools }, req: ListToolsRequest.self)
  }

  public func call(
    toolName: String,
    arguments: JSON? = nil,
    progressToken: ProgressToken? = nil)
    async throws -> CallToolRequest.Result
  {
    let _meta = progressToken.map { CallToolRequest.Params.Meta(progressToken: $0) }
    return try await jrpcSession.send(CallToolRequest(params: .init(_meta: _meta, name: toolName, arguments: arguments)))
  }

  public func requestCompletion(_ params: CompleteRequest.Params) async throws -> CompleteRequest.Result {
    try await jrpcSession.send(CompleteRequest(params: params))
  }

  public func setLogLevel(_ params: SetLevelRequest.Params) async throws -> SetLevelRequest.Result {
    try await jrpcSession.send(SetLevelRequest(params: params))
  }

  public func log(_ params: LoggingMessageNotification.Params) async throws {
    try await jrpcSession.send(LoggingMessageNotification(params: params))
  }

  // MARK: Private

  private var sendNotificationToStream: ((ServerNotification) -> Void) = { _ in }

  private var askForRequestToBeHandle: ((ServerRequest) async -> AnyJRPCResponse)? = nil

  private let jrpcSession: JSONRPCSession

  private var eventHandlers = [String: (JSONRPCEvent) -> Void]()

  private func listenToIncomingMessages() async {
    let events = await jrpcSession.eventSequence
    Task { [weak self] in
      for await event in events {
        await self?.handle(receptionOf: event)
      }
    }
  }

  private func handle(receptionOf event: JSONRPCEvent) {
    switch event {
    case .notification(_, let data):
      do {
        let notification = try JSONDecoder().decode(ServerNotification.self, from: data)
        sendNotificationToStream(notification)
      } catch {
        mcpLogger
          .error("Failed to decode notification \(String(data: data, encoding: .utf8) ?? "invalid data", privacy: .public)")
      }

    case .request(_, let handler, let data):
      // Respond to ping from the server
      Task { await handler(handle(receptionOf: data)) }

    case .error(let error):
      mcpLogger.error("Received error from server: \(error, privacy: .public)")
    }
  }

  private func handle(receptionOf request: Data) async -> AnyJRPCResponse {
    if let serverRequest = try? JSONDecoder().decode(ServerRequest.self, from: request) {
      guard let askForRequestToBeHandle else {
        mcpLogger.error("Unable to handle request. The client MCP connection has not been set properly")
        return .failure(.init(
          code: JRPCErrorCodes.methodNotFound.rawValue,
          message: "Unable to handle request. The client MCP connection has not been set properly"))
      }
      return await askForRequestToBeHandle(serverRequest)
    } else if (try? JSONDecoder().decode(PingRequest.self, from: request)) != nil {
      // Respond to ping from the server
      return .success(PingRequest.Result())
    }
    mcpLogger
      .error(
        "Received unknown request from server: \(String(data: request, encoding: .utf8) ?? "invalid data", privacy: .public)")
    return .failure(.init(
      code: JRPCErrorCodes.methodNotFound.rawValue,
      message: "The request could not be decoded to a known type"))
  }

}

extension JSONRPCSession {
  func send<Req: Request>(_ request: Req) async throws -> Req.Result {
    let response: JSONRPCResponse<Req.Result> = try await sendRequest(request.params, method: request.method)
    return try response.content.get()
  }

  func send(_ notification: some MCPShared.Notification) async throws {
    try await sendNotification(notification.params, method: notification.method)
  }

  func send<Req: PaginatedRequest, Result>(
    _ params: Req.Params,
    getResults: (Req.Result) -> [Result],
    req _: Req.Type = Req.self)
    async throws -> [Result]
  {
    var cursor: String? = nil
    var results = [Result]()

    while true {
      let request = Req(params: params.updatingCursor(to: cursor))
      let response = try await send(request)
      results.append(contentsOf: getResults(response))
      cursor = response.nextCursor
      if cursor == nil {
        return results
      }
    }
  }

}
