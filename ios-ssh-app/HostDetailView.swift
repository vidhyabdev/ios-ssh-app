//
//  HostDetailView.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

struct HostDetailView: View {
    let host: SSHHost
    @StateObject private var hostManager = HostManager()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Host Details")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("Name:")
                            .font(.headline)
                        Spacer()
                        Text(host.hostName)
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Text("Hostname:")
                            .font(.headline)
                        Spacer()
                        Text(host.hostname)
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Text("Username:")
                            .font(.headline)
                        Spacer()
                        Text(host.username)
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Text("Port:")
                            .font(.headline)
                        Spacer()
                        Text("\(host.port)")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                NavigationLink(destination: EditHostView(hostManager: hostManager, hostToEdit: host)) {
                    Text("Edit")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .buttonStyle(.borderedProminent)
                }
                
                Button("Connect") {
                    // Placeholder for connection logic
                }
                .disabled(true)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .padding()
        }
        .navigationTitle("Host Details")
    }
}

#Preview {
    HostDetailView(host: SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22))
}