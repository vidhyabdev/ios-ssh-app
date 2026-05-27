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
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal header with host name
            HStack {
                Text(host.hostName)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            
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
                
                Button("Send") {
                    sendCommand()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commandInput.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Terminal")
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