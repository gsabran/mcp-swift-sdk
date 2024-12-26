import JSONRPC
import MemberwiseInit

public typealias Transport = DataChannel

// MARK: - CapabilityHandler

/// Describes a capability of a client/server (see `ClientCapabilities` and `ServerCapabilities`), as well as how it is handled.
@MemberwiseInit(.public, _optionalsDefaultNil: true)
public struct CapabilityHandler<Info, Handler> {
  public let info: Info
  public let handler: Handler
}

extension CapabilityHandler where Info == EmptyObject {
  public init(handler: Handler) {
    self.init(info: .init(), handler: handler)
  }
}
