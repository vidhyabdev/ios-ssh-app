import Foundation
import Citadel

/// Real implementation of SSHService that executes commands through actual SSH
class RealSSHService: NSObject, SSHService {
    private var isConnected = false
    private var currentHost: SSHHost?
    private var client: SSHClient? = nil
    
    func connect() async throws {
        guard let host = currentHost else {
            throw SSHError.connectionFailed
        }
        
        // Create SSHClientSettings with host and password authentication
        let settings = SSHClientSettings(
            host: host.hostname,
            authenticationMethod: { .passwordBased(username: host.username, password: host.password ?? "") },
            hostKeyValidator: .acceptAnything()
        )
        
        do {
            // Connect to the server
            client = try await SSHClient.connect(to: settings)
            isConnected = true
        } catch {
            // Handle connection/authentication failure
            isConnected = false
            client = nil
            throw error
        }
    }
    
    func disconnect() {
        // Disconnect the SSHClient if it exists
        client = nil
        isConnected = false
    }
    
    func sendCommand(_ command: String) async throws -> String {
        guard isConnected else {
            throw SSHError.notConnected
        }
        
        guard let client = client else {
            throw SSHError.connectionFailed
        }
        
        // Execute command on remote server
        do {
            let output = try await client.executeCommand(command)
            // ByteBuffer to String conversion
            let stringOutput = String(decoding: output.readableBytesView, as: UTF8.self)
            return stringOutput
        } catch {
            throw SSHError.commandExecutionFailed
        }
    }
    
    func sendCommandStreaming(_ command: String, onOutput: @escaping (String) -> Void) async throws {
        // For now, call sendCommand and pass the full result to onOutput
        // This avoids implementing streaming logic which wasn't required
        let result = try await sendCommand(command)
        onOutput(result)
    }
    
    func setHost(_ host: SSHHost) {
        self.currentHost = host
    }
    
    func cancelCommand() {
        // For now, we'll just log that cancellation was requested
        // In a real implementation, we might need to handle cancellation differently
        // depending on how the streaming is implemented
        print("Cancel command requested")
    }
}