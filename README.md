# MCP Swift SDK!

[![Build & Deploy](https://github.com/gsabran/mcp-swift-sdk/actions/workflows/swift.yml/badge.svg)](https://github.com/gsabran/mcp-swift-sdk/actions/workflows/swift.yml)
[![Coverage Statusodecov](https://codecov.io/gh/gsabran/mcp-swift-sdk/graph/badge.svg?token=8QH4WQMLW7)](https://codecov.io/gh/gsabran/mcp-swift-sdk)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-048754?logo=buymeacoffee)](https://buymeacoffee.com/gsabran)

Swift implementation of the [Model Context Protocol](https://modelcontextprotocol.io) (MCP), providing both client and server capabilities for integrating with LLM surfaces.

## Archive notice
Given that another package was chosen by Anthropic as [their official Swift MCP SDK]([url](https://github.com/modelcontextprotocol/swift-sdk)), this package will not be maintained anymore. Particularly it will not support future changes to the MCP specs.
While I would have liked to keep maintaining it, it doesn't seem to make sense to dedicate significant time to doing so given the official recommendation.
Thanks to all those who contributed to this project, and provided feedback ❤️.

## Overview

The Model Context Protocol allows applications to provide context for LLMs in a standardized way, separating the concerns of providing context from the actual LLM interaction. This Swift SDK implements the full MCP specification for the client, making it easy to:

- Build MCP clients that can connect to any MCP server
- Use standard transports like stdio and SSE
- Handle all MCP protocol messages and lifecycle events

## Installation

 - Xcode: `File → Add Package Dependencies…` and input the package URL `https://github.com/gsabran/mcp-swift-sdk`

 - SPM-based projects:
 Add the dependency to your package:
 ```swift
 dependencies: [
   .package(url: "https://github.com/gsabran/mcp-swift-sdk", from: "0.2.0")
 ]
```
And then add the product that you need to all targets that use the dependency:
```swiftx
.product(name: "MCPServer", package: "mcp-swift-sdk"),
// and/or
.product(name: "MCPClient", package: "mcp-swift-sdk"),
```

## Quick Start

⚠️ When using stdio servers in a MacOS app, you need to disable sandboxing. This is because the app will need to run the processes for each server.

### Creating a Server
```swift
import MCPServer

let server = try await MCPServer(
  info: Implementation(name: "test-server", version: "1.0.0"),
  capabilities: .init(...),
  transport: .stdio())

// The client's roots, if available.  
let roots = await server.roots.value

// Keep the process running until the client disconnects.
try await server.waitForDisconnection()
```

#### Tool calling
The tool input schema can be generated for you (thanks [swift-json-schema](https://github.com/ajevans99/swift-json-schema)!)

```swift
import JSONSchemaBuilder

@Schemable
struct ToolInput {
  let text: String
}

let capabilities = ServerCapabilityHandlers(tools: [
  Tool(name: "repeat") { (input: ToolInput) in
    [.text(.init(text: input.text))]
  },
])
```

### Creating a Client

```swift
import MCPClient

let transport = try Transport.stdioProcess(
  serverInfo.executable,
  args: serverInfo.args,
  env: serverInfo.env)
  
let client = try await MCPClient(
  info: .init(name: "example-client", version: "1.0.0"),
  transport: transport,
  capabilities: .init(
    roots: .init(info: .init(listChanged: true), handler: listRoots)))

// List available resources
let resources = await client.resources.value

// Read a specific resource
let resourceContent = try await client.readResource(uri: "file:///example.txt")
```

## Documentation

- [Model Context Protocol documentation](https://modelcontextprotocol.io)
- [MCP Specification](https://spec.modelcontextprotocol.io)
- [Example Servers](https://github.com/modelcontextprotocol/servers)

## License

This project is licensed under the MIT License—see the [LICENSE](LICENSE) file for details.
