//
//  ChatManager.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import Foundation
import MCPClient
import MCPInterface

/// Protocol that defines the interface for managing chat functionality within an application.
/// All implementations operate on the main thread to ensure proper UI updates.
@MainActor
protocol ChatManager {
    /// Collection of all chat messages in the conversation.
    var messages: [ChatMessage] { get set }
    
    /// Indicates whether the chat manager is currently processing a message or operation.
    /// Used for displaying loading indicators or preventing concurrent operations.
    var isProcessing: Bool { get }
    
    /// Terminates any ongoing message processing operations.
    /// Use this to cancel message processing, such as when generating AI responses.
    func stop()
    
    /// Sends a new message to the chat.
    /// - Parameter message: The message to be sent
    func send(message: ChatMessage)
    
    /// Updates the client used for communication.
    /// - Parameter client: The MCPClient to use for handling communication
    func updateClient(_ client: MCPClient)
}
