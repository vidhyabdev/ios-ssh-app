//
//  AddHostView.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

struct AddHostView: View {
    @State private var hostName = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port = "22"
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var hostManager: HostManager
    
    init(hostManager: HostManager) {
        self.hostManager = hostManager
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Host Information")) {
                    TextField("Name", text: $hostName)
                    TextField("Hostname", text: $hostname)
                    TextField("Username", text: $username)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button("Save") {
                        // Create and add the new host to the list
                        if let portInt = Int(port) {
                            let newHost = SSHHost(hostName: hostName, hostname: hostname, username: username, port: portInt)
                            hostManager.addHost(newHost)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(hostName.isEmpty || hostname.isEmpty || username.isEmpty || port.isEmpty)
                }
            }
            .navigationTitle("Add Host")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    AddHostView(hostManager: HostManager())
}
