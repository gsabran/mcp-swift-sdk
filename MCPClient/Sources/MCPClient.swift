////
import Combine
import Foundation
import MCPShared

public typealias SamplingRequestHandler = ((CreateMessageRequest.Params) async throws -> CreateMessageRequest.Result)
public typealias ListRootsRequestHandler = ((ListRootsRequest.Params?) async throws -> ListRootsRequest.Result)

// MARK: - MCPClient

public actor MCPClient: MCPClientInterface {

  // MARK: Lifecycle

  public init(
    info: Implementation,
    transport: Transport,
    capabilities: ClientCapabilityHandlers = .init())
  async throws {
    try await self.init(
      samplingRequestHandler: capabilities.sampling?.handler,
      listRootRequestHandler: capabilities.roots?.handler,
      connection: try MCPClientConnection(
        info: info,
        capabilities: ClientCapabilities(
          experimental: nil, // TODO: support experimental requests
          roots: capabilities.roots?.info,
          sampling: capabilities.sampling?.info),
        transport: transport))
  }

  init(
    samplingRequestHandler: SamplingRequestHandler? = nil,
    listRootRequestHandler: ListRootsRequestHandler? = nil,
    connection: MCPClientConnectionInterface)
  async throws {
    // Initialize the connection, and then update server capabilities.
    self.connection = connection
    self.samplingRequestHandler = samplingRequestHandler
    self.listRootRequestHandler = listRootRequestHandler
    try await connect()
    Task { try await self.updateTools() }
    Task { try await self.updatePrompts() }
    Task { try await self.updateResources() }
    Task { try await self.updateResourceTemplates() }
  }

  // MARK: Public

  public var tools: ReadOnlyCurrentValueSubject<ServerCapabilityState<[Tool]>, Never> {
    get async {
      await .init(_tools.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher())
    }
  }

  public var prompts: ReadOnlyCurrentValueSubject<ServerCapabilityState<[Prompt]>, Never> {
    get async {
      await .init(_prompts.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher())
    }
  }

  public var resources: ReadOnlyCurrentValueSubject<ServerCapabilityState<[Resource]>, Never> {
    get async {
      await .init(_resources.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher())
    }
  }

  public var resourceTemplates: ReadOnlyCurrentValueSubject<ServerCapabilityState<[ResourceTemplate]>, Never> {
    get async {
      await .init(_resourceTemplates.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher())
    }
  }

  public func callTool(
    named name: String,
    arguments: JSON? = nil,
    progressHandler: ((Double, Double?) -> Void)? = nil)
    async throws -> CallToolResult
  {
    let connectionInfo = try getConnectionInfo()
    guard connectionInfo.serverCapabilities.tools != nil else {
      throw MCPClientError.notSupported
    }
    var progressToken: String? = nil
    if let progressHandler {
      let token = UUID().uuidString
      progressHandlers[token] = progressHandler
      progressToken = token
    }
    let result = try await connectionInfo.connection.call(
      toolName: name,
      arguments: arguments,
      progressToken: progressToken.map { .string($0) })
    if let progressToken {
      progressHandlers[progressToken] = nil
    }
    // If there has been an error during the execution, throw it
    if result.isError == true {
      let errors = result.content.compactMap { $0.text }.map { CallToolResult.ExecutionError(text: $0.text) }
      throw MCPClientError.toolCallError(executionErrors: errors)
    }
    return result
  }

  public func getPrompt(named name: String, arguments: JSON? = nil) async throws -> GetPromptResult {
    let connectionInfo = try getConnectionInfo()
    guard connectionInfo.serverCapabilities.prompts != nil else {
      throw MCPClientError.notSupported
    }
    return try await connectionInfo.connection.getPrompt(.init(name: name, arguments: arguments))
  }

  public func readResource(uri: String) async throws -> ReadResourceResult {
    let connectionInfo = try getConnectionInfo()
    guard connectionInfo.serverCapabilities.resources != nil else {
      throw MCPClientError.notSupported
    }
    return try await connectionInfo.connection.readResource(.init(uri: uri))
  }

  // MARK: Internal

  let connection: MCPClientConnectionInterface

  // MARK: Private

  private struct ConnectionInfo {
    let connection: MCPClientConnectionInterface
    let serverInfo: Implementation
    let serverCapabilities: ServerCapabilities
  }

  private let samplingRequestHandler: SamplingRequestHandler?
  private let listRootRequestHandler: ListRootsRequestHandler?

  private var connectionInfo: ConnectionInfo?

  private let _tools = CurrentValueSubject<ServerCapabilityState<[Tool]>?, Never>(nil)
  private let _prompts = CurrentValueSubject<ServerCapabilityState<[Prompt]>?, Never>(nil)
  private let _resources = CurrentValueSubject<ServerCapabilityState<[Resource]>?, Never>(nil)
  private let _resourceTemplates = CurrentValueSubject<ServerCapabilityState<[ResourceTemplate]>?, Never>(nil)

  private var progressHandlers = [String: (progress: Double, total: Double?) -> Void]()

  private func startListeningToNotifications() async throws {
    let connectionInfo = try getConnectionInfo()
    let notifications = await connectionInfo.connection.notifications
    Task { [weak self] in
      for await notification in notifications {
        switch notification {
        case .cancelled:
          break

        case .loggingMessage:
          break

        case .progress(let progressParams):
          if let token = progressParams.progressToken.string {
            await self?.progressHandlers[token]?(progressParams.progress, progressParams.total)
          }

        case .promptListChanged:
          try await self?.updatePrompts()

        case .resourceListChanged:
          try await self?.updateResources()

        case .toolListChanged:
          try await self?.updateResources()

        case .resourceUpdated:
          break
        }
      }
    }
  }

  private func startListeningToRequests() async throws {
    let connectionInfo = try getConnectionInfo()
    let requests = await connectionInfo.connection.requestsToHandle
    Task { [weak self] in
      for await(request, completion) in requests {
        guard let self else {
          completion(.failure(.init(
            code: JRPCErrorCodes.internalError.rawValue,
            message: "The client disconnected")))
          return
        }
        switch request {
        case .createMessage(let params):
          if let handler = await self.samplingRequestHandler {
            do {
              completion(.success(try await handler(params)))
            } catch {
              completion(.failure(.init(
                code: JRPCErrorCodes.internalError.rawValue,
                message: error.localizedDescription)))
            }
          } else {
            completion(.failure(.init(
              code: JRPCErrorCodes.invalidRequest.rawValue,
              message: "Sampling is not supported by this client")))
          }

        case .listRoots(let params):
          if let handler = await self.listRootRequestHandler {
            do {
              completion(.success(try await handler(params)))
            } catch {
              completion(.failure(.init(
                code: JRPCErrorCodes.internalError.rawValue,
                message: error.localizedDescription)))
            }
          } else {
            completion(.failure(.init(
              code: JRPCErrorCodes.invalidRequest.rawValue,
              message: "Listing roots is not supported by this client")))
          }
        }
      }
    }
  }

  private func startPinging() {
    // TODO
  }

  private func updateTools() async throws {
    let connectionInfo = try getConnectionInfo()
    guard connectionInfo.serverCapabilities.tools != nil else {
      // Tool calling not supported
      _tools.send(.notSupported)
      return
    }
    let tools = try await connectionInfo.connection.listTools()
    _tools.send(.supported(tools))
  }

  private func updatePrompts() async throws {
    let connectionInfo = try getConnectionInfo()
    guard connectionInfo.serverCapabilities.prompts != nil else {
      // Prompts calling not supported
      _prompts.send(.notSupported)
      return
    }
    let prompts = try await connectionInfo.connection.listPrompts()
    _prompts.send(.supported(prompts))
  }

  private func updateResources() async throws {
    let connectionInfo = try getConnectionInfo()
    guard connectionInfo.serverCapabilities.resources != nil else {
      // Resources calling not supported
      _resources.send(.notSupported)
      return
    }
    let resources = try await connectionInfo.connection.listResources()
    _resources.send(.supported(resources))
  }

  private func updateResourceTemplates() async throws {
    let connectionInfo = try getConnectionInfo()
    guard connectionInfo.serverCapabilities.resources != nil else {
      // Resources calling not supported
      _resourceTemplates.send(.notSupported)
      return
    }
    let resourceTemplates = try await connectionInfo.connection.listResourceTemplates()
    _resourceTemplates.send(.supported(resourceTemplates))
  }

  private func connect() async throws {
    let response = try await connection.initialize()
    guard response.protocolVersion == MCP.protocolVersion else {
      throw MCPClientError.versionMismatch
    }

    connectionInfo = ConnectionInfo(
      connection: connection,
      serverInfo: response.serverInfo,
      serverCapabilities: response.capabilities)

    try await connection.acknowledgeInitialization()
    try await startListeningToNotifications()
    try await startListeningToRequests()
    startPinging()
  }

  private func getConnectionInfo() throws -> ConnectionInfo {
    guard let connectionInfo else {
      throw MCPClientInternalError.internalStateInconsistency
    }
    return connectionInfo
  }

}

// MARK: - MCPClientInternalError

public enum MCPClientInternalError: Error {
  case alreadyConnectedOrConnecting
  case notConnected
  case internalStateInconsistency
}
