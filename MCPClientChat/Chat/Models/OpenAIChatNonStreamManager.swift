//
//  OpenAIChatNonStreamModel.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import Foundation
import MCPSwiftWrapper
import SwiftUI

@MainActor
@Observable
/// Handle a chat conversation without stream for OpenAI.
final class OpenAIChatNonStreamManager: ChatManager {
    let OPENAI_CHAT_MODEL_NAME = ProcessInfo.processInfo.environment["OPENAI_CHAT_MODEL_NAME"]!

    // MARK: Lifecycle
    
    init(service: OpenAIService) {
        print("✅ OpenAIService Start")
        self.service = service
    }
    
    // MARK: Internal
    
    /// Messages sent from the user or received from OpenAI
    var messages: [ChatMessage] = []
    
    /// Error message if something goes wrong
    var errorMessage = ""
    
    /// Loading state indicator
    var isLoading = false
    
    /// Returns true if OpenAI is still processing a response
    var isProcessing: Bool {
        isLoading
    }
    
    func updateClient(_ client: MCPClient) {
        mcpClient = client
    }
    
    /// Send a new message to OpenAI and get the complete response
    func send(message: ChatMessage) {
        print("✅ Send Mssg")
        messages.append(message)
        processUserMessage(prompt: message.text)
    }
    
    /// Cancel the current processing task
    func stop() {
        task?.cancel()
        task = nil
        isLoading = false
    }
    
    /// Clear the conversation
    func clearConversation() {
        messages.removeAll()
        openAIMessages.removeAll()
        errorMessage = ""
        isLoading = false
        task?.cancel()
        task = nil
    }
    
    // MARK: Private
    
    /// Service to communicate with OpenAI API
    private let service: OpenAIService
    
    /// Message history for OpenAI's context
    private var openAIMessages: [OpenAIMessage] = []
    
    /// Current task handling OpenAI API request
    private var task: Task<Void, Never>? = nil
    
    private var mcpClient: MCPClient?
    
    private func processUserMessage(prompt: String) {
        print("🟡 processUserMessage")
        
        // Add a placeholder for OpenAI's response
        messages.append(ChatMessage(text: "", role: .assistant, isWaitingForFirstText: true))
        
        // Add user message to history
        openAIMessages.append(OpenAIMessage(
            role: .user,
            content: .text(prompt)))
        
        task = Task {
            do {
                isLoading = true
                
                print("🟡 get client")
                guard let mcpClient else {
                    throw NSError(domain: "OpenAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "mcpClient is nil"])
                }
                print("🟡 get tools")
                // Get available tools from MCP
                var tools = try await mcpClient.openAITools()
                tools = tools.filter { $0.function.name != "create_pull_request_review" }

                // Send request and process response
                try await continueConversation(tools: tools)
                
                isLoading = false
            } catch {
                print("❌- \(error)")
                errorMessage = "\(error)"
                
                // Update UI to show error
                if var last = messages.popLast() {
                    last.isWaitingForFirstText = false
                    last.text = "Sorry, there was an error: \(error.localizedDescription)"
                    messages.append(last)
                    print("❌- \(error.localizedDescription)")
                }
                
                isLoading = false
            }
        }
    }
    
    private func continueConversation(tools: [OpenAITool]) async throws {
        print("🟡 in continueConversation")
        
        guard let mcpClient else {
            throw NSError(domain: "OpenAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "mcpClient is nil"])
        }
        
        let parameters = OpenAIParameters(
            messages: openAIMessages,
            model: .custom(OPENAI_CHAT_MODEL_NAME),
            toolChoice: .auto,
            tools: tools)
        print("🟡-----------\nparameters: \nmessages: \(parameters.messages)\nmodel: \(parameters.model)\ntools: \(String(describing: parameters.tools))\n-----------\n🟡make request")
        // Make non-streaming request to OpenAI
        let response = try await service.startChat(parameters: parameters)
        print("🟡Response: \(String(describing: response.choices?.first?.message))")
        guard
            let choices = response.choices,
            let firstChoice = choices.first,
            let message = firstChoice.message
        else {
            print("❌-3")
            throw NSError(domain: "OpenAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "No message in response"])
        }
        print("🟡 Process the regular text content")
        
        // Process the regular text content
        if let messageContent = message.content, !messageContent.isEmpty {
            // Update the UI with the response
            if var last = messages.popLast() {
                last.isWaitingForFirstText = false
                last.text = messageContent
                messages.append(last)
            }
            
            // Add assistant response to history
            openAIMessages.append(OpenAIMessage(
                role: .assistant,
                content: .text(messageContent)))
        }
        print("🟡 Process tool calls if any")
        
        // Process tool calls if any
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            for toolCall in toolCalls {
                let function = toolCall.function
                guard
                    let id = toolCall.id,
                    let name = function.name,
                    let argumentsData = function.arguments.data(using: .utf8)
                else {
                    continue
                }
                
                let toolId = id
                let toolName = name
                let argumentsString = function.arguments
                
                // Parse arguments from string to dictionary
                let arguments: [String: Any]
                do {
                    guard let parsedArgs = try JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
                        continue
                    }
                    arguments = parsedArgs
                } catch {
                    print("❌-4")
                    print("Error parsing tool arguments: \(error)")
                    continue
                }
                
                print("Tool use detected - Name: \(toolName), ID: \(toolId)")
                
                // Update UI to show tool use
                if var last = messages.popLast() {
                    last.isWaitingForFirstText = false
                    last.text += "\n Using tool: \(toolName)..."
                    messages.append(last)
                }
                
                // Add the assistant message with tool call to message history
                let toolCallObject = OpenAIToolCall(
                    id: toolId,
                    function: SwiftOpenAI.FunctionCall(
                        arguments: argumentsString,
                        name: toolName))
                
                openAIMessages.append(OpenAIMessage(
                    role: .assistant,
                    content: .text(""), // Content is null when using tool calls
                    toolCalls: [toolCallObject]))
                
                // Call tool via MCP
                let toolResponse = await mcpClient.openAICallTool(name: toolName, input: arguments, debug: true)
                print("Tool response: \(String(describing: toolResponse))")
                
                // Add tool result to conversation
                if let toolResult = toolResponse {
                    // Add the tool result as a tool message
                    openAIMessages.append(OpenAIMessage(
                        role: .tool,
                        content: .text(toolResult),
                        toolCallID: toolId))
                    
                    // Now get a new response with the tool result
                    try await continueConversation(tools: tools)
                } else {
                    print("❌-5")
                    // Handle tool failure
                    if var last = messages.popLast() {
                        last.isWaitingForFirstText = false
                        last.text = "There was an error using the tool \(toolName)."
                        messages.append(last)
                    }
                    
                    // Add error response as tool message
                    openAIMessages.append(OpenAIMessage(
                        role: .tool,
                        content: .text("Error: Tool execution failed"),
                        toolCallID: toolId))
                }
            }
        }
        print("🟡 Finishes?")
    }
}
