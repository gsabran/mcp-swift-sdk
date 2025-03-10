// swiftlint:disable no_direct_standard_out_logs
import Foundation
import MCPClient
import MCPInterface

/// Read the path from the process args
let repoPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/path/to/repo"

let client = try await MCPClient(
  info: .init(name: "test", version: "1.0.0"),
  transport: .stdioProcess(
    "uvx",
    args: ["mcp-server-git"],
    verbose: true),
  capabilities: .init())

let tools = await client.tools
let tool = try tools.value.get().first(where: { $0.name == "git_status" })!
print("git_status tool: \(tool)")

// Those parameters can be passed to an LLM that support tool calling.
let description = tool.description
let name = tool.name
let schemaData = try JSONEncoder().encode(tool.inputSchema)
let schema = try JSONSerialization.jsonObject(with: schemaData)

/// The LLM could call into the tool with unstructured JSON input:
let llmToolInput: [String: Any] = [
  "repo_path": repoPath,
]
let llmToolInputData = try JSONSerialization.data(withJSONObject: llmToolInput)
let toolInput = try JSONDecoder().decode(JSON.self, from: llmToolInputData)

// Alternatively, you can call into the tool directly from Swift with structured input:
// let toolInput: JSON = ["repo_path": .string(repoPath)]

let result = try await client.callTool(named: name, arguments: toolInput)
if result.isError != true {
  let content = result.content.first?.text?.text
  print("Git status: \(content ?? "")")
}
