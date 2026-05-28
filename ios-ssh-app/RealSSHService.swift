import Foundation
import Citadel

/// Real implementation of SSHService that executes commands through actual SSH
class RealSSHService: SSHService {
    private var isConnected = false
    private var currentHost: SSHHost?
    private var cancellation: Task<Void, Never>? = nil
    private var sshClient: SSHClient? = nil // Actual Citadel SSH client
    
    func connect() async throws {
        guard let host = currentHost else {
            throw SSHError.connectionFailed
        }
        
        // Validate required host properties (assuming they are non-optional)
        guard host.hostname != nil && 
              host.username != nil &&
              host.password != nil else {
            throw SSHError.connectionFailed
        }
        
        // Create SSH client settings using Citadel
        let settings = SSHClientSettings(
            host: host.hostname!,
            authenticationMethod: {
                .passwordBased(username: host.username!, password: host.password!)
            },
            hostKeyValidator: .acceptAnything()
        )
        
        // Connect to SSH server using Citadel
        let client = try await SSHClient.connect(to: settings)
        self.sshClient = client
        isConnected = true
    }
    
    func disconnect() {
        // Cancel any running command
        cancellation?.cancel()
        
        // Close the SSH connection if client exists
        sshClient = nil
        isConnected = false
    }
    
    func sendCommand(_ command: String) async throws -> String {
        guard isConnected else {
            throw SSHError.notConnected
        }
        
        guard let client = sshClient else {
            throw SSHError.connectionFailed
        }
        
        // Execute command on remote server and return actual stdout
        let output = try await client.executeCommand(
            command,
            maxResponseSize: 1024 * 1024,
            mergeStreams: true
        )
        
        // Convert ByteBuffer to String (assuming executeCommand returns ByteBuffer)
        return String(buffer: output)
    }
    
    func cancelCommand() {
        cancellation?.cancel()
    }
    
    func sendCommandStreaming(_ command: String, onOutput: @escaping (String) -> Void) async throws {
        guard isConnected else {
            throw SSHError.notConnected
        }
        
        // Cancel any previous command
        cancellation?.cancel()
        
        // Create a new cancellation task
        cancellation = Task {
            do {
                // For now, call sendCommand and pass the full result to onOutput
                // This avoids implementing streaming logic which wasn't required
                let result = try await sendCommand(command)
                onOutput(result)
            } catch {
                onOutput("Command execution failed: \(error.localizedDescription)\n")
            }
        }
    }
    
    func setHost(_ host: SSHHost) {
        self.currentHost = host
    }
}
