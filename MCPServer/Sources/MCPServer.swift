import Combine
import Foundation
import JSONRPC
import MCPInterface
import JSONSchema
import JSONSchemaBuilder

/// An MCP server implementation that provides methods for registering tools, resources, and prompts
/// and serves them to connected clients.
public actor MCPServer: MCPServerInterface {
    // MARK: - Private Properties
    
    private let connection: MCPServerConnectionInterface
    private var capabilities: ServerCapabilityHandlers
    private let info: Implementation
    
    private var registeredTools: [String: any CallableTool] = [:]
    
    private var registeredResources: [String: Resource] = [:]
    private var resourceCallbacks: [String: (URL) async throws -> ReadResourceResult] = [:]
    
    private var resourceTemplates: [String: ResourceTemplate] = [:]
    
    private var registeredPrompts: [String: PromptHandler] = [:]
    
    private let didDisconnectSubject = PassthroughSubject<Void, Never>()
    private var connectionCancellable: AnyCancellable?
    private var pingTask: Task<Void, Error>?
    
    // MARK: - Public Properties
    
    public private(set) var clientInfo: ClientInfo
    
    private let _roots = CurrentValueSubject<CapabilityStatus<[Root]>?, Never>(nil)
    
    public var roots: ReadOnlyCurrentValueSubject<CapabilityStatus<[Root]>, Never> {
        get async {
            await .init(_roots.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher())
        }
    }
    
    // MARK: - Initialization
    
    /// Creates an MCP server and connects to the client through the provided transport.
    /// The method completes after connecting to the client.
    /// - Parameters:
    ///   - info: Information about the server
    ///   - capabilities: The server's capabilities
    ///   - transport: The transport to use for communication
    ///   - initializeRequestHook: Optional hook called when an initialize request is received
    public init(
        info: Implementation,
        capabilities: ServerCapabilityHandlers,
        transport: Transport,
        initializeRequestHook: @escaping InitializeRequestHook = { _ in }
    ) async throws {
        let connection = try MCPServerConnection(
            info: info,
            capabilities: capabilities.capabilitiesDescription,
            transport: transport
        )
        
        try await self.init(
            info: info,
            capabilities: capabilities,
            connection: connection,
            initializeRequestHook: initializeRequestHook
        )
    }
    
    /// Creates an MCP server with a custom connection.
    /// - Parameters:
    ///   - info: Information about the server
    ///   - capabilities: The server's capabilities
    ///   - connection: The connection to use
    ///   - initializeRequestHook: Optional hook called when an initialize request is received
    init(
        info: Implementation,
        capabilities: ServerCapabilityHandlers,
        connection: MCPServerConnectionInterface,
        initializeRequestHook: @escaping InitializeRequestHook = { _ in }
    ) async throws {
        self.info = info
        self.connection = connection
        self.capabilities = capabilities
        
        // Initialize with default client info, will be updated during connection
        self.clientInfo = ClientInfo(
            info: Implementation(name: "Unknown", version: "0.0.0"),
            capabilities: ClientCapabilities()
        )
        
        // Complete client connection
        self.clientInfo = try await Self.connectToClient(
            connection: connection,
            initializeRequestHook: initializeRequestHook,
            capabilities: capabilities,
            info: info
        )
        
        // Set up listeners and health check
        await startListeningToNotifications()
        await startListeningToRequests()
        startPeriodicPing()
        
        // Update initial data
        Task { try await self.updateRoots() }
    }
    
    // MARK: - Connection Management
    
    /// Waits until the client disconnects.
    /// - Throws: Any error that occurs while waiting
    public func waitForDisconnection() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let cancellable = didDisconnectSubject
                .sink { _ in
                    continuation.resume()
                }
            
            self.connectionCancellable = cancellable
        }
    }
    
    private static func connectToClient(
        connection: MCPServerConnectionInterface,
        initializeRequestHook: @escaping InitializeRequestHook,
        capabilities: ServerCapabilityHandlers,
        info: Implementation
    ) async throws -> ClientInfo {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                for await(request, completion) in await connection.requestsToHandle {
                    if case .initialize(let params) = request {
                        do {
                            try await initializeRequestHook(params)
                            completion(.success(InitializeRequest.Result(
                                protocolVersion: MCP.protocolVersion,
                                capabilities: capabilities.capabilitiesDescription,
                                serverInfo: info
                            )))
                            
                            let clientInfo = ClientInfo(
                                info: params.clientInfo,
                                capabilities: params.capabilities
                            )
                            continuation.resume(returning: clientInfo)
                        } catch {
                            completion(.failure(.init(
                                code: JRPCErrorCodes.internalError.rawValue,
                                message: error.localizedDescription
                            )))
                            continuation.resume(throwing: error)
                        }
                        break
                    } else {
                        mcpLogger.error("Unexpected request received before initialization")
                        completion(.failure(.init(
                            code: JRPCErrorCodes.internalError.rawValue,
                            message: "Unexpected request received before initialization"
                        )))
                    }
                }
            }
        }
    }
    
    private func startPeriodicPing() {
        pingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    try await connection.ping()
                } catch {
                    handleClientDisconnection()
                    break
                }
            }
        }
    }
    
    private func handleClientDisconnection() {
        didDisconnectSubject.send(())
        pingTask?.cancel()
    }
    
    // MARK: - Tool Registration
    
    /// Registers a Schemable tool with the server.
    /// - Parameters:
    ///   - name: The name of the tool
    ///   - description: Optional description of the tool
    ///   - handler: Function to execute when the tool is called
    /// - Throws: Error if the tool cannot be registered
    public func registerTool<Input: Schemable & Decodable>(
        name: String,
        description: String? = nil,
        inputSchema: Input.Schema? = nil,
        handler: @escaping (Input) async throws -> [TextContentOrImageContentOrEmbeddedResource]
    ) async throws where Input.Schema.Output == Input {
        guard capabilities.tools != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "tools")
        }
        
        guard registeredTools[name] == nil else {
            throw MCPServerError.internalError(message: "Tool \(name) is already registered")
        }
        
        if let inputSchema = inputSchema?.schemaValue.json {
            let tool = Tool(
                name: name,
                description: description,
                inputSchema: inputSchema,
                decodeInput: { data in
                    try JSONDecoder().decode(Input.self, from: data)
                },
                call: handler
            )
            registeredTools[name] = tool
        } else {
            let tool = Tool(name: name, description: description, call: handler)
            registeredTools[name] = tool
        }
        
        if capabilities.tools?.info.listChanged == true {
            try await connection.notifyToolListChanged(nil)
        }
    }

    /// Updates the list of tools registered with the server.
    /// - Parameter tools: The new list of tools
    /// - Throws: Error if tools cannot be updated
    public func update(tools: [any CallableTool]) async throws {
        guard capabilities.tools?.info.listChanged == true else {
            throw MCPServerError.capabilityNotSupported(capability: "tools.listChanged")
        }
        
        // Create new capabilities with updated tools
        capabilities = .init(
            logging: capabilities.logging,
            prompts: capabilities.prompts,
            tools: tools.asRequestHandler(listToolChanged: true),
            resources: capabilities.resources
        )
        
        // Notify clients of the change
        try await connection.notifyToolListChanged(nil)
    }
    
    // MARK: - Resource Registration and Management
    
    /// Registers a resource with the server.
    /// - Parameters:
    ///   - name: The name of the resource
    ///   - uri: The URI of the resource
    ///   - description: Optional description of the resource
    ///   - mimeType: Optional MIME type of the resource
    ///   - readCallback: Function to execute when the resource is read
    /// - Throws: Error if the resource cannot be registered
    public func registerResource(
        name: String,
        uri: String,
        description: String? = nil,
        mimeType: String? = nil,
        readCallback: @escaping (URL) async throws -> ReadResourceResult
    ) async throws {
        guard capabilities.resources != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "resources")
        }
        
        guard registeredResources[uri] == nil else {
            throw MCPServerError.internalError(message: "Resource \(uri) is already registered")
        }
        
        let resource = Resource(uri: uri, name: name, description: description, mimeType: mimeType)
        registeredResources[uri] = resource
        resourceCallbacks[uri] = readCallback
        
        if capabilities.resources?.listChanged == true {
            try await connection.notifyResourceListChanged(nil)
        }
    }
    
    /// Registers a resource template with the server.
    /// - Parameters:
    ///   - name: The name of the template
    ///   - template: The resource template
    /// - Throws: Error if the template cannot be registered
    public func registerResourceTemplate(
        name: String,
        template: ResourceTemplate
    ) async throws {
        guard capabilities.resources != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "resources")
        }
        
        guard resourceTemplates[name] == nil else {
            throw MCPServerError.internalError(message: "Resource template \(name) is already registered")
        }
        
        resourceTemplates[name] = template
        
        if capabilities.resources?.listChanged == true {
            try await connection.notifyResourceListChanged(nil)
        }
    }
    
    // MARK: - Prompt Registration and Management
    
    /// Registers a prompt with the server using Schemable arguments.
    /// - Parameters:
    ///   - name: The name of the prompt
    ///   - description: Optional description of the prompt
    ///   - handler: Function to execute when the prompt is requested
    /// - Throws: Error if the prompt cannot be registered
    public func registerPrompt<Args: Schemable & Decodable>(
        name: String,
        description: String? = nil,
        argsSchema: Args.Schema,
        handler: @escaping (Args) async throws -> GetPromptResult
    ) async throws where Args.Schema.Output == Args {
        guard capabilities.prompts != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "prompts")
        }
        
        guard registeredPrompts[name] == nil else {
            throw MCPServerError.internalError(message: "Prompt \(name) is already registered")
        }
        
        // 引数情報を抽出
        let arguments = promptArgumentsFromSchema(from: argsSchema)
        
        // Promptオブジェクトを作成
        let prompt = Prompt(
            name: name,
            description: description,
            arguments: arguments
        )
        
        // 実行ハンドラーを保存
        let executionHandler = { (jsonArgs: JSON?) -> GetPromptResult in
            // JSONをArgsに変換
            guard let jsonArgs = jsonArgs else {
                // 引数がnilの場合、必須引数があるかチェック
                if arguments.contains(where: { $0.required == true }) {
                    throw MCPServerError.internalError(
                        message: "Required arguments missing for prompt \(name)"
                    )
                }
                
                // 引数なしで実行可能ならデフォルト値で実行
                let emptyDict: [String: Any] = [:]
                let jsonData = try JSONSerialization.data(withJSONObject: emptyDict)
                let args = try JSONDecoder().decode(Args.self, from: jsonData)
                return try await handler(args)
            }
            
            do {
                // JSON文字列を作成してデコード
                let jsonData = try JSONSerialization.data(withJSONObject: jsonArgs)
                
                // JSONデコードでArgsを生成
                let decoder = JSONDecoder()
                let args = try decoder.decode(Args.self, from: jsonData)
                
                // ハンドラーを実行
                return try await handler(args)
            } catch {
                throw MCPServerError.internalError(
                    message: "Error decoding arguments for prompt \(name): \(error.localizedDescription)"
                )
            }
        }
        
        // 完了候補コールバックを保存
        let completionCallback = { (fieldName: String, value: String) -> [String] in
            if let completionInfo = self.getCompletionInfo(
                from: argsSchema,
                fieldName: fieldName
            ) {
                return try await completionInfo(value)
            }
            return []
        }
        
        // プロンプト定義を拡張してPromptHandlerを作成
        let promptHandler = PromptHandler(
            prompt: prompt,
            execute: executionHandler,
            completionCallback: completionCallback
        )
        
        registeredPrompts[name] = promptHandler
        
        if capabilities.prompts?.info.listChanged == true {
            try await connection.notifyPromptListChanged(nil)
        }
    }
    
    private func promptArgumentsFromSchema<S: JSONSchemaComponent>(from schema: S) -> [PromptArgument] {
        var arguments: [PromptArgument] = []
        
        // スキーマ値を取得
        let schemaValue = schema.schemaValue
        
        // Propertiesを探す - JSONObjectの場合は通常ここに定義される
        if let propertiesObj = schemaValue["properties"]?.object {
            // Required属性を確認
            var requiredProps: [String] = []
            if let requiredArray = schemaValue["required"]?.array {
                requiredProps = requiredArray.compactMap { $0.string }
            }
            
            // 各プロパティをPromptArgumentに変換
            for (propName, propSchema) in propertiesObj {
                // 説明文を取得
                let description = propSchema.object?["description"]?.string
                
                // 必須かどうか
                let isRequired = requiredProps.contains(propName)
                
                let argument = PromptArgument(
                    name: propName,
                    description: description,
                    required: isRequired
                )
                
                arguments.append(argument)
            }
        }
        
        return arguments
    }
    
    private func getCompletionInfo<S: JSONSchemaComponent>(
        from schema: S,
        fieldName: String
    ) -> ((String) async throws -> [String])? {
        // Schemableな型からCompletableなフィールドを検索する
        // SchemaValue内の定義を調べてCompletableな項目を探す
        let schemaValue = schema.schemaValue
        
        // プロパティの中からフィールド名に一致するものを探す
        if let propertiesObj = schemaValue["properties"]?.object,
           let fieldSchema = propertiesObj[fieldName] {
            // Completableの特徴を探す（completionCallbackの存在など）
            if let completionMarker = fieldSchema.object?["x-completable"]?.boolean,
               completionMarker == true {
                // 単純な実装：空の候補リストを返す関数を提供
                return { _ in return [] }
            }
        }
        
        // 完了候補が見つからない場合はnilを返す
        return nil
    }

    
    // MARK: - Client Communication
    
    /// Requests sample text from the client's LLM.
    /// - Parameter params: Parameters for the LLM request
    /// - Returns: The generated message
    /// - Throws: Error if sampling fails
    public func getSampling(params: CreateSamplingMessageRequest.Params) async throws -> CreateSamplingMessageRequest.Result {
        guard clientInfo.capabilities.sampling != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "sampling")
        }
        return try await connection.requestCreateMessage(params)
    }
    
    /// Sends a log message to the client.
    /// - Parameter params: The log message parameters
    /// - Throws: Error if sending the log fails
    public func log(params: LoggingMessageNotification.Params) async throws {
        try await connection.log(params)
    }
    
    /// Notifies the client that a resource has been updated.
    /// - Parameter params: Parameters for the resource update
    /// - Throws: Error if sending the notification fails
    public func notifyResourceUpdated(params: ResourceUpdatedNotification.Params) async throws {
        guard capabilities.resources != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "resources")
        }
        try await connection.notifyResourceUpdated(params)
    }
    
    /// Notifies the client that the resource list has changed.
    /// - Parameter params: Optional parameters for the notification
    /// - Throws: Error if sending the notification fails
    public func notifyResourceListChanged(params: ResourceListChangedNotification.Params? = nil) async throws {
        guard capabilities.resources != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "resources")
        }
        try await connection.notifyResourceListChanged(params)
    }
    
    /// Notifies the client that the tool list has changed.
    /// - Parameter params: Optional parameters for the notification
    /// - Throws: Error if sending the notification fails
    public func notifyToolListChanged(params: ToolListChangedNotification.Params? = nil) async throws {
        guard capabilities.tools != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "tools")
        }
        try await connection.notifyToolListChanged(params)
    }
    
    /// Notifies the client that the prompt list has changed.
    /// - Parameter params: Optional parameters for the notification
    /// - Throws: Error if sending the notification fails
    public func notifyPromptListChanged(params: PromptListChangedNotification.Params? = nil) async throws {
        guard capabilities.prompts != nil else {
            throw MCPServerError.capabilityNotSupported(capability: "prompts")
        }
        try await connection.notifyPromptListChanged(params)
    }
    
    /// Sends a progress notification to the client.
    /// - Parameters:
    ///   - token: The progress token
    ///   - progress: The current progress value
    ///   - total: The optional total progress value
    /// - Throws: Error if sending the notification fails
    public func notifyProgress(token: ProgressToken, progress: Double, total: Double? = nil) async throws {
        let params = ProgressNotification.Params(
            progressToken: token,
            progress: progress,
            total: total
        )
        
        try await connection.notifyProgress(params)
    }
    
    // MARK: - Request Handling
    
    private func updateRoots() async throws {
        guard clientInfo.capabilities.roots != nil else {
            // Root listing not supported
            _roots.send(.notSupported)
            return
        }
        let roots = try await connection.listRoots()
        _roots.send(.supported(roots.roots))
    }
    
    private func startListeningToNotifications() async {
        let notifications = await connection.notifications
        Task { [weak self] in
            for await notification in notifications {
                switch notification {
                case .cancelled:
                    // TODO: Handle cancellation
                    break
                    
                case .progress(_):
                    // TODO: Handle progress
                    break
                    
                case .initialized:
                    // Client has confirmed initialization
                    break
                    
                case .rootsListChanged:
                    try await self?.updateRoots()
                }
            }
        }
    }
    
    private func startListeningToRequests() async {
        let requests = await connection.requestsToHandle
        Task { [weak self] in
            for await(request, completion) in requests {
                guard let self else {
                    completion(.failure(.init(
                        code: JRPCErrorCodes.internalError.rawValue,
                        message: "The server is gone"
                    )))
                    return
                }
                
                switch request {
                case .initialize:
                    mcpLogger.error("initialization received twice")
                    completion(.failure(.init(
                        code: JRPCErrorCodes.internalError.rawValue,
                        message: "initialization received twice"
                    )))
                    
                case .listPrompts(let params):
                    completion(await handle(request: params, with: capabilities.prompts?.listHandler, "Listing prompts"))
                    
                case .getPrompt(let params):
                    completion(try await handleGetPrompt(params))
                    
                case .listResources(let params):
                    completion(await handleListResources(params))
                    
                case .readResource(let params):
                    completion(try await handleReadResource(params))
                    
                case .subscribeToResource(let params):
                    completion(await handle(request: params, with: capabilities.resources?.subscribeToResource, "Subscribing to resource"))
                    
                case .unsubscribeToResource(let params):
                    completion(await handle(
                        request: params,
                        with: capabilities.resources?.unsubscribeToResource,
                        "Unsubscribing to resource"))
                    
                case .listResourceTemplates(let params):
                    completion(await handleListResourceTemplates(params))
                    
                case .listTools(let params):
                    completion(await handleListTools(params))
                    
                case .callTool(let params):
                    completion(try await handleCallTool(params))
                    
                case .complete(let params):
                    completion(try await handleComplete(params))
                    
                case .setLogLevel(let params):
                    completion(await handle(request: params, with: capabilities.logging, "Setting log level"))
                }
            }
        }
    }
    
    private func handle<Params>(
        request params: Params,
        with handler: ((Params) async throws -> some Encodable)?,
        _ requestName: String
    ) async -> AnyJRPCResponse {
        if let handler {
            do {
                let result = try await handler(params)
                return .success(result)
            } catch {
                if let err = error as? JSONRPCResponseError<JSONRPC.JSONValue> {
                    return .failure(err)
                } else {
                    return .failure(.init(
                        code: JRPCErrorCodes.internalError.rawValue,
                        message: error.localizedDescription))
                }
            }
        } else {
            return .failure(.init(
                code: JRPCErrorCodes.invalidRequest.rawValue,
                message: "\(requestName) is not supported by this server"))
        }
    }
    
    private func handleGetPrompt(_ params: GetPromptRequest.Params) async throws -> AnyJRPCResponse {
        guard let promptHandler = registeredPrompts[params.name] else {
            throw MCPServerError.promptNotFound(name: params.name)
        }
        
        do {
            let result = try await promptHandler.execute(params.arguments)
            return .success(result)
        } catch {
            return .failure(.init(
                code: JRPCErrorCodes.internalError.rawValue,
                message: error.localizedDescription))
        }
    }
    
    private func handleListResources(_ params: ListResourcesRequest.Params) async -> AnyJRPCResponse {
        var resources: [Resource] = []
        
        // Add registered static resources
        resources.append(contentsOf: registeredResources.values)
        
        // Add resources from templates
        for template in resourceTemplates.values {
            if let listCallback = template.listCallback {
                do {
                    let templateResources = try await listCallback()
                    resources.append(contentsOf: templateResources)
                } catch {
                    mcpLogger.error("Error listing resources from template: \(error.localizedDescription)")
                }
            }
        }
        
        let result = ListResourcesResult(resources: resources)
        return .success(result)
    }
    
    private func handleReadResource(_ params: ReadResourceRequest.Params) async throws -> AnyJRPCResponse {
        let uri = params.uri
        guard let url = URL(string: uri) else {
            throw MCPServerError.invalidTemplate(pattern: uri, reason: "Invalid URI")
        }
        
        // Check if it's a registered static resource
        if let callback = resourceCallbacks[uri] {
            let result = try await callback(url)
            return .success(result)
        }
        
        // Check if it matches any template
        for template in resourceTemplates.values {
            if let variables = template.match(uri) {
                let result = try await template.readCallback(url, variables)
                return .success(result)
            }
        }
        
        throw MCPServerError.resourceNotFound(uri: uri)
    }
    
    private func handleListResourceTemplates(_ params: ListResourceTemplatesRequest.Params) async -> AnyJRPCResponse {
        let templates = resourceTemplates.values.map { template in
            MCPInterface.ResourceTemplate(
                uriTemplate: template.uriTemplate.pattern,
                name: template.uriTemplate.pattern, // Use pattern as name if none provided
                description: nil,
                mimeType: nil
            )
        }
        
        let result = ListResourceTemplatesResult(resourceTemplates: templates)
        return .success(result)
    }
    
    private func handleListTools(_ params: ListToolsRequest.Params) async -> AnyJRPCResponse {
        let tools = registeredTools.values.map { callableTool in
            MCPInterface.Tool(
                name: callableTool.name,
                description: callableTool.description,
                inputSchema: callableTool.inputSchema
            )
        }
        
        let result = ListToolsResult(tools: tools)
        return .success(result)
    }
    
    private func handleCallTool(_ params: CallToolRequest.Params) async throws -> AnyJRPCResponse {
        guard let tool = registeredTools[params.name] else {
            throw MCPServerError.toolNotFound(name: params.name)
        }
        
        do {
            let content = try await tool.call(json: params.arguments)
            return .success(CallToolResult(content: content))
        } catch {
            // Return error as part of the result, not as a JRPC error
            return .success(CallToolResult(
                content: [.text(TextContent(text: error.localizedDescription))],
                isError: true
            ))
        }
    }
    
    private func handleComplete(_ params: CompleteRequest.Params) async throws -> AnyJRPCResponse {
        switch params.ref {
        case .prompt(let promptRef):
            return try await handlePromptCompletion(promptRef, argument: params.argument)
            
        case .resource(let resourceRef):
            return try await handleResourceCompletion(resourceRef, argument: params.argument)
        }
    }
    
    private func handlePromptCompletion(_ ref: PromptReference, argument: CompleteRequest.Params.Argument) async throws -> AnyJRPCResponse {
        guard let promptHandler = registeredPrompts[ref.name] else {
            throw MCPServerError.promptNotFound(name: ref.name)
        }
        
        if let callback = promptHandler.completionCallback(for: argument.name) {
            let values = try await callback(argument.value)
            return .success(CompleteResult(
                completion: .init(
                    values: Array(values.prefix(100)),
                    total: values.count,
                    hasMore: values.count > 100
                )
            ))
        }
        
        // Return empty completion if no callbacks found
        return .success(CompleteResult(completion: .init(values: [])))
    }
    
    private func handleResourceCompletion(_ ref: ResourceReference, argument: CompleteRequest.Params.Argument) async throws -> AnyJRPCResponse {
        // Find a template that matches the URI pattern
        for template in resourceTemplates.values {
            if template.uriTemplate.pattern == ref.uri {
                // Try to get completions for the specified variable
                if let callback = template.completeCallbacks[argument.name] {
                    let values = try await callback(argument.value)
                    return .success(CompleteResult(
                        completion: .init(
                            values: Array(values.prefix(100)),
                            total: values.count,
                            hasMore: values.count > 100
                        )
                    ))
                }
            }
        }
        
        // Return empty completion if no matching template found or no completions available
        return .success(CompleteResult(completion: .init(values: [])))
    }
}
