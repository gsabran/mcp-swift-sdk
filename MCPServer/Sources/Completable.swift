import Foundation
import JSONSchema
import JSONSchemaBuilder


@propertyWrapper
public struct Completable<Value: Schemable> {
    public let wrappedValue: Value
    private let completeCallback: (String?) async throws -> [String]
    
    public var projectedValue: Completable<Value> { self }
    
    public init(wrappedValue: Value, _ completeCallback: @escaping (String?) async throws -> [String]) {
        self.wrappedValue = wrappedValue
        self.completeCallback = completeCallback
    }
    
    public var completions: (String?) async throws -> [String] {
        return completeCallback
    }
}
