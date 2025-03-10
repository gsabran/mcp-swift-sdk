import Foundation
import JSONSchemaBuilder
import MCPServer
import Vapor

/// Start the web server.
/// - Parameter runMCPServerForConnection: When a new connection is made to connect to MCP, create a new MCP server (one instance per connection) to handle the request.
func runWebServer(runMCPServerForConnection: @escaping (BodyStreamWriter, AsyncStream<Data>) async throws -> Void) async throws {
  var sessions: [String: AsyncStream<Data>.Continuation] = [:]

  let app = try await Application.make()

  app.get("sse") { _ async -> Response in
    // Expects an initial request to /sse, which will start a long lived connection.
    // It will immediately write to that connection an endpoint where to send messages to that contains an identifier for this connection.
    let body = Response.Body(stream: { writer in
      Task {
        do {
          let sessionId = UUID().uuidString
          let (stream, continuation) = AsyncStream<Data>.makeStream()
          sessions[sessionId] = continuation // TODO: look at concurrency.

          let message = try EndpointEvent(sessionId: sessionId).buffer()
          try await writer.write(.buffer(message)).get()

          try await runMCPServerForConnection(writer, stream)
          _ = writer.write(.end)
        } catch {
          logger.error("Error: \(error, privacy: .public)")
        }
      }
    })

    let response = Response(status: .ok, body: body)

    response.headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
    response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
    response.headers.replaceOrAdd(name: .connection, value: "keep-alive")

    return response
  }

  // To send messages to the server, the client will POST to /messages with a sessionId query parameter.
  app.post("messages") { request async -> Response in
    guard let sessionId = request.query[String.self, at: "sessionId"] else {
      return Response(status: .badRequest)
    }
    guard let session = sessions[sessionId] else {
      return Response(status: .notFound)
    }
    guard
      let contentType = request.headers.first(name: "Content-Type"),
      contentType.contains("application/json"),
      let contentLengthStr = request.headers.first(name: "content-length"),
      let contentLength = Int(contentLengthStr),
      var bodyData = request.body.data,
      bodyData.readableBytes >= contentLength,
      let bytes = bodyData.readBytes(length: contentLength)
    else {
      return Response(status: .badRequest)
    }
    let data = Data(bytes)
    session.yield(data)
    return Response(status: .ok)
  }

  try await app.execute()
}

// MARK: - ServerEvent

protocol ServerEvent {
  var event: String? { get }
  var data: [String] { get }
  var id: String? { get }
  var retry: Int? { get }
}

extension ServerEvent {
  var isValid: Bool {
    !data.isEmpty
  }
}

// MARK: - ServerEventError

enum ServerEventError: Error {
  case noDataAvailable
  case encoding
}

extension ServerEvent {
  func buffer() throws -> ByteBuffer {
    guard isValid else {
      throw ServerEventError.noDataAvailable
    }

    var message = ""

    if let event {
      message += "event: \(event)\n"
    }

    message += data
      .map { "data: \($0)" }
      .joined(separator: "\n")
      .appending("\n")

    if let id {
      message += "id: \(id)\n"
    }

    if let retry {
      message += "retry: \(retry)\n"
    }

    message += "\n\n"

    return ByteBuffer(string: message)
  }
}

// MARK: - EndpointEvent

struct EndpointEvent: ServerEvent {
  var id: String?

  var retry: Int?

  init(sessionId: String) {
    self.sessionId = sessionId
  }

  let event: String? = "endpoint"
  var data: [String] { ["/messages?sessionId=\(sessionId)"] }
  private let sessionId: String
}

// MARK: - MessageEvent

struct MessageEvent: ServerEvent {
  var id: String?

  var retry: Int?

  let event: String? = "message"
  init(data: Data) {
    self.data = [String(data: data, encoding: .utf8)!]
  }

  var data: [String]
}
