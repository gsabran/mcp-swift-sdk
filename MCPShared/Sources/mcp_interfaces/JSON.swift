
// MARK: - JSON

public enum JSON: Codable, Equatable, Sendable {
  case object(_ value: [String: JSON.Value])
  case array(_ value: [JSON.Value])

  // MARK: - JSONValue

  // TODO: look at instead aliasing JSONRPC.JSONValue which seems to have an error in its encoding for arrays/objects
  public enum Value: Codable, Equatable, Sendable {
    case string(_ value: String)
    case object(_ value: [String: JSON.Value])
    case array(_ value: [JSON.Value])
    case bool(_ value: Bool)
    case number(_ value: Double)
    case null
  }

}
