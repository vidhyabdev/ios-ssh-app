//
//  HostManager.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import Foundation
import SwiftUI

class HostManager: ObservableObject {
    @Published var hosts: [SSHHost] = [
        SSHHost(hostName: "Work Server", hostname: "work.company.com", username: "admin", port: 22),
        SSHHost(hostName: "Personal VM", hostname: "192.168.1.100", username: "user", port: 2222),
        SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22),
        SSHHost(hostName: "Backup Server", hostname: "backup.server.net", username: "backupuser", port: 2222)
    ]
    
    func addHost(_ host: SSHHost) {
        hosts.append(host)
    }
}