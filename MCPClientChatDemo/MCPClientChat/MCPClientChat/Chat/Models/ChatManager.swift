//
//  ChatManager.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import Foundation

@MainActor
protocol ChatManager {
   var messages: [ChatMessage] { get set }
   var isProcessing: Bool { get }
   func stop()
   func send(message: ChatMessage)
}
