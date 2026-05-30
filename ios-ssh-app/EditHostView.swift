//
//  EditHostView.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

struct EditHostView: View {
    @State private var hostName = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port = "22"
    @State private var password = "" // Password will be stored in Keychain
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var hostManager: HostManager
    let hostToEdit: SSHHost
    
    init(hostManager: HostManager, hostToEdit: SSHHost) {
        self.hostManager = hostManager
        self.hostToEdit = hostToEdit
        
        // Initialize with existing values
        _hostName = State(initialValue: hostToEdit.hostName)
        _hostname = State(initialValue: hostToEdit.hostname)
        _username = State(initialValue: hostToEdit.username)
        _port = State(initialValue: "\(hostToEdit.port)")
        // Initialize password from Keychain
        _password = State(initialValue: hostManager.getHostPassword(for: hostToEdit) ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Host Information")) {
                TextField("Name", text: $hostName)
                TextField("Hostname", text: $hostname)
                TextField("Username", text: $username)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                SecureField("Password (Optional)", text: $password)
            }
            
            Section {
                Button("Update") {
                    if let portInt = Int(port) {
                        // Update host in array
                        if let index = hostManager.hosts.firstIndex(where: { $0.id == hostToEdit.id }) {
                            let updatedHost = SSHHost(hostName: hostName, hostname: hostname, username: username, port: portInt)
                            hostManager.hosts[index] = updatedHost
                            hostManager.saveHosts()
                            
                            // Update password in Keychain if provided
                            if !password.isEmpty {
                                hostManager.updateHostPassword(password, for: updatedHost)
                            }
                            
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .disabled(hostName.isEmpty || hostname.isEmpty || username.isEmpty || port.isEmpty)
            }
            
            Section {
                Button("Delete") {
                    hostManager.deleteHost(hostToEdit)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Edit Host")
        .navigationBarItems(trailing: Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

#Preview {
    EditHostView(hostManager: HostManager(), hostToEdit: SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22))
}
