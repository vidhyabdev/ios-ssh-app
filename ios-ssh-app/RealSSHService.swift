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
        
        // Set up host key verification delegate
        session.delegate = self
        
        // Authenticate with password
        let authResult = session.authenticate(byPassword: host.password ?? "")
        
        // Check if connection and authentication were successful
        if session.isConnected && session.isAuthorized {
            self.session = session
            isConnected = true
        } else {
            // Handle connection/authentication failure with more specific errors
            if !session.isConnected {
                // Check for specific connection issues
                if session.connectionError != nil {
                    if session.connectionError!.localizedDescription.contains("timed out") {
                        throw SSHError.timeout
                    } else if session.connectionError!.localizedDescription.contains("unreachable") {
                        throw SSHError.hostUnreachable
                    } else {
                        throw SSHError.connectionFailedWithDetails("Failed to establish SSH connection to \(host.hostname):\(host.port). Connection error: \(session.connectionError!.localizedDescription)")
                    }
                } else {
                    throw SSHError.connectionFailedWithDetails("Failed to establish SSH connection to \(host.hostname):\(host.port)")
                }
            } else if !session.isAuthorized {
                // Check for authentication failure reason
                if authResult == false {
                    // NMSSH authentication failure
                    throw SSHError.authenticationFailed
                } else {
                    throw SSHError.connectionFailedWithDetails("Authentication failed for user \(host.username) on \(host.hostname):\(host.port)")
                }
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
        let output = session.channel.execute(command, error: nil)
        
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
    
    func cancelCommand() {
        // Not implemented in this basic version - can be extended later if needed
    }
}

// MARK: - NMSSHSessionDelegate
extension RealSSHService: NMSSHSessionDelegate {
    func session(_ session: NMSSHSession, didReceiveHostKey key: String) {
        // This delegate method is called when host key is received
        // We could implement trust-on-first-use logic here if needed
        // For now, we'll let NMSSH handle it according to its default behavior
    }
    
    func session(_ session: NMSSHSession, didReceiveAuthenticationBanner banner: String) {
        // Handle authentication banners if needed
    }
    
    func sessionDidDisconnect(_ session: NMSSHSession) {
        // Handle disconnection
    }
}
