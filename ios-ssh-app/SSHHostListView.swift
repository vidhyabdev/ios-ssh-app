//
//  SSHHostListView.swift
//  ios-ssh-app
//
//  Created by Vidhyashankar Balasubramaniyan on 5/27/26.
//

import SwiftUI

struct SSHHost: Identifiable {
    let id = UUID()
    let hostName: String
    let hostname: String
    let username: String
    let port: Int
}

struct SSHHostListView: View {
    let hosts = [
        SSHHost(hostName: "Work Server", hostname: "work.company.com", username: "admin", port: 22),
        SSHHost(hostName: "Personal VM", hostname: "192.168.1.100", username: "user", port: 2222),
        SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22),
        SSHHost(hostName: "Backup Server", hostname: "backup.server.net", username: "backupuser", port: 2222)
    ]
    
    var body: some View {
        NavigationView {
            List(hosts, id: \.id) { host in
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.hostName)
                        .font(.headline)
                    HStack {
                        Text("Host: \(host.hostname)")
                        Spacer()
                        Text("Port: \(host.port)")
                    }
                    Text("User: \(host.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("SSH Hosts")
        }
    }
}

#Preview {
    SSHHostListView()
}