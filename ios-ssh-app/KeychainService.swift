//
//  KeychainService.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import Foundation
import Security
import CryptoKit

/// Service for managing SSH passwords and fingerprints in iOS Keychain
class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    /// Generates a stable identifier for a host's password
    private func makeKeychainIdentifier(host: SSHHost) -> String {
        // Use a combination of hostname and username as the identifier
        // This ensures we can uniquely identify and update passwords
        return "\(host.hostname):\(host.username):\(host.port)"
    }
    
    /// Generates a stable identifier for a host's fingerprint
    private func makeFingerprintIdentifier(host: SSHHost) -> String {
        // Use a combination of hostname and username as the identifier
        // This ensures we can uniquely identify and verify fingerprints
        return "fingerprint:\(host.hostname):\(host.username):\(host.port)"
    }
    
    /// Save a password to the Keychain for a given host
    func savePassword(_ password: String, forHost host: SSHHost) {
        let identifier = makeKeychainIdentifier(host: host)
        
        guard let passwordData = password.data(using: .utf8) else {
            print("Failed to convert password to data")
            return
        }
        
        // Check if an existing record exists
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.vidhyabdev.ios-ssh-app"
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            // Update existing password
            let attributes: [String: Any] = [
                kSecValueData as String: passwordData
            ]
            
            query = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: identifier,
                kSecAttrService as String: "com.vidhyabdev.ios-ssh-app"
            ]
            
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            // Add new password
            let newQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: identifier,
                kSecAttrService as String: "com.vidhyabdev.ios-ssh-app",
                kSecValueData as String: passwordData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]
            
            SecItemAdd(newQuery as CFDictionary, nil)
        }
    }
    
    /// Retrieve a password from the Keychain for a given host
    func getPassword(forHost host: SSHHost) -> String? {
        let identifier = makeKeychainIdentifier(host: host)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.vidhyabdev.ios-ssh-app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    /// Update password for an existing host
    func updatePassword(_ password: String, forHost host: SSHHost) {
        // First delete the old password, then save the new one
        deletePassword(forHost: host)
        savePassword(password, forHost: host)
    }
    
    /// Delete password from the Keychain for a given host
    func deletePassword(forHost host: SSHHost) {
        let identifier = makeKeychainIdentifier(host: host)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.vidhyabdev.ios-ssh-app"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Fingerprint Management
    
    /// Save a host fingerprint to the Keychain
    func saveFingerprint(_ fingerprint: String, forHost host: SSHHost) {
        let identifier = makeFingerprintIdentifier(host: host)
        
        guard let fingerprintData = fingerprint.data(using: .utf8) else {
            print("Failed to convert fingerprint to data")
            return
        }
        
        // Check if an existing record exists
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.vidhyabdev.ios-ssh-app"
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            // Update existing fingerprint
            let attributes: [String: Any] = [
                kSecValueData as String: fingerprintData
            ]
            
            query = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: identifier,
                kSecAttrService as String: "com.vidhyabdev.ios-ssh-app"
            ]
            
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            // Add new fingerprint
            let newQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: identifier,
                kSecAttrService as String: "com.vidhyabdev.ios-ssh-app",
                kSecValueData as String: fingerprintData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]
            
            SecItemAdd(newQuery as CFDictionary, nil)
        }
    }
    
    /// Retrieve a fingerprint from the Keychain for a given host
    func getFingerprint(forHost host: SSHHost) -> String? {
        let identifier = makeFingerprintIdentifier(host: host)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.vidhyabdev.ios-ssh-app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    /// Delete fingerprint from the Keychain for a given host
    func deleteFingerprint(forHost host: SSHHost) {
        let identifier = makeFingerprintIdentifier(host: host)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.vidhyabdev.ios-ssh-app"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    /// Set a fingerprint for a host (used for first-time trust or manual entry)
    /// - Parameters:
    ///   - fingerprint: The fingerprint string
    ///   - host: The SSH host
    func setFingerprint(_ fingerprint: String, forHost host: SSHHost) {
        saveFingerprint(fingerprint, forHost: host)
        print("[KeychainService] Fingerprint saved for \(host.hostname):\(host.port)")
    }
    
    /// Generate a fingerprint from a host key string
    /// Uses SHA-256 hash to create a consistent fingerprint
    static func generateFingerprint(from hostKey: String) -> String {
        // For now, use a simple SHA-256 hash
        // In production, use proper SSH key fingerprinting
        guard let data = hostKey.data(using: .utf8) else {
            return "Invalid"
        }
        
        // Generate SHA-256 hash
        let sha256 = CryptoKit.SHA256.hash(data: data)
        
        // Format as hex string with colons (like SSH)
        let hex = sha256.withUnsafeBytes { buffer in
            (0..<32).map { String(format: "%02x", buffer.load(fromByteOffset: $0, as: UInt8.self)) }.joined(separator: ":")
        }
        return hex
    }
}
