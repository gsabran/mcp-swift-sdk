// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MCP",
  platforms: [
    .macOS(.v14),
    .iOS(.v17),
  ],
  products: [
    .library(
      name: "MCPClient",
      targets: [
        "MCPClient",
      ]),
    .library(
      name: "MCPServer",
      targets: [
        "MCPServer",
      ]),
  ],
  dependencies: [
    .package(url: "https://github.com/gsabran/JSONRPC", from: "0.9.1"),
    .package(url: "https://github.com/ajevans99/swift-json-schema", from: "0.3.1"),
  ],
  targets: [
    .target(
      name: "MCPClient",
      dependencies: [
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "MCPInterface"),
      ],
      path: "MCPClient/Sources"),
    .target(
      name: "MCPServer",
      dependencies: [
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "MCPInterface"),
        .product(name: "JSONSchema", package: "swift-json-schema"),
        .product(name: "JSONSchemaBuilder", package: "swift-json-schema"),
      ],
      path: "MCPServer/Sources"),
    .target(
      name: "MCPInterface",
      dependencies: [
        .product(name: "JSONRPC", package: "JSONRPC"),
      ],
      path: "MCPInterface/Sources"),

    // Tests libraries
    .target(
      name: "MCPTestingUtils",
      dependencies: [
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "MCPInterface"),
        .target(name: "SwiftTestingUtils"),
      ],
      path: "MCPTestingUtils/Sources"),
    .target(
      name: "SwiftTestingUtils",
      dependencies: [],
      path: "SwiftTestingUtils/Sources"),
    .testTarget(
      name: "MCPClientTests",
      dependencies: [
        .target(name: "MCPClient"),
        .target(name: "MCPInterface"),
        .target(name: "MCPTestingUtils"),
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "SwiftTestingUtils"),
      ],
      path: "MCPClient/Tests"),
    .testTarget(
      name: "MCPServerTests",
      dependencies: [
        .target(name: "MCPServer"),
        .target(name: "MCPInterface"),
        .target(name: "MCPTestingUtils"),
        .target(name: "SwiftTestingUtils"),
        .product(name: "JSONRPC", package: "JSONRPC"),
      ],
      path: "MCPServer/Tests"),
    .testTarget(
      name: "MCPInterfaceTests",
      dependencies: [
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "MCPInterface"),
        .target(name: "SwiftTestingUtils"),
      ],
      path: "MCPInterface/Tests"),
    .testTarget(
      name: "MCPSharedTesting",
      dependencies: [
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "MCPInterface"),
        .target(name: "MCPClient"),
        .target(name: "MCPServer"),
        .target(name: "MCPTestingUtils"),
        .target(name: "SwiftTestingUtils"),
      ],
      path: "MCPSharedTesting/Tests"),
  ])
