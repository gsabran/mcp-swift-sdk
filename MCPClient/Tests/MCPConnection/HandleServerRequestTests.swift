
import JSONRPC
import MCPShared
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class HandleServerRequestTests: MCPClientConnectionTest {

    @Test("list roots")
    func test_listRoots() async throws {
      try await assert(
        executing: {
          // Handle the first incoming request
          for await(request, completion) in await self.sut.requestsToHandle {
            switch request {
            case .listRoots(let params):
              #expect(params == nil)
            default:
              Issue.record("Unexpected server request: \(request)")
            }
            completion(.success(ListRootsResult(roots: [.init(uri: "file:///home/user/projects/myproject", name: "My Project")])))
            break
          }
        }, triggers: [
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "method": "roots/list"
            }
            """),
          .request("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "roots": [
                  {
                    "uri": "file:///home/user/projects/myproject",
                    "name": "My Project"
                  }
                ]
              }
            }
            """),
        ])
    }

    @Test("create sampling message")
    func test_createMessage() async throws {
      try await assert(
        executing: {
          // Handle the first incoming request
          for await(request, completion) in await self.sut.requestsToHandle {
            switch request {
            case .createMessage(let params):
              #expect(params.maxTokens == 100)
            default:
              Issue.record("Unexpected server request: \(request)")
            }
            completion(.success(CreateMessageResult(
              role: .assistant,
              content: .text(.init(text: "The capital of France is Paris.")),
              model: "claude-3-sonnet-20240307",
              stopReason: "endTurn")))
            break
          }
        }, triggers: [
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "method": "sampling/createMessage",
              "params": {
                "messages": [
                  {
                    "role": "user",
                    "content": {
                      "type": "text",
                      "text": "What is the capital of France?"
                    }
                  }
                ],
                "modelPreferences": {
                  "hints": [
                    {
                      "name": "claude-3-sonnet"
                    }
                  ],
                  "intelligencePriority": 0.8,
                  "speedPriority": 0.5
                },
                "systemPrompt": "You are a helpful assistant.",
                "maxTokens": 100
              }
            }
            """),
          .request("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "role": "assistant",
                "content": {
                  "type": "text",
                  "text": "The capital of France is Paris."
                },
                "model": "claude-3-sonnet-20240307",
                "stopReason": "endTurn"
              }
            }
            """),
        ])
    }
  }
}
