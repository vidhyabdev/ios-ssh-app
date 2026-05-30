import Foundation
import Citadel

/// Real implementation of SSHService that executes commands through actual SSH
class RealSSHService: NSObject, SSHService {
    private var isConnected = false
    private var currentHost: SSHHost?
    private var session: Citadel.Session? = nil
    
    func connect() async throws {
        guard let host = currentHost else {
            throw SSHError.connectionFailed
        }
        
        // Create Citadel session with host and port
        session = Citadel.Session(host: host.hostname, port: Int32(host.port))
        
        do {
            // Connect to the server
            try session?.connect()
            
            // Authenticate with password
            try session?.authenticate(username: host.username, password: host.password ?? "")
            
            // Check if connection and authentication were successful
            isConnected = true
        } catch {
            // Handle connection/authentication failure
            isConnected = false
            session = nil
            throw error
        }
    }
    
    func disconnect() {
        // Disconnect the Citadel session if it exists
        session?.disconnect()
        session = nil
        isConnected = false
    }
    
    func sendCommand(_ command: String) async throws -> String {
        guard isConnected else {
            throw SSHError.notConnected
        }
        
        guard let session = session else {
            throw SSHError.connectionFailed
        }
        
        // Execute command on remote server
        do {
            let output = try await session.execute(command)
            return output
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