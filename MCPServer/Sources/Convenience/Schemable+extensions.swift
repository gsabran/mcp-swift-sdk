import Foundation
import JSONRPC
import JSONSchema
import JSONSchemaBuilder
import MCPInterface

// MARK: - CallableTool

// Allows to use @Schemable from `JSONSchemaBuilder` to define the input for tools as:
//
// @Schemable
// struct RepeatToolInput {
//  let text: String
// }
//
// print(RepeatToolInput.schema.schemaValue)
// -> {"required":["text"],"properties":{"text":{"type":"string"}},"type":"object"}

/// Definition for a tool the client can call.
public protocol CallableTool {
  associatedtype Input
  /// A JSON Schema object defining the expected parameters for the tool.
  var inputSchema: JSON { get }
  /// The name of the tool.
  var name: String { get }
  /// A human-readable description of the tool.
  var description: String? { get }

  func decodeInput(_ input: JSON?) throws -> Input

  func call(_ input: Input) async throws -> [TextContentOrImageContentOrEmbeddedResource]
}

// MARK: - Tool

public struct Tool<Input>: CallableTool {

  public init(
    name: String,
    description: String? = nil,
    inputSchema: JSON,
    decodeInput: @escaping (Data) throws -> Input,
    call: @escaping (Input) async throws -> [TextContentOrImageContentOrEmbeddedResource])
  {
    self.name = name
    self.description = description
    self.inputSchema = inputSchema
    _decodeInput = decodeInput
    _call = call
  }

  public let name: String

  public let description: String?

  public let inputSchema: JSON

  public func call(_ input: Input) async throws -> [TextContentOrImageContentOrEmbeddedResource] {
    try await _call(input)
  }

  public func decodeInput(_ input: MCPInterface.JSON?) throws -> Input {
    let data = try JSONEncoder().encode(input)
    return try _decodeInput(data)
  }

  private let _call: (Input) async throws -> [TextContentOrImageContentOrEmbeddedResource]

  private let _decodeInput: (Data) throws -> Input
}

extension Tool where Input: Schemable {
  public init(
    name: String,
    description: String? = nil,
    call: @escaping (Input) async throws -> [TextContentOrImageContentOrEmbeddedResource]) where Input.Schema.Output == Input
  {
    self.init(
      name: name,
      description: description,
      inputSchema: Input.schema.schemaValue.json,
      decodeInput: { data in
        let json = try JSONDecoder().decode(JSONSchema_JSONValue.self, from: data)

        switch Input.schema.parse(json) {
        case .valid(let value):
          return value
        case .invalid:
          throw MCPServerError.decodingError(input: data, schema: Input.schema.schemaValue.json)
        }
      },
      call: call)
  }
}

extension CallableTool {
  public func call(json: JSON?) async throws -> [TextContentOrImageContentOrEmbeddedResource] {
    let input: Input = try decodeInput(json)
    return try await call(input)
  }
}

extension Array where Element == any CallableTool {
  func asRequestHandler(listToolChanged: Bool)
    -> ListedCapabilityHandler<ListChangedCapability, CallToolRequest.Handler, ListToolsRequest.Handler>
  {
    let toolsByName = [String: any CallableTool](uniqueKeysWithValues: map { ($0.name, $0) })

    return .init(
      info: .init(listChanged: listToolChanged),
      handler: { request in
        let name = request.name
        guard let tool = toolsByName[name] else {
          throw JSONRPCResponseError<JSONRPC.JSONValue>(
            code: JRPCErrorCodes.invalidParams.rawValue,
            message: "Unknown tool: \(name)")
        }
        let arguments = request.arguments
        do {
          let content = try await tool.call(json: arguments)
          return CallToolResult(content: content)
        } catch {
          return CallToolResult(content: [.text(.init(text: error.localizedDescription))], isError: true)
        }
      },
      listHandler: { _ in
        ListToolsResult(tools: self.map { tool in MCPInterface.Tool(
          name: tool.name,
          description: tool.description,
          inputSchema: tool.inputSchema) })
      })
  }
}

/// Convert between the JSON representation from `JSONSchema` and ours
extension [KeywordIdentifier: JSONSchema_JSONValue] {
  fileprivate var json: JSON {
    .object(mapValues { $0.value })
  }
}

extension JSONSchema_JSONValue {
  fileprivate var value: JSON.Value {
    switch self {
    case .null:
      .null
    case .boolean(let value):
      .bool(value)
    case .number(let value):
      .number(value)
    case .string(let value):
      .string(value)
    case .array(let value):
      .array(value.map(\.value))
    case .object(let value):
      .object(value.mapValues { $0.value })
    case .integer(let value):
      .number(Double(value))
    }
  }
}

/*
'Input.schema.schemaValue.json' would not be compiled because Input.schema.schemaValue returns a SchemaValue object, but there was no direct way to convert this to the custom JSON type. The existing extensions only handled:
    [KeywordIdentifier: JSONSchema_JSONValue] → JSON
    JSONSchema_JSONValue → JSON.Value
 But there was no extension for:
    SchemaValue → JSON
*/
extension SchemaValue {
  var json: JSON {
    switch self {
    case .boolean(let value):
      // For boolean schema values, create a simple JSON object
      return .object(["type": .string("boolean"), "default": .bool(value)])
    case .object(let dict):
      // Use the existing extension on [KeywordIdentifier: JSONSchema_JSONValue]
      return dict.json
    }
  }
}
