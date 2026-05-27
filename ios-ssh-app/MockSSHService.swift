import Foundation

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
        
        // Simulate command execution delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Return mock responses based on command
        switch command.lowercased() {
        case "ls":
            onOutput("Documents  Downloads  Pictures  Videos")
        case "pwd":
            onOutput("/home/user")
        case "whoami":
            onOutput("user")
        case "date":
            onOutput(Date().description)
        case "clear":
            // No output for clear command
            break
        default:
            // For other commands, return a generic response
            onOutput("Command '\(command)' executed successfully")
        }
    }
    
    func setHost(_ host: SSHHost) {
        // Mock service doesn't use host information
    }
}