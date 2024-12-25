
import Foundation

extension JSON {

  // MARK: Lifecycle

  public init(from decoder: Decoder) throws {
    do {
      // Object
      let container = try decoder.container(keyedBy: String.self)
      let keys = container.allKeys
      let object = keys.reduce(into: [String: JSON.Value]()) { result, key in
        if let value = try? container.decode(JSON.Value.self, forKey: key) {
          result[key] = value
        }
      }
      self = .object(object)
    } catch {
      // Array
      var container = try decoder.unkeyedContainer()
      var array: [JSON.Value] = []
      while !container.isAtEnd {
        if let value = try? container.decode(JSON.Value.self) {
          array.append(value)
        }
      }
      self = .array(array)
    }
  }

  // MARK: Public

  public static func ==(lhs: JSON, rhs: JSON) -> Bool {
    lhs.asValue == rhs.asValue
  }

  public func encode(to encoder: any Encoder) throws {
    try asValue.encode(to: encoder)
  }

  // MARK: Internal

  var asValue: JSON.Value {
    switch self {
    case .object(let value):
      .object(value)
    case .array(let value):
      .array(value)
    }
  }

}

extension JSON.Value {

  // MARK: Lifecycle

  public init(from decoder: Decoder) throws {
    do {
      // Single values
      let container = try decoder.singleValueContainer()
      if container.decodeNil() {
        self = .null
      } else if let value = try? container.decode(String.self) {
        self = .string(value)
      } else if let value = try? container.decode(Bool.self) {
        self = .bool(value)
      } else if let value = try? container.decode(Double.self) {
        self = .number(value)
      } else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON")
      }
    } catch {
      // Object
      do {
        let container = try decoder.container(keyedBy: String.self)
        let keys = container.allKeys
        let object = keys.reduce(into: [String: JSON.Value]()) { result, key in
          if let value = try? container.decode(JSON.Value.self, forKey: key) {
            result[key] = value
          }
        }
        self = .object(object)
      } catch {
        // Array
        var container = try decoder.unkeyedContainer()
        var array: [JSON.Value] = []
        while !container.isAtEnd {
          if let value = try? container.decode(JSON.Value.self) {
            array.append(value)
          }
        }
        self = .array(array)
      }
    }
  }

  // MARK: Public

  public static func ==(lhs: JSON.Value, rhs: JSON.Value) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null):
      true
    case (.string(let lhs), .string(let rhs)):
      lhs == rhs
    case (.bool(let lhs), .bool(let rhs)):
      lhs == rhs
    case (.number(let lhs), .number(let rhs)):
      lhs == rhs
    case (.object(let lhs), .object(let rhs)):
      lhs == rhs
    case (.array(let lhs), .array(let rhs)):
      lhs == rhs
    default:
      false
    }
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()

    case .string(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .bool(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .number(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .object(let value):
      var container = encoder.container(keyedBy: String.self)
      for (key, value) in value {
        try container.encode(value, forKey: key)
      }

    case .array(let value):
      var container = encoder.unkeyedContainer()
      for value in value {
        try container.encode(value)
      }
    }
  }

}

extension JSON {
  public var asAny: Any {
    switch self {
    case .object(let value):
      value.keys.reduce(into: [String: Any]()) { result, key in
        result[key] = value[key]?.asAny
      }

    case .array(let value):
      value.map { $0.asAny }
    }
  }

  public func asJSONData(options: JSONSerialization.WritingOptions = []) throws -> Data {
    try JSONSerialization.data(withJSONObject: asAny, options: options)
  }

  public func asJSONString(options: JSONSerialization.WritingOptions = []) throws -> String {
    guard let string = String(data: try asJSONData(options: options), encoding: .utf8) else {
      throw NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON to string"])
    }
    return string
  }
}

extension JSON.Value {
  public var asAny: Any {
    switch self {
    case .string(let value):
      value

    case .object(let value):
      value.keys.reduce(into: [String: Any]()) { result, key in
        result[key] = value[key]?.asAny
      }

    case .array(let value):
      value.map { $0.asAny }

    case .bool(let value):
      value

    case .number(let value):
      value

    case .null:
      NSNull()
    }
  }
}

// MARK: - String + CodingKey

extension String: @retroactive CodingKey {

  // MARK: Lifecycle

  public init?(stringValue: String) {
    self = stringValue
  }

  public init?(intValue: Int) {
    self = "\(intValue)"
  }

  // MARK: Public

  public var stringValue: String { self }
  public var intValue: Int? { Int(self) }
}
