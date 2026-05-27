//
//  HostManager.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import Foundation
import SwiftUI
import Combine

class HostManager: ObservableObject {
    @Published var hosts: [SSHHost] = []
    
    private let userDefaultsKey = "SavedSSHHosts"
    
    init() {
        loadHosts()
    }
    
    func addHost(_ host: SSHHost) {
        hosts.append(host)
        saveHosts()
    }
    
    private func saveHosts() {
        if let encoded = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadHosts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedHosts = try? JSONDecoder().decode([SSHHost].self, from: data) {
            hosts = decodedHosts
        } else {
            // If no saved hosts, load sample hosts
            hosts = [
                SSHHost(hostName: "Work Server", hostname: "work.company.com", username: "admin", port: 22),
                SSHHost(hostName: "Personal VM", hostname: "192.168.1.100", username: "user", port: 2222),
                SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22),
                SSHHost(hostName: "Backup Server", hostname: "backup.server.net", username: "backupuser", port: 2222)
            ]
        }
    }
}
