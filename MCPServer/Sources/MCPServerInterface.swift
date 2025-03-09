import Foundation
import JSONRPC
import JSONSchemaBuilder
import MCPInterface
import MemberwiseInit

// MARK: - MCPServerInterface

public protocol MCPServerInterface {
    var clientInfo: ClientInfo { get async }
    
    /// The client's roots. This will be update if the client changes them.
    var roots: ReadOnlyCurrentValueSubject<CapabilityStatus<[Root]>, Never> { get async }
    /// A method that completes once the client has disconnected.
    func waitForDisconnection() async throws
    /// Ask the client to sample an LLM for the given parameters.
    func getSampling(params: CreateSamplingMessageRequest.Params) async throws -> CreateSamplingMessageRequest.Result
    /// Ask the client to log an event.
    func log(params: LoggingMessageNotification.Params) async throws
    /// Update the list of available tools, and notify the client that the list has changed.
    func update(tools: [any CallableTool]) async throws
    /// Notify the client that a specific resource has been updated.
    func notifyResourceUpdated(params: ResourceUpdatedNotification.Params) async throws
    /// Notify the client that the list of available resources has been updated.
    func notifyResourceListChanged(params: ResourceListChangedNotification.Params?) async throws
    /// Notify the client that the list of available tools has been updated.
    func notifyToolListChanged(params: ToolListChangedNotification.Params?) async throws
    /// Notify the client that the list of available prompts has been updated.
    func notifyPromptListChanged(params: PromptListChangedNotification.Params?) async throws
}

// MARK: - ServerCapabilityHandlers

/// Capabilities that the server supports.
/// Each supported capability provides the handlers required to respond to the relevant requests from the client.
///
/// Note: This is similar to `ServerCapabilities`, with the addition of the handler function.
@MemberwiseInit(.public, _optionalsDefaultNil: true)
public struct ServerCapabilityHandlers {
    /// Present if the server supports sending log messages to the client.
    public let logging: SetLevelRequest.Handler?
    /// Present if the server offers any prompt templates.
    public let prompts: ListedCapabilityHandler<ListChangedCapability, GetPromptRequest.Handler, ListPromptsRequest.Handler>?
    /// Present if the server offers any tools to call.
    public let tools: ListedCapabilityHandler<ListChangedCapability, CallToolRequest.Handler, ListToolsRequest.Handler>?
    /// Present if the server offers any resources to read.
    public let resources: ResourcesCapabilityHandler?
    
    /// Returns server capabilities description inferred from handlers
    var capabilitiesDescription: ServerCapabilities {
        ServerCapabilities(
            experimental: nil, // TODO: support experimental requests
            logging: logging != nil ? EmptyObject() : nil,
            prompts: prompts?.info,
            resources: resources.map { capability in
                CapabilityInfo(
                    subscribe: capability.subscribeToResource != nil,
                    listChanged: capability.listChanged
                )
            },
            tools: tools?.info
        )
    }
}

// MARK: - ListedCapabilityHandler

/// A capability that has a list of options (ex: prompts, tools, resources)
@MemberwiseInit(.public, _optionalsDefaultNil: true)
public struct ListedCapabilityHandler<Info, Handler, ListHandler> {
    public let info: Info
    public let handler: Handler
    public let listHandler: ListHandler
}

// MARK: - ResourcesCapabilityHandler

/// All the handler functions required to support the `resources` capability.
public struct ResourcesCapabilityHandler {
    
    // MARK: Lifecycle
    
    public init(
        listChanged: Bool = false,
        readResource: @escaping ReadResourceRequest.Handler,
        listResource: @escaping ListResourcesRequest.Handler,
        listResourceTemplates: @escaping ListResourceTemplatesRequest.Handler,
        subscribeToResource: SubscribeRequest.Handler? = nil,
        unsubscribeToResource: UnsubscribeRequest.Handler? = nil,
        complete: CompleteRequest.Handler? = nil)
    {
        self.listChanged = listChanged
        self.readResource = readResource
        self.listResource = listResource
        self.listResourceTemplates = listResourceTemplates
        self.subscribeToResource = subscribeToResource
        self.unsubscribeToResource = unsubscribeToResource
        self.complete = complete
    }
    
    // MARK: Public
    
    /// Whether this server supports notifications for changes to the resource list.
    public let listChanged: Bool
    public let readResource: ReadResourceRequest.Handler
    public let listResource: ListResourcesRequest.Handler
    public let listResourceTemplates: ListResourceTemplatesRequest.Handler
    public let subscribeToResource: SubscribeRequest.Handler?
    public let unsubscribeToResource: UnsubscribeRequest.Handler?
    public let complete: CompleteRequest.Handler?
    
}

public typealias InitializeRequestHook = (InitializeRequest.Params) async throws -> Void

// MARK: - ClientInfo

/// Information about the client the server is connected to.
public struct ClientInfo {
    public let info: Implementation
    public let capabilities: ClientCapabilities
}
