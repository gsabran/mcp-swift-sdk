
import MCPShared
import SwiftTestingUtils
import Testing
@testable import MCPClient

// MARK: - MCPClientConnectionTestSuite

/// All the tests about `MCPClientConnection`
@Suite("MCP Connection")
class MCPClientConnectionTestSuite { }

// MARK: - MCPClientConnectionTest

/// A parent test class that provides a few util functions to assert that the interactions with the transport are as expected.
class MCPClientConnectionTest {

  // MARK: Lifecycle

  init() {
    transport = MockTransport()
    clientCapabilities = ClientCapabilities(
      roots: .init(listChanged: true),
      sampling: .init())
    sut = try! MCPClientConnection(
      info: .init(name: "TestClient", version: "1.0.0"),
      capabilities: clientCapabilities,
      transport: transport.dataChannel)
  }

  // MARK: Internal

  var transport: MockTransport
  let clientCapabilities: ClientCapabilities
  var sut: MCPClientConnection

  /// Asserts that the given task sends the expected requests and receives the expected responses.
  /// - Parameters:
  ///  - task: The task to execute.
  ///  - messages: The sequence of messages relevant to the task. All responses are dequeued as soon as possible, and each request is awaited for until continuing to dequeue messages.
  ///  - transport: The transport to use.
  static func assert<Result>(
    executing task: @escaping () async throws -> Result,
    triggers messages: [Message],
    with transport: MockTransport)
    async throws -> Result
  {
    var result: Result? = nil
    var err: Error? = nil

    /// The next message that the system is expected to send.
    var nextMessageToSent: (exp: SwiftTestingUtils.Expectation, message: String)?

    transport.sendMessage = { data in
      if let (exp, message) = nextMessageToSent {
        assertEqual(received: data, expected: message)
        exp.fulfill()
      } else {
        Issue.record("Unexpected message sent: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
      }
    }

    var i = 0
    let prepareNextExpectedMessage = {
      if let request = messages[i..<messages.count].compactMap({ $0.request }).first {
        nextMessageToSent = (exp: expectation(description: "request sent"), message: request)
      } else {
        nextMessageToSent = nil
      }
    }
    prepareNextExpectedMessage()

    // Start the task
    let taskCompleted = expectation(description: "task completed")
    Task {
      do {
        result = try await task()
      } catch {
        err = error
      }
      taskCompleted.fulfill()
    }

    // Process each message
    while i < messages.count {
      let message = messages[i]
      i += 1
      switch message {
      case .response(let response):
        // Responses are sent immediately
        transport.receive(message: response)
      case .request:
        // Requests are awaited for (the expectation for the current request has already been set by `prepareNextExpectedMessage`).
        guard let nextMessageToSent else {
          throw TestError.internalError
        }
        try await fulfillment(of: nextMessageToSent.exp)
        prepareNextExpectedMessage()
      }
    }

    // Wait for the task to complete
    try await fulfillment(of: taskCompleted)
    guard let result else {
      throw err ?? TestError.expectationUnfulfilled
    }
    return result
  }

  /// Assert that after receiving the given request, the given response is sent.
  func assert(
    receiving request: String,
    respondsWith response: String)
    async throws
  {
    let responseSent = expectation(description: "response sent")
    transport.expect(messages: [
      { sendMessage in
        sendMessage(response)
        responseSent.fulfill()
      },
    ])

    transport.receive(message: request)
    try await fulfillment(of: responseSent)
  }

  /// Asserts that executing the given task sends the expected request and that then receiving the specified response leads to the task's completion.
  func assert<Result>(
    executing task: @escaping () async throws -> Result,
    sends request: String,
    receives response: String)
    async throws -> Result
  {
    try await assert(executing: task, triggers: [
      .request(request),
      .response(response),
    ])
  }

  /// Asserts that the given task sends the expected requests and receives the expected responses.
  /// - Parameters:
  ///  - task: The task to execute.
  ///  - messages: The sequence of messages relevant to the task. All responses are dequeued as soon as possible, and each request is awaited for until continuing to dequeue messages.
  func assert<Result>(
    executing task: @escaping () async throws -> Result,
    triggers messages: [Message])
    async throws -> Result
  {
    try await Self.assert(executing: task, triggers: messages, with: transport)
  }

  func assert<Result>(
    executing task: @escaping () async throws -> Result,
    sends request: String,
    receives response: String,
    andFailsWith errorHandler: (Error) -> Void)
    async
  {
    do {
      _ = try await assert(executing: task, sends: request, receives: response)
      Issue.record("Expected the task to fail")
    } catch {
      // Expected
      errorHandler(error)
    }
  }

}
