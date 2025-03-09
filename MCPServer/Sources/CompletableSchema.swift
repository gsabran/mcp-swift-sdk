import Foundation
import JSONSchema
import JSONSchemaBuilder

extension JSONComponents {
    public struct CompletableSchema<Upstream: JSONSchemaComponent>: JSONSchemaComponent {
        public var schemaValue: [KeywordIdentifier: JSONValue] {
            get {
                var schema = upstream.schemaValue
                schema["x-completable"] = .boolean(true)
                return schema
            }
            set { upstream.schemaValue = newValue }
        }
        
        var upstream: Upstream
        let completeCallback: @Sendable (String?) async throws -> [String]
        
        public init(upstream: Upstream, completeCallback: @escaping @Sendable (String?) async throws -> [String]) {
            self.upstream = upstream
            self.completeCallback = completeCallback
        }
        
        public func parse(_ value: JSONValue) -> Parsed<Upstream.Output, ParseIssue> {
            return upstream.parse(value)
        }
        
        public func complete(_ value: String?) async throws -> [String] {
            return try await completeCallback(value)
        }
    }
}

extension JSONSchemaComponent {
    public func completable(
        _ completeCallback: @Sendable @escaping (String?) async throws -> [String]
    )
    -> JSONComponents.CompletableSchema<Self> {
        return .init(upstream: self, completeCallback: completeCallback)
    }
}
