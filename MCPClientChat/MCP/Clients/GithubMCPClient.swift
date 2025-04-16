//
//  GithubMCPClient.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import Foundation
import MCPClient
import SwiftUI

final class GIthubMCPClient {
    
    // MARK: Lifecycle
    
    init() {
        print("🏃 Runnning GIthubMCPClient: \(String(describing: token))")
        Task {
            do {
                self.client = try await MCPClient(
                    info: .init(name: "GIthubMCPClient", version: "1.0.0"),
                    transport: .stdioProcess(
                        "npx",
                        args: ["-y", "@modelcontextprotocol/server-github"],
                        env: ["GITHUB_PERSONAL_ACCESS_TOKEN" : "\(token!)"],
                        verbose: false),
                    capabilities: .init())
                clientInitialized.continuation.yield(self.client)
                clientInitialized.continuation.finish()
                if let _ = try await self.client?.openAITools(){
                    print("✅ good")
                } else {
                    print("❌ Could not retrieve tools")
                }
                print("☺️ Initialized MCP Client: GIthubMCPClient")
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
    let token = ProcessInfo.processInfo.environment["github_token"]
    private var client: MCPClient?
    private let clientInitialized = AsyncStream.makeStream(of: MCPClient?.self)
}
