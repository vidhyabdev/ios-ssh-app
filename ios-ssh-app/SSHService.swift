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
    
    /// Set the host for this SSH service instance
    func setHost(_ host: SSHHost)
    
    /// Send a command to the SSH host with streaming output
    func sendCommandStreaming(_ command: String, onOutput: @escaping (String) -> Void) async throws
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
    
    func sendCommandStreaming(_ command: String, onOutput: @escaping (String) -> Void) async throws {
        guard isConnected else {
            throw SSHError.notConnected
        }
        
        // Simulate streaming output for the command
        let mockOutputLines = [
            "Starting command: \(command)",
            "Processing...",
            "Executing...",
            "Command completed successfully"
        ]
        
        for line in mockOutputLines {
            // Simulate delay between output lines
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            onOutput(line)
        }
    }
    
    func setHost(_ host: SSHHost) {
        // Mock service doesn't use host information
    }
}

/// Error types for SSH operations
enum SSHError: Error, LocalizedError {
    case notConnected
    case connectionFailed
    case connectionFailedWithDetails(String)
    case authenticationFailed
    case hostKeyVerificationFailed
    case hostUnreachable
    case timeout
    case sshHandshakeFailed
    case commandExecutionFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to SSH host"
        case .connectionFailed:
            return "Failed to connect to SSH host"
        case .connectionFailedWithDetails(let details):
            return details
        case .authenticationFailed:
            return "Authentication failed for SSH host"
        case .hostKeyVerificationFailed:
            return "Host key verification failed. The authenticity of the host cannot be established."
        case .hostUnreachable:
            return "Host is unreachable"
        case .timeout:
            return "Connection timed out"
        case .sshHandshakeFailed:
            return "SSH handshake failed"
        case .commandExecutionFailed:
            return "Failed to execute command on SSH host"
        }
    }
}
