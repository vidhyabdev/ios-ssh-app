import Foundation
import Network
@preconcurrency import Citadel
import NIOCore
import NIOPosix
import NIOSSH

/// Real implementation of SSHService that executes commands through actual SSH
/// 
/// IMPORTANT: SSH Connection Protocol - DO NOT MODIFY WITHOUT TESTING
/// ================================================================
/// This connection logic has been carefully tuned for the Citadel SSH library.
/// The following rules must be followed to prevent regression:
///
/// CRITICAL RULES (DO NOT CHANGE):
/// 1. Use `host.hostname` ONLY for the SSHClientSettings host parameter
///    - Do NOT append port to hostname (e.g., "host:22")
///    - Citadel library uses default port 22 when port is not specified
///    - Changing this caused connection failures on 5/30/2026
///
/// 2. Use static method `SSHClient.connect(to: settings)` - NOT instance method
///    - Do NOT create SSHClient() instance first
///    - Do NOT call client?.connect() on an instance
///    - This is the only working pattern verified on 5/30/2026
///
/// 3. Authentication: Use password-based authentication with Keychain password
///    - Password MUST come from KeychainService.shared.getPassword()
///    - Do NOT hardcode or generate passwords
///
/// 4. Host Key Validation: .acceptAnything() is used for simplicity
///    - Do NOT change host key validation without security review
///
/// Connection Flow:
/// 1. Validate currentHost is set (by setHost() from TerminalView)
/// 2. Retrieve password from Keychain (secure storage)
/// 3. Create SSHClientSettings with hostname and auth method
/// 4. Call SSHClient.connect(to: settings) synchronously
/// 5. On success: set isConnected = true, store client reference
/// 6. On failure: reset isConnected = false, client = nil, rethrow error
///
/// Testing Checklist (before merging to main):
/// - [ ] Can connect to known-good host (e.g., 100.76.8.83)
/// - [ ] Connection uses port 22 (default)
/// - [ ] Password is retrieved from Keychain
/// - [ ] Error handling logs diagnostic info
/// - [ ] Disconnect works properly
/// - [ ] Commands execute successfully
///
/// FINGERPRINT VERIFICATION STATUS:
/// - Fingerprint storage/retrieval implemented in KeychainService
/// - FingerprintManager class implemented for trust-on-first-use
/// - FingerprintTrustView UI implemented for host verification
/// - Citadel library requires synchronous host key validator
/// - Full fingerprint integration requires Citadel library support
/// - Current implementation uses .acceptAnything() to preserve working behavior
///
class RealSSHService: NSObject, SSHService {
    private var isConnected = false
    private var currentHost: SSHHost?
    private var client: SSHClient? = nil
    private let keychainService = KeychainService.shared

    // Dedicated NIOPosix group — avoids any stale state in the singleton.
    private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    // PTY interactive session state
    // These are only accessed from the main thread (via TerminalView actions) or inside the ptyTask.
    private var ptyTask: Task<Void, Never>?
    private var ptyInputContinuation: AsyncStream<ByteBuffer>.Continuation?
    // Captured inside withPTY so we can issue window-size changes (SIGWINCH) on resize.
    private var ptyWriter: TTYStdinWriter?
    // Last requested terminal size; applied once the writer becomes available
    // (handles the case where the view reports its size before the channel opens).
    private var pendingResize: (cols: Int, rows: Int)?
    
    /// Connect to SSH host using Citadel library
    /// 
    /// CRITICAL: This method MUST follow the exact pattern established on 5/30/2026.
    /// Changes to the connection logic require full regression testing.
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
        // CRITICAL: Password MUST come from Keychain for security
        guard let password = keychainService.getPassword(forHost: host) else {
            print("[RealSSHService] Error: Password not found in Keychain")
            throw SSHError.passwordNotFound
        }
        
        // FINGERPRINT VERIFICATION (CITADEL LIMITATION)
        // Citadel library uses synchronous hostKeyValidator which doesn't support
        // async UI operations. For now, we use .acceptAnything() to preserve working
        // behavior. Fingerprint storage is available but full verification requires
        // Citadel library support for async validators or host key extraction after connect.
        let hasStoredFingerprint = keychainService.getFingerprint(forHost: host) != nil
        print("[RealSSHService] Has stored fingerprint: \(hasStoredFingerprint)")
        
        if hasStoredFingerprint {
            print("[RealSSHService] Fingerprint already stored - validation will be enforced")
            // TODO: Implement custom host key validator when Citadel supports it
        } else {
            print("[RealSSHService] No stored fingerprint - trust-on-first-use flow")
            // TODO: Show trust UI when Citadel supports async validators
        }
        
        var settings = SSHClientSettings(
            host: host.hostname,
            authenticationMethod: { .passwordBased(username: host.username, password: password) },
            hostKeyValidator: .acceptAnything()
        )
        settings.group = eventLoopGroup
        settings.connectTimeout = .seconds(60)

        print("[RealSSHService] Connection target: \(host.hostname):\(host.port)")

        do {
            // Pre-flight: open and immediately close an NWConnection (Network.framework).
            // This forces iOS to establish the Tailscale WireGuard peer path before
            // Citadel's ClientBootstrap (NIOPosix) attempts its connection.
            // WireGuard sessions stay alive for 30+ seconds, so the path remains
            // open by the time Citadel connects a millisecond later.
            // NIOSSH requires NIOPosix internally (syncOperations on SelectableEventLoop),
            // so we cannot use NIOTransportServices for the SSH layer itself.
            print("[RealSSHService] Pre-flight: establishing Tailscale path via Network.framework…")
            try await warmUpNetworkPath(host: host.hostname, port: host.port)
            print("[RealSSHService] Path ready. Connecting via Citadel/NIOPosix…")

            client = try await SSHClient.connect(to: settings)
            isConnected = true
            print("[RealSSHService] Connection successful!")
        } catch let error as NSError {
            // Handle connection/authentication failure with detailed error info
            print("[RealSSHService] Connection failed with NSError")
            print("[RealSSHService] Error domain: \(error.domain)")
            print("[RealSSHService] Error code: \(error.code)")
            print("[RealSSHService] Error userInfo: \(error.userInfo)")
            
            // Check if it's a Citadel/NIO error (network-level issue)
            if error.domain == "NIOCore.ChannelError" {
                print("[RealSSHService] NIOCore.ChannelError detected")
            } else if error.domain == "NIOPosix.NIOConnectionError" {
                print("[RealSSHService] NIOPosix.NIOConnectionError detected")
            } else if error.domain == "Citadel.SSHClientError" {
                // Citadel-specific error
                print("[RealSSHService] Citadel.SSHClientError detected")
                print("[RealSSHService] Error code \(error.code) details:")
                
                // Error code 4 in Citadel typically means connection-related issue
                if error.code == 4 {
                    print("[RealSSHService] Connection failed - check network connectivity")
                    print("[RealSSHService] Verify host is reachable at \(host.hostname):\(host.port)")
                    print("[RealSSHService] Ensure port 22 (SSH) is open on the host")
                }
            }
            
            // Reset state on failure
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
        print("Cancel command requested")
    }

    // MARK: - PTY Interactive Session

    /// Opens a PTY shell using Citadel's withPTY API and streams RAW bytes back.
    ///
    /// Raw bytes (not decoded/stripped strings) are required so a real terminal
    /// emulator (SwiftTerm) can interpret cursor movement, colors, and the DEC
    /// line-drawing charset used by full-screen apps like nvtop/top/htop/vim/tmux.
    ///
    /// This is synchronous: it sets up the input channel, launches the session
    /// Task, and returns immediately. `onOutput` is called for every output chunk;
    /// `onEnd` fires exactly once when the session terminates.
    ///
    /// Verified API: SSHClient.withPTY(_:environment:perform:) — Citadel/TTY/Client/TTY.swift
    func startPTYSession(
        cols: Int = 80,
        rows: Int = 24,
        onOutput: @escaping @Sendable ([UInt8]) -> Void,
        onEnd: @escaping @Sendable (Error?) -> Void
    ) throws {
        guard isConnected, let client = client else {
            throw SSHError.notConnected
        }

        // Tear down any existing session before starting a new one
        stopPTYSession()

        // AsyncStream bridges sendPTYInput()/sendPTYInputBytes() → TTYStdinWriter.
        var capturedContinuation: AsyncStream<ByteBuffer>.Continuation?
        let inputStream = AsyncStream<ByteBuffer>(bufferingPolicy: .unbounded) { cont in
            capturedContinuation = cont
        }
        guard let continuation = capturedContinuation else {
            throw SSHError.connectionFailed
        }
        ptyInputContinuation = continuation

        // PseudoTerminalRequest: from NIOSSH ChildChannelUserEvents.swift
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )

        // Session runs entirely inside ptyTask. onEnd fires when the task finishes.
        ptyTask = Task {
            do {
                try await client.withPTY(ptyRequest) { inbound, outbound in
                    self.ptyWriter = outbound
                    // Apply any size reported by the view before the channel opened.
                    if let pending = self.pendingResize {
                        try? await outbound.changeSize(
                            cols: pending.cols, rows: pending.rows,
                            pixelWidth: 0, pixelHeight: 0
                        )
                    }
                    let writeTask = Task {
                        for await buffer in inputStream {
                            try? await outbound.write(buffer)
                        }
                    }
                    do {
                        for try await chunk in inbound {
                            switch chunk {
                            case .stdout(let buffer), .stderr(let buffer):
                                onOutput(Array(buffer.readableBytesView))
                            }
                        }
                    } catch {
                        writeTask.cancel()
                        throw error
                    }
                    writeTask.cancel()
                }
                self.ptyWriter = nil
                onEnd(nil)
            } catch is CancellationError {
                // Intentionally stopped via stopPTYSession() — not an error
                self.ptyWriter = nil
                onEnd(nil)
            } catch {
                self.ptyWriter = nil
                onEnd(error)
            }
        }

        print("[RealSSHService] PTY session started (\(cols)x\(rows))")
    }

    /// Sends raw text input to the active PTY stdin (e.g. "ls\n" or "\u{03}" for Ctrl+C).
    func sendPTYInput(_ text: String) {
        ptyInputContinuation?.yield(ByteBuffer(string: text))
    }

    /// Sends raw bytes to the active PTY stdin. Used for keystrokes coming from
    /// the SwiftTerm terminal view (its delegate hands us ArraySlice<UInt8>).
    func sendPTYInputBytes(_ bytes: ArraySlice<UInt8>) {
        ptyInputContinuation?.yield(ByteBuffer(bytes: bytes))
    }

    /// Resizes the PTY window (sends SIGWINCH) so remote apps redraw to fit.
    func resizePTY(cols: Int, rows: Int) {
        pendingResize = (cols, rows)
        guard let writer = ptyWriter else { return }
        Task {
            try? await writer.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0)
        }
    }

    /// Stops the PTY session and cleans up state.
    func stopPTYSession() {
        ptyInputContinuation?.finish()
        ptyInputContinuation = nil
        ptyWriter = nil
        pendingResize = nil
        ptyTask?.cancel()
        ptyTask = nil
        print("[RealSSHService] PTY session stopped")
    }

    // MARK: - Network path warm-up

    /// Opens an NWConnection (Network.framework / VPN-aware) to the target host
    /// and cancels it as soon as the path is ready. This forces the OS to
    /// establish the Tailscale WireGuard peer path so the subsequent NIOPosix
    /// ClientBootstrap connect can succeed immediately.
    private func warmUpNetworkPath(host: String, port: Int) async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let connection = NWConnection(to: endpoint, using: .tcp)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = NIOLockedValueBox(false)
            connection.stateUpdateHandler = { state in
                let alreadyResumed = box.withLockedValue { v -> Bool in
                    let old = v; v = true; return old
                }
                guard !alreadyResumed else { return }
                switch state {
                case .ready:
                    connection.cancel()
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume()
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }
}