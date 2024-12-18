// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MCP",
  platforms: [
    .macOS(.v14),
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
    .package(url: "https://github.com/ChimeHQ/JSONRPC", revision: "ef61a695bafa0e07080dadac65a0c59b37880548"),
    .package(url: "https://github.com/gohanlon/swift-memberwise-init-macro", from: "0.5.1"),
    // Dev dependency
    .package(url: "https://github.com/airbnb/swift", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "MCPClient",
      dependencies: [
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "MCPShared"),
      ],
      path: "MCPClient/Sources"),
    .testTarget(
      name: "MCPClientTests",
      dependencies: [
        .target(name: "MCPClient"),
        .target(name: "MCPShared"),
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "SwiftTestingUtils"),
      ],
      path: "MCPClient/Tests"),
    .target(
      name: "MCPServer",
      dependencies: [
        .product(name: "JSONRPC", package: "JSONRPC"),
        .target(name: "MCPShared"),
      ],
      path: "MCPServer/Sources"),
    .testTarget(
      name: "MCPServerTests",
      dependencies: [
        .target(name: "MCPServer"),
        .target(name: "MCPShared"),
        .target(name: "SwiftTestingUtils"),
      ],
      path: "MCPServer/Tests"),
    .target(
      name: "MCPShared",
      dependencies: [
        //        .product(name: "JSONRPC", package: "JSONRPC"),
        .product(name: "MemberwiseInit", package: "swift-memberwise-init-macro"),
      ],
      path: "MCPShared/Sources"),
    .testTarget(
      name: "MCPSharedTests",
      dependencies: [
        .target(name: "MCPShared"),
      ],
      path: "MCPShared/Tests"),
    .target(
      name: "SwiftTestingUtils",
      dependencies: [],
      path: "SwiftTestingUtils/Sources"),
    .testTarget(
      name: "SwiftTestingUtilsTests",
      dependencies: [
        .target(name: "SwiftTestingUtils"),
      ],
      path: "SwiftTestingUtils/Tests"),
  ])
