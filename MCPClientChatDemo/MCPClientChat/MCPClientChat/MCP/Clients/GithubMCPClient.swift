//
//  GithubMCPClient.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import Foundation
import MCPClient
import SwiftUI

final class GIthubMCPClient: MCPLLMClient {
   
   var client: MCPClient?
   
   init() {
      Task {
         do {
            /// Need to define manually the `env`  to be able to initialize client!!!
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "")
            //    customEnv["GITHUB_PERSONAL_ACCESS_TOKEN"] = "YOUR_GITHUB_PERSONAL_TOKEN" // Needed for write operations.
            self.client = try await MCPClient(
               info: .init(name: "GIthubMCPClient", version: "1.0.0"),
               transport: .stdioProcess(
                  "npx",
                  args: ["-y", "@modelcontextprotocol/server-github"],
                  env: env,
                  verbose: true
               ),
               capabilities: .init()
            )
         } catch {
            print("Failed to initialize MCPClient: \(error)")
         }
      }
   }
}
