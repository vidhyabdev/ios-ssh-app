//
//  SSHHostListView.swift
//  ios-ssh-app
//
//  Created by Vidhyashankar Balasubramaniyan on 5/27/26.
//

import SwiftUI

struct SSHHost: Identifiable, Codable {
    let id = UUID()
    let hostName: String
    let hostname: String
    let username: String
    let port: Int
}

struct SSHHostListView: View {
    @StateObject private var hostManager = HostManager()
    
    var body: some View {
        NavigationView {
            List(hostManager.hosts, id: \.id) { host in
                NavigationLink(destination: HostDetailView(host: host)) {
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
            }
            .navigationTitle("SSH Hosts")
            .navigationBarItems(trailing: NavigationLink(destination: AddHostView(hostManager: hostManager)) {
                Image(systemName: "plus")
            })
        }
    }
}

#Preview {
    SSHHostListView()
}
