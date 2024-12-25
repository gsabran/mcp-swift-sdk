
import JSONRPC
import MCPShared
import Testing
@testable import MCPClient

// MARK: - MCPClientConnectionTestSuite.CallToolTests

extension MCPClientConnectionTestSuite {
  final class CallToolTests: MCPClientConnectionTest {

    // MARK: Internal

    @Test("call tool")
    func test_callTool() async throws {
      let weathers = try await assert(executing: {
        try await self.sut.call(
          toolName: self.tool.name,
          arguments: .object([
            "location": .string("New York"),
          ]),
          progressToken: .string("toolCallId"))
          .content
          .map { $0.text }
      }, sends: """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "method": "tools/call",
          "params": {
            "_meta" : {
              "progressToken" : "toolCallId"
            },
            "name": "get_weather",
            "arguments": {
              "location": "New York"
            }
          }
        }
        """, receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "content": [{
                "type": "text",
                "text": "Current weather in New York:\\nTemperature: 72°F\\nConditions: Partly cloudy"
              }]
            }
          }
          """)

      #expect(weathers.map { $0?.text } == ["Current weather in New York:\nTemperature: 72°F\nConditions: Partly cloudy"])
    }

    @Test("protocol error")
    func test_protocolError() async throws {
      await assert(
        executing: {
          _ = try await self.sut.call(toolName: self.tool.name, arguments: .object([
            "location": .string("New York"),
          ]))
        },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
              "name": "get_weather",
              "arguments": {
                "location": "New York"
              }
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "error": {
              "code": -32602,
              "message": "Unknown tool: invalid_tool_name"
            }
          }
          """) { error in
          guard let error = error as? JSONRPCResponseError<JSONValue> else {
            Issue.record("Unexpected error type: \(error)")
            return
          }

          #expect(error.code == -32602)
          #expect(error.message == "Unknown tool: invalid_tool_name")
          #expect(error.data == nil)
        }
    }

    @Test("tool call error")
    func test_toolCallError() async throws {
      let response = try await assert(
        executing: {
          try await self.sut.call(
            toolName: self.tool.name,
            arguments: .object([
              "location": .string("New York"),
            ]))
        },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
              "name": "get_weather",
              "arguments": {
                "location": "New York"
              }
            }
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "content": [{
                "type": "text",
                "text": "Failed to fetch weather data: API rate limit exceeded"
              }],
              "isError": true
            }
          }
          """)
      #expect(response.isError == true)
      #expect(response.content.map { $0.text?.text } == ["Failed to fetch weather data: API rate limit exceeded"])
//      { error in
//       guard let error = error as? MCPClientError else {
//         Issue.record("Unexpected error type: \(error)")
//         return
//       }
//
//       switch error {
//       case .toolCallError(let errors):
//         #expect(errors.map { $0.text } == ["Failed to fetch weather data: API rate limit exceeded"])
//       default:
//         Issue.record("Unexpected error type: \(error)")
//       }
//     }
    }

    // MARK: Private

    private let tool = Tool(
      name: "get_weather",
      description: "Get current weather information for a location",
      inputSchema: .array([]))

  }
}

// MARK: - ToolArguments

private struct ToolArguments: Encodable {
  let location: String
}

// MARK: - ToolResponse

private struct ToolResponse: Decodable {
  let type: String
  let text: String
}
