
import AppKit
import JSONSchemaBuilder
import MCPServer

// MARK: - EmptyInput

@Schemable
struct EmptyInput { }

let testTool = Tool(name: "test") { (_: EmptyInput) async throws in
  []
}
