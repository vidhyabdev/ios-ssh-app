//
//  TerminalView.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

/// Represents a single line in the terminal output
struct TerminalOutput: Identifiable {
    let id = UUID()
    let text: String
}

struct TerminalView: View {
    let host: SSHHost
    @ObservedObject var hostManager: HostManager
    @State private var selectedBackend: SSHBackend = .default
    
    @State private var commandInput = ""
    @State private var terminalOutput = [TerminalOutput]()
    @State private var connectionState: ConnectionState = .disconnected
    @State private var showHistory = false
    @State private var commandHistory = [String]()
    @State private var showSettings = false
    @State private var isCommandRunning = false
    
    // Terminal preferences
    @State private var selectedTheme: TerminalTheme = .dark
    @State private var selectedFontSize: TerminalFontSize = .medium
    
    // SSH Service
    @State private var sshService: SSHService
    
    init(host: SSHHost, hostManager: HostManager) {
        self.host = host
        self.hostManager = hostManager
        // Load backend preference first
        let savedBackend = UserDefaults.standard.string(forKey: "SelectedSSHBackend") ?? "mock"
        let backend = SSHBackend(rawValue: savedBackend) ?? .default
        // Set the selectedBackend property first
        self.selectedBackend = backend
        // Initialize sshService with the selected backend
        self._sshService = State(initialValue: backend.createSSHService())
    }
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    var body: some View {
        VStack(spacing: 0) {
// Session banner with host information
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(host.username)@\(host.hostname):\(host.port)")
                        .font(getFont(for: selectedFontSize, size: 12))
                        .foregroundColor(selectedTheme == .dark ? .white : .black)
                    Text(host.hostName)
                        .font(getFont(for: selectedFontSize, size: 10))
                        .foregroundColor(selectedTheme == .dark ? .gray : .secondary)
                    Text("Backend: \(selectedBackend.displayName)")
                        .font(getFont(for: selectedFontSize, size: 10))
                        .foregroundColor(selectedTheme == .dark ? .blue : .primary)
                }
                Spacer()
                Text(getConnectionStateText())
                    .font(getFont(for: selectedFontSize, size: 10))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(getConnectionStateColor())
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(selectedTheme == .dark ? Color.black : Color.gray)
            
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
                        ForEach(terminalOutput) { line in
                            Text(line.text)
                                .font(getFont(for: selectedFontSize, size: 14))
                                .foregroundColor(selectedTheme == .dark ? .green : .primary)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    // Scroll to bottom when content changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let lastLine = terminalOutput.last {
                            proxy.scrollTo(lastLine.id, anchor: .bottom)
                        }
                    }
                }
            }
            
             // Command input area
             HStack {
                  TextField("Enter command...", text: $commandInput)
                      .textFieldStyle(RoundedBorderTextFieldStyle())
                      .font(getFont(for: selectedFontSize, size: 14))
                      .autocapitalization(.none)
                      .autocorrectionDisabled(true)
                      .disabled(connectionState != .connected || isCommandRunning)
                 
                 Button("Clear") {
                     clearTerminal()
                 }
                 .buttonStyle(.bordered)
                 .font(getFont(for: selectedFontSize, size: 14))
                 .disabled(terminalOutput.isEmpty)
                 
                 Button("Copy") {
                     copyToClipboard()
                 }
                 .buttonStyle(.bordered)
                 .font(getFont(for: selectedFontSize, size: 14))
                 .disabled(terminalOutput.isEmpty)
                 
                 Button("Paste") {
                     pasteFromClipboard()
                 }
                 .buttonStyle(.bordered)
                 .font(getFont(for: selectedFontSize, size: 14))
                 
                 Button("History") {
                     showHistory = true
                 }
                 .buttonStyle(.bordered)
                 .font(getFont(for: selectedFontSize, size: 14))
                 .disabled(connectionState != .connected || isCommandRunning)
                 
                 if isCommandRunning {
                     Button("Stop") {
                         stopCommand()
                     }
                     .buttonStyle(.borderedProminent)
                     .font(getFont(for: selectedFontSize, size: 14))
                 } else {
                     Button("Send") {
                         sendCommand()
                     }
                     .buttonStyle(.borderedProminent)
                     .font(getFont(for: selectedFontSize, size: 14))
                     .disabled(commandInput.isEmpty || connectionState != .connected)
                 }
             }
             .padding()
            
            // History sheet
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    List(commandHistory.reversed(), id: \.self) { command in
                        Text(command)
                            .onTapGesture {
                                commandInput = command
                                showHistory = false
                            }
                    }
                    .navigationTitle("History")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                showHistory = false
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Terminal")
        .navigationBarItems(trailing: Button("Settings") {
            showSettings = true
        })
.onAppear {
            loadPreferences()
            loadBackendPreference()
        }
.sheet(isPresented: $showSettings) {
            TerminalSettingsView(
                isPresented: $showSettings,
                selectedTheme: $selectedTheme,
                selectedFontSize: $selectedFontSize,
                selectedBackend: $selectedBackend
            )
        }
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
    
    private func getFont(for fontSize: TerminalFontSize, size: CGFloat) -> Font {
        switch fontSize {
        case .small:
            return Font.system(size: size * 0.8, design: .monospaced)
        case .medium:
            return Font.system(size: size, design: .monospaced)
        case .large:
            return Font.system(size: size * 1.2, design: .monospaced)
        }
    }
    
    private func connect() {
        Task {
            connectionState = .connecting
            do {
                // Recreate SSH service with selected backend
                sshService = selectedBackend.createSSHService()
                
                // For RealSSHService, we need to set the host
                if let realSSHService = sshService as? RealSSHService {
                    realSSHService.setHost(host)
                }
                
                try await sshService.connect()
                connectionState = .connected
                // Add initial connection message
                terminalOutput.append(TerminalOutput(text: "Connected to \(host.hostName) using \(selectedBackend.displayName)"))
            } catch {
                // Handle connection error
                connectionState = .disconnected
                terminalOutput.append(TerminalOutput(text: "Connection failed: \(error.localizedDescription)"))
            }
        }
    }
    
    private func disconnect() {
        sshService.disconnect()
        connectionState = .disconnected
        terminalOutput.removeAll()
    }
    
    private func sendCommand() {
        Task {
            // Add the command to the terminal output
            let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !command.isEmpty {
                terminalOutput.append(TerminalOutput(text: "$ \(command)"))
                
                // Add to command history
                if !commandHistory.contains(command) {
                    commandHistory.append(command)
                }
                
                 // Check if the service supports streaming
                 if let streamingService = sshService as? RealSSHService {
                     // For streaming services, we'll handle output incrementally
                     isCommandRunning = true
                     // Start the streaming command asynchronously
                     do {
try await streamingService.sendCommandStreaming(command) { output in
                              DispatchQueue.main.async {
                                  if !output.isEmpty {
                                      terminalOutput.append(TerminalOutput(text: output))
                                  }
                              }
                          }
                         // Command finished, set running flag to false
                         isCommandRunning = false
                     } catch {
                         DispatchQueue.main.async {
                             terminalOutput.append(TerminalOutput(text: "Error: \(error.localizedDescription)"))
                             isCommandRunning = false
                         }
                     }
                 } else {
                     // For non-streaming services (like MockSSHService), use existing behavior
                     do {
                         let response = try await sshService.sendCommand(command)
                         if !response.isEmpty {
                             terminalOutput.append(TerminalOutput(text: response))
                         }
                     } catch {
                         terminalOutput.append(TerminalOutput(text: "Error: \(error.localizedDescription)"))
                     }
                 }
                
                // Clear input
                commandInput = ""
            }
        }
    }
    
    private func stopCommand() {
        // Cancel the ongoing command if there is one
        if let streamingService = sshService as? RealSSHService {
            streamingService.cancelCommand()
        }
        isCommandRunning = false
    }
    
// Removed the generateFakeResponse function as it's now handled by MockSSHService
    
    // MARK: - Preferences Management
    private func loadPreferences() {
        // Load theme preference
        if let savedTheme = UserDefaults.standard.string(forKey: "TerminalTheme") {
            selectedTheme = TerminalTheme(rawValue: savedTheme) ?? .dark
        }
        
        // Load font size preference
        if let savedFontSize = UserDefaults.standard.string(forKey: "TerminalFontSize") {
            selectedFontSize = TerminalFontSize(rawValue: savedFontSize) ?? .medium
        }
    }
    
private func savePreferences() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: "TerminalTheme")
        UserDefaults.standard.set(selectedFontSize.rawValue, forKey: "TerminalFontSize")
    }
    
    private func loadBackendPreference() {
        // Load backend preference
        if let savedBackend = UserDefaults.standard.string(forKey: "SelectedSSHBackend") {
            selectedBackend = SSHBackend(rawValue: savedBackend) ?? .default
        }
    }
    
    // MARK: - Terminal Output Operations
    private func clearTerminal() {
        terminalOutput.removeAll()
    }
    
    private func copyToClipboard() {
        let outputText = terminalOutput.map { $0.text }.joined(separator: "\n")
        UIPasteboard.general.string = outputText
        print("Copied \(terminalOutput.count) lines to clipboard")
    }
    
    private func pasteFromClipboard() {
        if let pastedText = UIPasteboard.general.string {
            commandInput = pastedText
            print("Pasted \(pastedText.count) characters to command input")
        }
    }
}

#Preview {
    TerminalView(host: SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22), hostManager: HostManager())
}
