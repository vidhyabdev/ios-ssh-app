import Foundation
import NMSSH

/// Real implementation of SSHService that executes commands through actual SSH
class RealSSHService: SSHService {
    private var isConnected = false
    private var currentHost: SSHHost?
    private var session: NMSSHSession? = nil
    
    func connect() async throws {
        guard let host = currentHost else {
            throw SSHError.connectionFailed
        }
        
        // Create NMSSH session with host and port
        let session = NMSSHSession.connect(toHost: "\(host.hostname):\(host.port)", withUsername: host.username)
        
        // Authenticate with password
        let isAuthenticated = session.authenticate(byPassword: host.password ?? "")
        
        // Check if connection and authentication were successful
        if session.isConnected && session.isAuthorized {
            self.session = session
            isConnected = true
        } else {
            // Handle connection/authentication failure
            if !session.isConnected {
                throw SSHError.connectionFailedWithDetails("Failed to establish SSH connection to \(host.hostname):\(host.port)")
            } else if !session.isAuthorized {
                throw SSHError.connectionFailedWithDetails("Authentication failed for user \(host.username) on \(host.hostname):\(host.port)")
            }
        }
    }
    
    func disconnect() {
        // Disconnect the NMSSH session if it exists
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
        var error: NSError?
        let output = session.channel.execute(command, error: &error)
        
        // Check for execution errors
        if let error = error {
            throw SSHError.commandExecutionFailed
        }
        
        // Return the command output
        return output ?? ""
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
}
