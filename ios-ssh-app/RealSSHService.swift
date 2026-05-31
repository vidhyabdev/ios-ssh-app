import Foundation
import Citadel
import NIOCore

/// Real implementation of SSHService that executes commands through actual SSH
class RealSSHService: NSObject, SSHService {
    private var isConnected = false
    private var currentHost: SSHHost?
    private var client: SSHClient? = nil
    private let keychainService = KeychainService.shared
    
    func connect() async throws {
        print("[RealSSHService] ====== CONNECT DIAGNOSTICS ======")
        guard let host = currentHost else {
            print("[RealSSHService] Error: No current host set")
            throw SSHError.connectionFailed
        }
        
        print("[RealSSHService] Host: \(host.hostName)")
        print("[RealSSHService] Hostname: \(host.hostname)")
        print("[RealSSHService] Port: \(host.port)")
        print("[RealSSHService] Username: \(host.username)")
        
        // Retrieve password from Keychain
        guard let password = keychainService.getPassword(forHost: host) else {
            print("[RealSSHService] Error: Password not found in Keychain")
            throw SSHError.passwordNotFound
        }
        
        print("[RealSSHService] Password found: true")
        print("[RealSSHService] Password length: \(password.count) chars")
        
        // Create SSHClientSettings with host and password authentication
        // Citadel SSHClient expects host:port format in the host parameter
        let hostWithPort = "\(host.hostname):\(host.port)"
        print("[RealSSHService] Connection target: \(hostWithPort)")
        
        let settings = SSHClientSettings(
            host: hostWithPort,
            authenticationMethod: { .passwordBased(username: host.username, password: password) },
            hostKeyValidator: .acceptAnything()
        )
        
        do {
            // Connect to the server
            print("[RealSSHService] Calling SSHClient.connect(to: settings)...")
            client = try await SSHClient.connect(to: settings)
            isConnected = true
            print("[RealSSHService] Connection successful!")
        } catch let error as NSError {
            // Handle connection/authentication failure with detailed error info
            print("[RealSSHService] Connection failed with NSError")
            print("[RealSSHService] Error domain: \(error.domain)")
            print("[RealSSHService] Error code: \(error.code)")
            print("[RealSSHService] Error userInfo: \(error.userInfo)")
            
            // Check if it's a Citadel/NIO error
            if error.domain == "NIOCore.ChannelError" {
                print("[RealSSHService] NIOCore.ChannelError detected")
            } else if error.domain == "NIOPosix.NIOConnectionError" {
                print("[RealSSHService] NIOPosix.NIOConnectionError detected")
            }
            
            // Handle connection/authentication failure
            isConnected = false
            client = nil
            throw error
        } catch {
            // Handle other errors
            print("[RealSSHService] Connection failed with unknown error")
            print("[RealSSHService] Error type: \(type(of: error))")
            print("[RealSSHService] Error description: \(error.localizedDescription)")
            
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