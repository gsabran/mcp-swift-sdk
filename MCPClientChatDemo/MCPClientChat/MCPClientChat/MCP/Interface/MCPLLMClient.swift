//
//  MCPLLMClient.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import Foundation
import MCPClient
import MCPInterface
import SwiftAnthropic

// TODO: James+Gui decide where this should live so it can be reused.

/**
 * Protocol that bridges the MCP (Multi-Client Protocol) framework with LLM providers library.
 *
 * This protocol provides methods to:
 * 1. Retrieve available tools from an MCP client and convert them to Anthropic's format
 * 2. Execute tools with provided parameters and handle their responses
 */
protocol MCPLLMClient {
   
   /// The underlying MCP client that processes requests
   var client: MCPClient? { get }
   /**
    * Retrieves available tools from the MCP client and converts them to Anthropic's tool format.
    *
    * - Returns: An array of Anthropic-compatible tools
    * - Throws: Errors from the underlying MCP client or during conversion process
    */
   func tools() async throws -> [MessageParameter.Tool]
   /**
     * Executes a tool with the specified name and input parameters.
     *
     * - Parameters:
     *   - name: The identifier of the tool to call
     *   - input: Dictionary of parameters to pass to the tool
     *   - debug: Flag to enable verbose logging during execution
     * - Returns: A string containing the tool's response, or `nil` if execution failed
     */
   func callTool(name: String, input: [String: Any], debug: Bool) async -> String?
}

/**
 * Extension providing default implementations of the MCPSwiftAnthropicClient protocol.
 */
extension MCPLLMClient {
   
   func tools() async throws -> [MessageParameter.Tool] {
      guard let client else { return [] }
      let tools = await client.tools
      return try tools.value.get().map { $0.toAnthropicTool() }
   }
   
   func callTool(
      name: String,
      input: [String: Any],
      debug: Bool)
      async -> String? {
      
      guard let client else { return nil }

      do {
         if debug {
            print("🔧 Calling tool '\(name)'...")
         }
         
         // Convert DynamicContent values to basic types
         var serializableInput: [String: Any] = [:]
         for (key, value) in input {
            if let dynamicContent = value as? MessageResponse.Content.DynamicContent {
               serializableInput[key] = dynamicContent.extractValue()
            } else {
               serializableInput[key] = value
            }
         }
         
         let inputData = try JSONSerialization.data(withJSONObject: serializableInput)
         let inputJSON = try JSONDecoder().decode(JSON.self, from: inputData)
         
         let result = try await client.callTool(named: name, arguments: inputJSON)
         
         if result.isError != true {
            if let content = result.content.first?.text?.text {
               if debug {
                  print("✅ Tool execution successful")
               }
               return content
            } else {
               if debug {
                  print("⚠️ Tool returned no text content")
               }
               return nil
            }
         } else {
            print("❌ Tool returned an error")
            if let errorText = result.content.first?.text?.text {
               if debug {
                  print("   Error: \(errorText)")
               }
            }
            return nil
         }
      } catch {
         if debug {
            print("⛔️ Error calling tool: \(error)")
         }
         return nil
      }
   }
}
