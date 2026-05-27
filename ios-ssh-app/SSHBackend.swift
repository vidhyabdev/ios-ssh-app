//
//  SSHBackend.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import Foundation

/// Enum representing the available SSH backends
enum SSHBackend: String, CaseIterable, Codable {
    case mock = "mock"
    case real = "real"
    
    /// Returns the display name for the backend
    var displayName: String {
        switch self {
        case .mock:
            return "Mock SSH"
        case .real:
            return "Real SSH"
        }
    }
    
    /// Returns the default backend (MockSSHService)
    static let `default`: SSHBackend = .mock
}

/// Extension to create SSHService instances based on the backend
extension SSHBackend {
    /// Creates an SSHService instance based on the backend type
    func createSSHService() -> SSHService {
        switch self {
        case .mock:
            return MockSSHService()
        case .real:
            return RealSSHService()
        }
    }
}