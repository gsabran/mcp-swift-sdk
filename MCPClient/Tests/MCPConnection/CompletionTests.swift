
import JSONRPC
import MCPShared
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class CompletionTests: MCPClientConnectionTest {
    @Test("request completion")
    func test_requestCompletion() async throws {
      let resources = try await assert(
        executing: {
          try await self.sut.requestCompletion(CompleteRequest.Params(
            ref: .prompt(PromptReference(name: "code_review")),
            argument: .init(name: "language", value: "py")))
        },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "completion/complete",
            "params": {
              "ref": {
                "type": "ref/prompt",
                "name": "code_review"
              },
              "argument": {
                "name": "language",
                "value": "py"
              }
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "completion": {
                "values": ["python", "pytorch", "pyside"],
                "total": 10,
                "hasMore": true
              }
            }
          }
          """)
      #expect(resources.completion.values == ["python", "pytorch", "pyside"])
      #expect(resources.completion.hasMore == true)
    }
  }
}
