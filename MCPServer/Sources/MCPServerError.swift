import Foundation
import MCPInterface

/// Errors that can occur during MCP server operations
public enum MCPServerError: Error {
    /// Tool not found
    case toolNotFound(name: String)
    
    /// Resource not found
    case resourceNotFound(uri: String)
    
    /// Prompt not found
    case promptNotFound(name: String)
    
    /// Invalid template
    case invalidTemplate(pattern: String, reason: String)
    
    /// The requested capability is not supported
    case capabilityNotSupported(capability: String)
    
    /// Client disconnected
    case clientDisconnected
    
    /// Internal error
    case internalError(message: String)
    
    /// An error that occurred while calling a tool
    case toolCallError(_ errors: [Error])
    
    /// Decoding error with detailed input and schema information
    case decodingError(input: Data, schema: JSON)
    
    /// Invalid input for a tool
    case invalidToolInput(toolName: String, error: Error)
    
    /// Invalid arguments for a prompt
    case invalidPromptArguments(promptName: String, error: Error)
}

extension MCPServerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .resourceNotFound(let uri):
            return "Resource not found: \(uri)"
        case .promptNotFound(let name):
            return "Prompt not found: \(name)"
        case .invalidTemplate(let pattern, let reason):
            return "Invalid URI template pattern '\(pattern)': \(reason)"
        case .capabilityNotSupported(let capability):
            return "The requested capability '\(capability)' is not supported by the client"
        case .clientDisconnected:
            return "Client has disconnected"
        case .internalError(let message):
            return "Internal server error: \(message)"
        case .invalidToolInput(let toolName, let error):
            return "Invalid input for tool '\(toolName)': \(error.localizedDescription)"
        case .invalidPromptArguments(let promptName, let error):
            return "Invalid arguments for prompt '\(promptName)': \(error.localizedDescription)"            
        case .toolCallError(let errors):
            return "Tool call error:\n\(errors.map { $0.localizedDescription }.joined(separator: "\n"))"
        case .decodingError(let input, let schema):
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let schemaDesc: Any = (try? encoder.encode(schema)).map { String(data: $0, encoding: .utf8) ?? "corrupted data" } ?? schema
            return "Decoding error. Received:\n\(String(data: input, encoding: .utf8) ?? "corrupted data")\nExpected schema:\n\(schemaDesc)"
        }
    }
}
