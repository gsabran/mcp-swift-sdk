import JSONRPC
import MCPShared
import MemberwiseInit

// MARK: - MCPClientInterface

public protocol MCPClientInterface { }

public typealias Transport = DataChannel

// MARK: - ClientCapabilityHandlers

/// Describes the supported capabilities of an MCP client, and how to handle each of the supported ones.
///
/// Note: This is similar to `ClientCapabilities`, with the addition of the handler function.
@MemberwiseInit(.public, _optionalsDefaultNil: true)
public struct ClientCapabilityHandlers {
  public let roots: CapabilityHandler<ListChangedCapability, ListRootsRequestHandler>?
  public let sampling: CapabilityHandler<EmptyObject, SamplingRequestHandler>?
  // TODO: add experimental
}

// MARK: - MCPClientError

public enum MCPClientError: Error {
  case alreadyConnectedOrConnecting
  case notConnected
  case notSupported
  case versionMismatch
  case toolCallError(executionErrors: [CallToolResult.ExecutionError])
}

// MARK: - ServerCapabilityState

public enum ServerCapabilityState<Capability: Equatable>: Equatable {
  case supported(_ capability: Capability)
  case notSupported
}

extension ServerCapabilityState {
  public var capability: Capability? {
    switch self {
    case .supported(let capability):
      return capability
    case .notSupported:
      return nil
    }
  }

  public func get() throws -> Capability {
    switch self {
    case .supported(let capability):
      return capability
    case .notSupported:
      throw MCPClientError.notSupported
    }
  }
}
