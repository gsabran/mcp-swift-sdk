import Foundation
import MCPInterface

/// A template for resources with variable URI patterns
public struct ResourceTemplate {
    /// The name of the template
    public let name: String
    
    /// An optional description
    public let description: String?
    
    /// The MIME type of resources matching this template
    public let mimeType: String?
    
    /// The URI template
    public let uriTemplate: URITemplate
    
    /// Function to read a resource matching this template
    public let readCallback: (URL, [String: String]) async throws -> ReadResourceResult
    
    /// Optional function to list all resources matching this template
    public let listCallback: (() async throws -> [Resource])?
    
    /// Optional callbacks for completing template variables
    public let completeCallbacks: [String: (String) async throws -> [String]]
    
    /// Initialize a new resource template
    /// - Parameters:
    ///   - name: The name of the template
    ///   - uriTemplate: The URI template
    ///   - description: Optional description
    ///   - mimeType: Optional MIME type
    ///   - readCallback: Function to read a resource matching this template
    ///   - listCallback: Optional function to list all resources matching this template
    ///   - completeCallbacks: Optional callbacks for completing template variables
    public init(
        name: String,
        uriTemplate: URITemplate,
        description: String? = nil,
        mimeType: String? = nil,
        readCallback: @escaping (URL, [String: String]) async throws -> ReadResourceResult,
        listCallback: (() async throws -> [Resource])? = nil,
        completeCallbacks: [String: (String) async throws -> [String]] = [:]
    ) {
        self.name = name
        self.uriTemplate = uriTemplate
        self.description = description
        self.mimeType = mimeType
        self.readCallback = readCallback
        self.listCallback = listCallback
        self.completeCallbacks = completeCallbacks
    }
    
    /// Check if a URI matches this template
    /// - Parameter uri: The URI to check
    /// - Returns: A dictionary of variable values if matched, nil otherwise
    public func match(_ uri: String) -> [String: String]? {
        return uriTemplate.match(uri)
    }
    
    /// Get the completion callback for a variable
    /// - Parameter variableName: The variable name
    /// - Returns: The completion callback if available
    public func completionCallback(for variableName: String) -> ((String) async throws -> [String])? {
        return completeCallbacks[variableName]
    }
}

/// Helper struct for resource handlers
public struct ResourceHandler {
    /// The resource definition
    public let resource: Resource
    
    /// The callback to retrieve the resource content
    public let callback: (URL) async throws -> ReadResourceResult
    
    /// Initialize a new resource handler
    /// - Parameters:
    ///   - resource: The resource definition
    ///   - callback: The callback to retrieve the resource content
    public init(resource: Resource, callback: @escaping (URL) async throws -> ReadResourceResult) {
        self.resource = resource
        self.callback = callback
    }
}
