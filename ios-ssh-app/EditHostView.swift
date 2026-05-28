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
    @State private var password = "" // Temporary password field for SSH testing
    
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
        _password = State(initialValue: hostToEdit.password ?? "") // Initialize with existing password
    }
    
    var body: some View {
        Form {
            Section(header: Text("Host Information")) {
                TextField("Name", text: $hostName)
                TextField("Hostname", text: $hostname)
                TextField("Username", text: $username)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                SecureField("Password (Optional)", text: $password) // Temporary password field for SSH testing
            }
            
            Section {
                Button("Update") {
                    if let portInt = Int(port) {
                        let updatedHost = SSHHost(hostName: hostName, hostname: hostname, username: username, port: portInt, password: password.isEmpty ? nil : password)
                        
                        // Find and replace the host in the array
                        if let index = hostManager.hosts.firstIndex(where: { $0.id == hostToEdit.id }) {
                            hostManager.hosts[index] = updatedHost
                            hostManager.saveHosts()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .disabled(hostName.isEmpty || hostname.isEmpty || username.isEmpty || port.isEmpty)
            }
            
            Section {
                Button("Delete") {
                    if let index = hostManager.hosts.firstIndex(where: { $0.id == hostToEdit.id }) {
                        hostManager.hosts.remove(at: index)
                        hostManager.saveHosts()
                        presentationMode.wrappedValue.dismiss()
                    }
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
