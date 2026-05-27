//
//  TerminalView.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

struct TerminalView: View {
    let host: SSHHost
    @ObservedObject var hostManager: HostManager
    
    @State private var commandInput = ""
    @State private var terminalOutput = [String]()
    @State private var connectionState: ConnectionState = .disconnected
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal header with host name and connection status
            HStack {
                Text(host.hostName)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(getConnectionStateText())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(getConnectionStateColor())
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            
            // Connection controls
            if connectionState == .disconnected {
                HStack {
                    Button("Connect") {
                        connect()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            } else if connectionState == .connected {
                HStack {
                    Button("Disconnect") {
                        disconnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            
            // Scrollable terminal output area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(terminalOutput, id: \.self) { line in
                            Text(line)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    // Scroll to bottom when content changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(terminalOutput.last ?? "", anchor: .bottom)
                    }
                }
            }
            
            // Command input area
            HStack {
                TextField("Enter command...", text: $commandInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(connectionState != .connected)
                
                Button("Send") {
                    sendCommand()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commandInput.isEmpty || connectionState != .connected)
            }
            .padding()
        }
        .navigationTitle("Terminal")
    }
    
    private func getConnectionStateText() -> String {
        switch connectionState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        }
    }
    
    private func getConnectionStateColor() -> Color {
        switch connectionState {
        case .disconnected:
            return Color.red
        case .connecting:
            return Color.orange
        case .connected:
            return Color.green
        }
    }
    
    private func connect() {
        connectionState = .connecting
        // Simulate connecting process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            connectionState = .connected
            // Add initial connection message
            terminalOutput.append("Connected to \(host.hostName)")
        }
    }
    
    private func disconnect() {
        connectionState = .disconnected
        terminalOutput.removeAll()
    }
    
    private func sendCommand() {
        // Add the command to the terminal output
        let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !command.isEmpty {
            terminalOutput.append("$ \(command)")
            
            // Add a fake response
            let fakeResponse = generateFakeResponse(for: command)
            terminalOutput.append(fakeResponse)
            
            // Clear input
            commandInput = ""
        }
    }
    
    private func generateFakeResponse(for command: String) -> String {
        // Simple mock responses for common commands
        switch command.lowercased() {
        case "ls":
            return "Documents  Downloads  Music  Pictures  Videos"
        case "pwd":
            return "/home/user"
        case "whoami":
            return "user"
        case "date":
            return Date().description
        case "echo":
            return command.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
        case "clear":
            terminalOutput.removeAll()
            return ""
        case "help":
            return "Available commands: ls, pwd, whoami, date, echo, clear, help"
        default:
            return "Command not found: \(command)"
        }
    }
}

#Preview {
    TerminalView(host: SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22), hostManager: HostManager())
}