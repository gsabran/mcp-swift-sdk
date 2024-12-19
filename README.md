# MCP Swift SDK (Client only for now)!

[![Build & Deploy](https://github.com/gsabran/mcp-swift-sdk/actions/workflows/swift.yml/badge.svg)](https://github.com/gsabran/mcp-swift-sdk/actions/workflows/swift.yml)
[![Coverage Statusodecov](https://codecov.io/gh/gsabran/mcp-swift-sdk/graph/badge.svg?token=8QH4WQMLW7)](https://codecov.io/gh/gsabran/mcp-swift-sdk)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-048754?logo=buymeacoffee)](https://buymeacoffee.com/gsabran)

Swift implementation of the [Model Context Protocol](https://modelcontextprotocol.io) (MCP), providing both client and server capabilities for integrating with LLM surfaces.

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
   .package(url: "https://github.com/gsabran/mcp-swift-sdk", from: "0.0.1")
 ]
```
And then add the product to all targets that use the dependency:
```swift
.product(name: "MCPClient", package: "mcp-swift-sdk"),
```

## Quick Start

### Creating a Client

```swift
import MCPClient
import JSONRPC

let transport = try DataChannel.stdioProcess(
  serverInfo.executable,
  args: serverInfo.args,
  env: serverInfo.env)
  
let client = try await MCPClient(
  info: .init(name: "example-client", version: "1.0.0"),
  capabilities: .init(),
  transport: transport)

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
