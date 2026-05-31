//
//  FingerprintManager.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import Foundation

/// Manages SSH host fingerprint verification for trust-on-first-use behavior
class FingerprintManager: ObservableObject {
    @Published var needsTrustVerification = false
    @Published var fingerprint: String = ""
    @Published var hostForVerification: SSHHost?
    @Published var trustDecisionMade = false
    
    private let keychainService = KeychainService.shared
    
    /// Check if host fingerprint is trusted
    /// - Parameters:
    ///   - host: The SSH host to check
    ///   - fingerprint: The current fingerprint to verify
    /// - Returns: true if trusted, false if not trusted or fingerprint changed
    func isHostTrusted(_ host: SSHHost, fingerprint: String) -> Bool {
        guard let storedFingerprint = keychainService.getFingerprint(forHost: host) else {
            return false
        }
        return storedFingerprint == fingerprint
    }
    
    /// Check if host has a stored fingerprint
    /// - Parameter host: The SSH host to check
    /// - Returns: true if fingerprint exists, false otherwise
    func hasStoredFingerprint(for host: SSHHost) -> Bool {
        return keychainService.getFingerprint(forHost: host) != nil
    }
    
    /// Store a new host fingerprint (trust-on-first-use)
    /// - Parameters:
    ///   - host: The SSH host
    ///   - fingerprint: The fingerprint to store
    func trustHost(_ host: SSHHost, fingerprint: String) {
        keychainService.saveFingerprint(fingerprint, forHost: host)
    }
    
    /// Remove stored fingerprint for a host (for troubleshooting)
    /// - Parameter host: The SSH host
    func removeFingerprint(for host: SSHHost) {
        keychainService.deleteFingerprint(forHost: host)
    }
}