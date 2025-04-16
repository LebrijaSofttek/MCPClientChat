//
//  AatlassianMCPClient.swift
//  MCPClientChat
//
//  Created by Juan Lebrija on 16/04/25.
//

import Foundation
import MCPClient
import SwiftUI

final class AtlassianMCPClient {
    
    // MARK: Lifecycle
    init() {
        print("🏃 Runnning AtlassianMCPClient")
        Task {
            do {
                self.client = try await MCPClient(
                    info: .init(name: "AtlassianMCPClient", version: "1.0.0"),
                    transport: .stdioProcess(
                        "uvx",
                        args: ["mcp-atlassian"],
                        env: ["CONFLUENCE_URL": "https://your-company.atlassian.net/wiki",
                              "CONFLUENCE_USERNAME": "your.email@company.com",
                              "CONFLUENCE_API_TOKEN": "\(ProcessInfo.processInfo.environment["atlassian_token"]!)",
                              "JIRA_URL": "https://juanlebrija2002-1742602157566.atlassian.net",
                              "JIRA_USERNAME": "juan.lebrija2002@gmail.com",
                              "JIRA_API_TOKEN": "\(ProcessInfo.processInfo.environment["atlassian_token"]!)"],
                        verbose: false),
                    capabilities: .init())
                clientInitialized.continuation.yield(self.client)
                clientInitialized.continuation.finish()
                if let _ = try await self.client?.openAITools(){
                    print("✅ good")
                } else {
                    print("❌ Could not retrieve tools")
                }
                print("☺️ Initialized MCP Client: AtlassianMCPClient")
            } catch {
                print("❌ Failed to initialize MCPClient: \(error)")
                clientInitialized.continuation.yield(nil)
                clientInitialized.continuation.finish()
            }
        }
    }
    
    // MARK: Internal
    /// Modern async/await approach
    func getClientAsync() async throws -> MCPClient? {
        for await client in clientInitialized.stream {
            print("🈺 client: \(try await String(describing: client?.openAITools().debugDescription))")
            return client
        }
        return nil // Stream completed without a client
    }
    
    // MARK: Private
    private var client: MCPClient?
    private let clientInitialized = AsyncStream.makeStream(of: MCPClient?.self)
}
