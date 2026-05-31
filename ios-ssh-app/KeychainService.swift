//
//  KeychainService.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import Foundation
import Security

/// Service for managing SSH passwords in iOS Keychain
class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    /// Generates a stable identifier for a host's password
    private func makeKeychainIdentifier(host: SSHHost) -> String {
        // Use the host.id for the identifier - this ensures the password
        // stays associated with the host even if hostname, username, or port changes
        return "ssh_password_\(host.id.uuidString)"
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
}