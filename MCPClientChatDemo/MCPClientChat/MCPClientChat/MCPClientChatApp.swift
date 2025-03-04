//
//  MCPClientChatApp.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import SwiftUI
import SwiftAnthropic

@main
struct MCPClientChatApp: App {
      
   @State private var chatManager = ChatNonStreamManager(
      service: AnthropicServiceFactory.service(apiKey: "YOUR_API_KEY", betaHeaders: nil, debugEnabled: true),
      mcpLLMClient: GIthubMCPClient())
   
   var body: some Scene {
      WindowGroup {
         ChatView(chatManager: chatManager)
            .toolbar(removing: .title)
            .containerBackground(
               .thinMaterial, for: .window
            )
            .toolbarBackgroundVisibility(
               .hidden, for: .windowToolbar
            )
      }
      .windowStyle(.hiddenTitleBar)
   }
}
