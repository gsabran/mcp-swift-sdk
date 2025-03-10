import Foundation
import JSONSchemaBuilder
import MCPServer
import Vapor

/// Proxy transport, used for logging received and send data. (can be removed).
func proxy(_ transport: Transport) -> Transport {
  let (stream, continuation) = AsyncStream<Data>.makeStream()

  Task {
    for await data in transport.dataSequence {
      logger.log("Reading data from transport: \(String(data: data, encoding: .utf8)!, privacy: .public)")
      continuation.yield(data)
    }
    continuation.finish()
  }

  return Transport(
    writeHandler: { data in
      logger.log("Writing data to transport: \(String(data: data, encoding: .utf8)!, privacy: .public)")
      try await transport.writeHandler(data)
    },
    dataSequence: stream)
}

// MARK: - RepeatToolInput

@Schemable
struct RepeatToolInput {
  let text: String
}

@MainActor
func startMCPServer(sendDataTo responseStream: BodyStreamWriter, readDataFrom requestStream: AsyncStream<Data>) async throws {
  let transport = Transport(
    writeHandler: { data in
      let message = try MessageEvent(data: data).buffer()
      try await responseStream.write(.buffer(message)).get()
    },
    dataSequence: requestStream)

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
}
