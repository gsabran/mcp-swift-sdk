import Foundation

// MARK: AnyMeta + Codable
extension AnyMeta {

  public init(from decoder: Decoder) throws {
    value = try JSON(from: decoder)
  }

  public init(_ value: JSON) {
    self.value = value
  }

  public func encode(to encoder: Encoder) throws {
    try value.encode(to: encoder)
  }

}

// MARK: StringOrNumber + Codable
extension StringOrNumber {

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let number = try? container.decode(Double.self) {
      self = .number(number)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid progress token")
    }
  }

  public var string: String? {
    guard case .string(let value) = self else {
      return nil
    }
    return value
  }

  public var number: Double? {
    guard case .number(let value) = self else {
      return nil
    }
    return value
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .number(let number):
      try container.encode(number)
    case .string(let string):
      try container.encode(string)
    }
  }

}

// MARK: AnyParams + Codable

extension AnyParams {

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    var values: [String: JSON.Value] = [:]
    for key in container.allKeys.filter({ $0 != ._meta }) {
      if let value = try? container.decode(JSON.Value.self, forKey: key) {
        values[key] = value
      }
    }
    _meta = try container.decodeIfPresent(AnyMeta.self, forKey: ._meta)
    if values.isEmpty {
      value = nil
    } else {
      value = values
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    if let _meta {
      try container.encode(_meta, forKey: "_meta")
    }
    if let value {
      try value.encode(to: encoder)
    }
  }

}

// MARK: AnyParamsWithProgressToken + Codable

extension AnyParamsWithProgressToken {

  public init(from decoder: Decoder) throws {
    let hash = try JSON(from: decoder)
    switch hash {
    case .array:
      throw try DecodingError.dataCorruptedError(in: decoder.unkeyedContainer(), debugDescription: "Unexpected array")
    case .object(var object):
      if case .object(let metaHash) = object["_meta"] {
        let data = try JSONEncoder().encode(metaHash)
        _meta = try JSONDecoder().decode(MetaProgress.self, from: data)
      } else {
        _meta = nil
      }
      object.removeValue(forKey: "_meta")
      if object.isEmpty {
        value = nil
      } else {
        let data = try JSONEncoder().encode(object)
        let json = try JSONDecoder().decode(JSON.self, from: data)
        switch json {
        case .array:
          throw try DecodingError.dataCorruptedError(in: decoder.unkeyedContainer(), debugDescription: "Unexpected array")
        case .object(let val):
          value = val
        }
      }
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    if let _meta {
      try container.encode(_meta, forKey: "_meta")
    }
    if let value {
      try value.encode(to: encoder)
    }
  }
}

// MARK: TextContentOrImageContentOrEmbeddedResource + Codable
extension TextContentOrImageContentOrEmbeddedResource {

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let type = try container.decode(String.self, forKey: "type")
    switch type {
    case "text":
      self = try .text(.init(from: decoder))
    case "image":
      self = try .image(.init(from: decoder))
    case "resource":
      self = try .embeddedResource(.init(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(forKey: "type", in: container, debugDescription: "Invalid content. Got type \(type)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .text(let value):
      try value.encode(to: encoder)
    case .image(let value):
      try value.encode(to: encoder)
    case .embeddedResource(let value):
      try value.encode(to: encoder)
    }
  }
}

extension TextContentOrImageContentOrEmbeddedResource {
  public var text: TextContent? {
    guard case .text(let value) = self else {
      return nil
    }
    return value
  }

  public var image: ImageContent? {
    guard case .image(let value) = self else {
      return nil
    }
    return value
  }

  public var embeddedResource: EmbeddedResource? {
    guard case .embeddedResource(let value) = self else {
      return nil
    }
    return value
  }
}

// MARK: TextOrImageContent + Codable
extension TextOrImageContent {

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let type = try container.decode(String.self, forKey: "type")
    switch type {
    case "text":
      self = try .text(.init(from: decoder))
    case "image":
      self = try .image(.init(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(forKey: "type", in: container, debugDescription: "Invalid content. Got type \(type)")
    }
  }

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .text(let value):
      try value.encode(to: encoder)
    case .image(let value):
      try value.encode(to: encoder)
    }
  }
}

extension TextOrImageContent {
  public var text: TextContent? {
    guard case .text(let value) = self else {
      return nil
    }
    return value
  }

  public var image: ImageContent? {
    guard case .image(let value) = self else {
      return nil
    }
    return value
  }
}

// MARK: TextOrBlobResourceContents + Codable
extension TextOrBlobResourceContents {

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    if container.contains("text") {
      // It is not ideal to rely on the presence/absence of a key to know which type to decode.
      // But the specs doesn't specifies the type through a value that would be given to a well known key.
      self = try .text(.init(from: decoder))
    } else {
      self = try .blob(.init(from: decoder))
    }
  }

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .text(let value):
      try value.encode(to: encoder)
    case .blob(let value):
      try value.encode(to: encoder)
    }
  }
}

extension TextOrBlobResourceContents {
  public var text: TextResourceContents? {
    guard case .text(let value) = self else {
      return nil
    }
    return value
  }

  public var blob: BlobResourceContents? {
    guard case .blob(let value) = self else {
      return nil
    }
    return value
  }
}

// MARK: PromptOrResourceReference + Codable
extension PromptOrResourceReference {

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let type = try container.decode(String.self, forKey: "type")
    if type == "ref/prompt" {
      self = try .prompt(.init(from: decoder))
    } else {
      self = try .resource(.init(from: decoder))
    }
  }

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .prompt(let value):
      try value.encode(to: encoder)
    case .resource(let value):
      try value.encode(to: encoder)
    }
  }

}

extension PromptOrResourceReference {
  public var prompt: PromptReference? {
    guard case .prompt(let value) = self else {
      return nil
    }
    return value
  }

  public var resource: ResourceReference? {
    guard case .resource(let value) = self else {
      return nil
    }
    return value
  }
}

// MARK: ClientRequest + Decodable
extension ClientRequest {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let method = try container.decode(String.self, forKey: "method")

    switch method {
    case Requests.initialize:
      self = try .initialize(InitializeRequest(from: decoder).params)
    case Requests.listPrompts:
      self = try .listPrompts(ListPromptsRequest(from: decoder).params)
    case Requests.getPrompt:
      self = try .getPrompt(GetPromptRequest(from: decoder).params)
    case Requests.listResources:
      self = try .listResources(ListResourcesRequest(from: decoder).params)
    case Requests.readResource:
      self = try .readResource(ReadResourceRequest(from: decoder).params)
    case Requests.subscribeToResource:
      self = try .subscribeToResource(SubscribeRequest(from: decoder).params)
    case Requests.unsubscribeToResource:
      self = try .unsubscribeToResource(UnsubscribeRequest(from: decoder).params)
    case Requests.listResourceTemplates:
      self = try .listResourceTemplates(ListResourceTemplatesRequest(from: decoder).params)
    case Requests.listTools:
      self = try .listTools(ListToolsRequest(from: decoder).params)
    case Requests.callTool:
      self = try .callTool(CallToolRequest(from: decoder).params)
    case Requests.autocomplete:
      self = try .complete(CompleteRequest(from: decoder).params)
    case Requests.setLoggingLevel:
      self = try .setLogLevel(SetLevelRequest(from: decoder).params)
    default:
      throw DecodingError.dataCorruptedError(
        forKey: "method",
        in: container,
        debugDescription: "Invalid client request. Got method \(method)")
    }
  }
}

// MARK: ClientNotification + Decodable

extension ClientNotification {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let method = try container.decode(String.self, forKey: "method")
    switch method {
    case Notifications.cancelled:
      self = try .cancelled(CancelledNotification(from: decoder).params)
    case Notifications.progress:
      self = try .progress(ProgressNotification(from: decoder).params)
    case Notifications.initialized:
      self = try .initialized(InitializedNotification(from: decoder).params ?? .init())
    case Notifications.rootsListChanged:
      self = try .rootsListChanged(RootsListChangedNotification(from: decoder).params ?? .init())
    default:
      throw DecodingError.dataCorruptedError(
        forKey: "method",
        in: container,
        debugDescription: "Invalid client notification. Got method \(method)")
    }
  }
}

// MARK: ServerRequest + Decodable
extension ServerRequest {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let method = try container.decode(String.self, forKey: "method")
    switch method {
    case Requests.createMessage:
      self = try .createMessage(CreateSamplingMessageRequest(from: decoder).params)
    case Requests.listRoots:
      self = try .listRoots(ListRootsRequest(from: decoder).params)
    default:
      throw DecodingError.dataCorruptedError(
        forKey: "method",
        in: container,
        debugDescription: "Invalid server request. Got method \(method)")
    }
  }
}

// MARK: ServerNotification + Decodable
extension ServerNotification {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    let method = try container.decode(String.self, forKey: "method")
    switch method {
    case Notifications.cancelled:
      self = try .cancelled(CancelledNotification(from: decoder).params)
    case Notifications.progress:
      self = try .progress(ProgressNotification(from: decoder).params)
    case Notifications.loggingMessage:
      self = try .loggingMessage(LoggingMessageNotification(from: decoder).params)
    case Notifications.resourceUpdated:
      self = try .resourceUpdated(ResourceUpdatedNotification(from: decoder).params)
    case Notifications.resourceListChanged:
      self = try .resourceListChanged(ResourceListChangedNotification(from: decoder).params ?? .init())
    case Notifications.toolListChanged:
      self = try .toolListChanged(ToolListChangedNotification(from: decoder).params ?? .init())
    case Notifications.promptListChanged:
      self = try .promptListChanged(PromptListChangedNotification(from: decoder).params ?? .init())
    default:
      throw DecodingError.dataCorruptedError(
        forKey: "method",
        in: container,
        debugDescription: "Invalid server notification. Got method \(method)")
    }
  }
}

// MARK: - JRPCMessageCodingKeys

/// Some boilerplate to remove compiler warnings due to some properties (method, type) having
/// a known value that is not decoded, but should be encoded.
public enum JRPCMessageCodingKeys: String, CodingKey {
  case method
  case params
}

// MARK: - CancelledNotification.CodingKeys

extension CancelledNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - InitializedNotification.CodingKeys

extension InitializedNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - PingRequest.CodingKeys

extension PingRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ProgressNotification.CodingKeys

extension ProgressNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ResourceListChangedNotification.CodingKeys

extension ResourceListChangedNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ResourceUpdatedNotification.CodingKeys

extension ResourceUpdatedNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - PromptListChangedNotification.CodingKeys

extension PromptListChangedNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ToolListChangedNotification.CodingKeys

extension ToolListChangedNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - LoggingMessageNotification.CodingKeys

extension LoggingMessageNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - CreateSamplingMessageRequest.CodingKeys

extension CreateSamplingMessageRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ListRootsRequest.CodingKeys

extension ListRootsRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - RootsListChangedNotification.CodingKeys

extension RootsListChangedNotification {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - InitializeRequest.CodingKeys

extension InitializeRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ListResourcesRequest.CodingKeys

extension ListResourcesRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ListResourceTemplatesRequest.CodingKeys

extension ListResourceTemplatesRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ReadResourceRequest.CodingKeys

extension ReadResourceRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - SubscribeRequest.CodingKeys

extension SubscribeRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - UnsubscribeRequest.CodingKeys

extension UnsubscribeRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ListPromptsRequest.CodingKeys

extension ListPromptsRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - GetPromptRequest.CodingKeys

extension GetPromptRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - ListToolsRequest.CodingKeys

extension ListToolsRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - CallToolRequest.CodingKeys

extension CallToolRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - SetLevelRequest.CodingKeys

extension SetLevelRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

// MARK: - CompleteRequest.CodingKeys

extension CompleteRequest {
  public typealias CodingKeys = JRPCMessageCodingKeys
}

extension TextContent {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    annotations = try container.decodeIfPresent(Annotations.self, forKey: "annotations")
    text = try container.decode(String.self, forKey: "text")
  }
}

extension ImageContent {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    annotations = try container.decodeIfPresent(Annotations.self, forKey: "annotations")
    data = try container.decode(String.self, forKey: "data")
    mimeType = try container.decode(String.self, forKey: "mimeType")
  }
}

extension EmbeddedResource {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    annotations = try container.decodeIfPresent(Annotations.self, forKey: "annotations")
    resource = try container.decode(TextOrBlobResourceContents.self, forKey: "resource")
  }
}

extension ResourceReference {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    uri = try container.decode(String.self, forKey: "uri")
  }
}

extension PromptReference {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    name = try container.decode(String.self, forKey: "name")
  }
}

// MARK: - CallToolResult.ExecutionError + LocalizedError

extension CallToolResult.ExecutionError: LocalizedError {

  public var errorDescription: String? {
    text
  }
}

// MARK: - JRPCError + LocalizedError

extension JRPCError: LocalizedError {

  public var errorDescription: String? {
    if let data {
      do {
        if let dataStr = try String(data: JSONEncoder().encode(data), encoding: .utf8) {
          return "JRPC error \(code): \(message)\n\(dataStr)"
        }
      } catch {
        // will fall back to the default error description
      }
    }
    return "JRPC error \(code): \(message)"
  }
}
