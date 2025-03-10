import Foundation
import JSONSchemaBuilder
import MCPServer

let transport = Transport.stdio()
func proxy(_ transport: Transport) -> Transport {
  var sendToDataSequence: AsyncStream<Data>.Continuation?
  let dataSequence = AsyncStream<Data>.init { continuation in
    sendToDataSequence = continuation
  }

  Task {
    for await data in transport.dataSequence {
      mcpLogger.info("Reading data from transport: \(String(data: data, encoding: .utf8)!, privacy: .public)")
      sendToDataSequence?.yield(data)
    }
  }

  return Transport(
    writeHandler: { data in
      mcpLogger.info("Writing data to transport: \(String(data: data, encoding: .utf8)!, privacy: .public)")
      try await transport.writeHandler(data)
    },
    dataSequence: dataSequence)
}

// MARK: - RepeatToolInput

@Schemable
struct RepeatToolInput {
  let text: String
}

let server = try await MCPServer(
  info: Implementation(name: "test-server", version: "1.0.0"),
  capabilities: ServerCapabilityHandlers(tools: [
    Tool(name: "repeat") { (input: RepeatToolInput) in
      [.text(.init(text: input.text))]
    },
    testTool,
  ]),
  transport: proxy(transport))

try await server.waitForDisconnection()
