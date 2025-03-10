import Foundation
import JSONRPC

public typealias HandleRequest<Request> = (Request, (AnyJRPCResponse) -> Void)

// MARK: - MCPConnection

/// Note: this class is not thread safe, and should be used in a thread safe context (like within an actor).
package class MCPConnection<Request: Decodable & Equatable, Notification: Decodable & Equatable> {

  public init(
    transport: Transport)
    throws
  {
    jrpcSession = JSONRPCSession(channel: transport)

    var sendNotificationToStream: (Notification) -> Void = { _ in }
    notifications = AsyncStream<Notification>() { continuation in
      sendNotificationToStream = { continuation.yield($0) }
    }
    self.sendNotificationToStream = sendNotificationToStream

    // A bit hard to read... When a request is received (sent to `askForRequestToBeHandle`), we yield it to the stream
    // where we expect someone to be listening and handling the request. The handler then calls the completion `requestContinuation`
    // which will be sent back as an async response to `askForRequestToBeHandle`.
    var askForRequestToBeHandle: ((Request) async -> AnyJRPCResponse)? = nil
    requestsToHandle = AsyncStream<HandleRequest<Request>>() { streamContinuation in
      askForRequestToBeHandle = { request in
        await withCheckedContinuation { (requestContinuation: CheckedContinuation<AnyJRPCResponse, Never>) in
          streamContinuation.yield((request, { response in
            requestContinuation.resume(returning: response)
          }))
        }
      }
    }
    self.askForRequestToBeHandle = askForRequestToBeHandle

    Task { await listenToIncomingMessages() }
  }

  public private(set) var notifications: AsyncStream<Notification>
  public private(set) var requestsToHandle: AsyncStream<HandleRequest<Request>>

  package let jrpcSession: JSONRPCSession

  private var sendNotificationToStream: ((Notification) -> Void) = { _ in }

  private var askForRequestToBeHandle: ((Request) async -> AnyJRPCResponse)? = nil

  private var eventHandlers = [String: (JSONRPCEvent) -> Void]()

  private func listenToIncomingMessages() async {
    let events = await jrpcSession.eventSequence
    Task { [weak self] in
      for await event in events {
        self?.handle(receptionOf: event)
      }
    }
  }

  private func handle(receptionOf event: JSONRPCEvent) {
    switch event {
    case .notification(_, let data):
      do {
        let notification = try JSONDecoder().decode(Notification.self, from: data)
        sendNotificationToStream(notification)
      } catch {
        mcpLogger
          .error("Failed to decode notification \(String(data: data, encoding: .utf8) ?? "invalid data", privacy: .public)")
      }

    case .request(_, let handler, let data):
      Task { await handler(handle(receptionOf: data)) }

    case .error(let error):
      mcpLogger.error("Received error: \(error, privacy: .public)")
    }
  }

  private func handle(receptionOf request: Data) async -> AnyJRPCResponse {
    if let decodedRequest = try? JSONDecoder().decode(Request.self, from: request) {
      guard let askForRequestToBeHandle else {
        mcpLogger.error("Unable to handle request. The MCP connection has not been set properly")
        return .failure(.init(
          code: JRPCErrorCodes.methodNotFound.rawValue,
          message: "Unable to handle request. The MCP connection has not been set properly"))
      }
      return await askForRequestToBeHandle(decodedRequest)
    } else if (try? JSONDecoder().decode(PingRequest.self, from: request)) != nil {
      // Respond to ping
      return .success(PingRequest.Result())
    }
    mcpLogger
      .error(
        "Received unknown request: \(String(data: request, encoding: .utf8) ?? "invalid data", privacy: .public)")
    return .failure(.init(
      code: JRPCErrorCodes.methodNotFound.rawValue,
      message: "The request could not be decoded to a known type"))
  }

}
