// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MCPExamples",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .executable(name: "ExampleSSEServer", targets: [
      "ExampleSSEServer",
    ]),
    .executable(name: "ExampleStdioServer", targets: [
      "ExampleStdioServer",
    ]),
    .executable(name: "ExampleStdioClient", targets: [
      "ExampleStdioClient",
    ]),
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor", from: "4.113.2"),
    .package(name: "MCP", path: "../"),
  ],
  targets: [
    .executableTarget(
      name: "ExampleStdioServer",
      dependencies: [
        .product(name: "MCPServer", package: "MCP"),
      ],
      path: "ExampleStdioServer/Sources"),
    .executableTarget(
      name: "ExampleSSEServer",
      dependencies: [
        .product(name: "MCPServer", package: "MCP"),
        .product(name: "Vapor", package: "vapor"),
      ],
      path: "ExampleSSEServer/Sources"),
    .executableTarget(
      name: "ExampleStdioClient",
      dependencies: [
        .product(name: "MCPClient", package: "MCP"),
      ],
      path: "ExampleStdioClient/Sources"),
  ])
