//
//  SSHService.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import Foundation

/// Protocol defining the interface for SSH connections
protocol SSHService {
    /// Connect to the SSH host
    func connect() async throws
    
    /// Disconnect from the SSH host
    func disconnect()
    
    /// Send a command to the SSH host
    func sendCommand(_ command: String) async throws -> String
}

/// Mock implementation of SSHService for testing and development
class MockSSHService: SSHService {
    private var isConnected = false
    
    func connect() async throws {
        // Simulate connection delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        isConnected = true
    }
    
    func disconnect() {
        isConnected = false
    }
    
    func sendCommand(_ command: String) async throws -> String {
        guard isConnected else {
            throw SSHError.notConnected
        }
        
        // Simulate command execution delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Return mock responses based on command
        switch command.lowercased() {
        case "ls":
            return "Documents  Downloads  Pictures  Videos"
        case "pwd":
            return "/home/user"
        case "whoami":
            return "user"
        case "date":
            return Date().description
        case "clear":
            return ""
        default:
            // For other commands, return a generic response
            return "Command '\(command)' executed successfully"
        }
    }
}

/// Error types for SSH operations
enum SSHError: Error, LocalizedError {
    case notConnected
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to SSH host"
        case .connectionFailed:
            return "Failed to connect to SSH host"
        }
    }
}