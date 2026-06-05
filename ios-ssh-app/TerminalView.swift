//
//  TerminalView.swift
//  ios-ssh-app
//

import SwiftUI

/// Represents a single line of text output (used only in mock-SSH mode).
struct TerminalOutput: Identifiable {
    let id = UUID()
    let text: String
}

struct TerminalView: View {
    let host: SSHHost
    @ObservedObject var hostManager: HostManager
    @State private var selectedBackend: SSHBackend = .default

    @State private var commandInput = ""
    @State private var connectionState: ConnectionState = .disconnected
    @State private var showSettings = false
    @State private var commandHistory = [String]()
    @State private var showHistory = false

    // Terminal preferences
    @State private var selectedTheme: TerminalTheme = .dark
    @State private var selectedFontSize: TerminalFontSize = .medium

    // PTY state — used for Real SSH only
    @State private var isPTYSessionActive = false
    @State private var ptyController = PTYTerminalController()

    // Mock SSH text output fallback
    @State private var mockOutput = [TerminalOutput]()
    @State private var isMockCommandRunning = false
    @State private var isMockAtBottom = true
    private let mockBottomID = "mock-bottom"

    // SSH Service
    @State private var sshService: SSHService

    init(host: SSHHost, hostManager: HostManager) {
        self.host = host
        self.hostManager = hostManager
        let savedBackend = UserDefaults.standard.string(forKey: "SelectedSSHBackend") ?? "mock"
        let backend = SSHBackend(rawValue: savedBackend) ?? .default
        self.selectedBackend = backend
        self._sshService = State(initialValue: backend.createSSHService())
    }

    enum ConnectionState { case disconnected, connecting, connected }

    var body: some View {
        VStack(spacing: 0) {
            banner

            if connectionState == .disconnected {
                Button("Connect") { connect() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                // Show any previous error/status messages while disconnected
                mockOutputView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if connectionState == .connecting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting…").font(monoFont(size: 13))
                }
                .padding(.vertical, 8)
                Spacer()

            } else {
                // Connected
                if sshService is RealSSHService {
                    // ── Real SSH: full SwiftTerm emulator ──
                    SwiftTermView(
                        fontSize: ptyFontSize,
                        controller: ptyController,
                        onSend: { data in
                            (sshService as? RealSSHService)?.sendPTYInputBytes(data)
                        },
                        onSizeChange: { cols, rows in
                            (sshService as? RealSSHService)?.resizePTY(cols: cols, rows: rows)
                        }
                    )
                    .background(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .center) {
                        if !isPTYSessionActive {
                            VStack(spacing: 10) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 36))
                                    .foregroundColor(.gray)
                                Text("Session ended")
                                    .font(monoFont(size: 13))
                                    .foregroundColor(.gray)
                                Button("Reconnect PTY") { startPTY() }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    ctrlKeyBar
                    inputBar
                } else {
                    // ── Mock SSH: text output view ──
                    mockOutputView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    inputBar
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
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

    // MARK: - Banner

    private var banner: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(host.username)@\(host.hostname)")
                    .font(monoFont(size: 12).weight(.semibold))
                    .foregroundColor(.white)
                Text(":\(host.port)  \(host.hostName)")
                    .font(monoFont(size: 10))
                    .foregroundColor(Color(white: 0.6))
            }
            Spacer()
            // PTY active indicator
            if connectionState == .connected && sshService is RealSSHService {
                Circle()
                    .fill(isPTYSessionActive ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
            }
            Text(connectionStateBadge)
                .font(monoFont(size: 10).weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(connectionStateColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
            if connectionState == .connected {
                Button(role: .destructive) { disconnect() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(white: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(white: 0.07))
    }

    // MARK: - Ctrl key bar (Real SSH only)

    private var ctrlKeyBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ctrlButton("Ctrl+C", "\u{03}")
                ctrlButton("Ctrl+D", "\u{04}")
                ctrlButton("Ctrl+Z", "\u{1A}")
                ctrlButton("Ctrl+L", "\u{0C}")
                ctrlButton("Ctrl+B", "\u{02}")
                ctrlButton("Tab",    "\t")
                ctrlButton("Esc",    "\u{1B}")
                ctrlButton("↑",      "\u{1B}[A")
                ctrlButton("↓",      "\u{1B}[B")
                ctrlButton("←",      "\u{1B}[D")
                ctrlButton("→",      "\u{1B}[C")
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 5)
        .background(Color(white: 0.1))
    }

    private func ctrlButton(_ label: String, _ seq: String) -> some View {
        Button(label) {
            (sshService as? RealSSHService)?.sendPTYInput(seq)
        }
        .font(monoFont(size: 12))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.2))
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .disabled(!isPTYSessionActive)
    }

    // MARK: - Mock text output view

    private var mockOutputView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(mockOutput) { line in
                        Text(line.text)
                            .font(monoFont(size: 14))
                            .foregroundColor(.green)
                            .textSelection(.enabled)
                    }
                    Color.clear.frame(height: 1).id(mockBottomID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.containerSize.height >= geo.contentSize.height - 24
            } action: { _, atBottom in isMockAtBottom = atBottom }
            .onChange(of: mockOutput.count) { _, _ in
                guard isMockAtBottom else { return }
                proxy.scrollTo(mockBottomID, anchor: .bottom)
            }
            .overlay(alignment: .bottomTrailing) {
                if !isMockAtBottom {
                    Button {
                        withAnimation { proxy.scrollTo(mockBottomID, anchor: .bottom) }
                        isMockAtBottom = true
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, Color.accentColor)
                            .shadow(radius: 3)
                    }
                    .padding(12)
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Enter command…", text: $commandInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(monoFont(size: 15))
                    .autocapitalization(.none)
                    .autocorrectionDisabled(true)
                    .frame(maxWidth: .infinity)
                    .disabled(isMockCommandRunning)
                    .onSubmit { handleSend() }

                if isMockCommandRunning {
                    Button { stopMockCommand() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                } else {
                    Button { handleSend() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.borderless)
                    .tint(.accentColor)
                    .disabled(commandInput.isEmpty)
                }
            }

            HStack(spacing: 6) {
                actionButton("History", "clock.arrow.circlepath") { showHistory = true }
                actionButton("Paste", "doc.on.clipboard") { pasteFromClipboard() }
                if sshService is RealSSHService {
                    actionButton("Clear", "trash") { clearPTYScreen() }
                        .disabled(!isPTYSessionActive)
                    actionButton("Copy", "doc.on.doc") { copyPTYInput() }
                        .disabled(commandInput.isEmpty)
                } else {
                    actionButton("Clear", "trash") { mockOutput.removeAll() }
                        .disabled(mockOutput.isEmpty)
                    actionButton("Copy", "doc.on.doc") { copyMockOutput() }
                        .disabled(mockOutput.isEmpty)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                List(commandHistory.reversed(), id: \.self) { cmd in
                    Text(cmd).onTapGesture { commandInput = cmd; showHistory = false }
                }
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { showHistory = false }
                    }
                }
            }
        }
    }

    private func actionButton(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon).font(.system(size: 12)).labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Connection

    private func connect() {
        Task {
            connectionState = .connecting
            mockOutput.removeAll()
            do {
                sshService = selectedBackend.createSSHService()
                if let real = sshService as? RealSSHService { real.setHost(host) }
                try await sshService.connect()
                connectionState = .connected
                if sshService is RealSSHService {
                    startPTY()
                } else {
                    mockOutput.append(TerminalOutput(text: "Connected (mock)"))
                }
            } catch {
                connectionState = .disconnected
                mockOutput.append(TerminalOutput(text: "Connection failed: \(error.localizedDescription)"))
            }
        }
    }

    private func disconnect() {
        if let real = sshService as? RealSSHService { real.stopPTYSession() }
        sshService.disconnect()
        isPTYSessionActive = false
        connectionState = .disconnected
        mockOutput.removeAll()
    }

    // MARK: - PTY

    private func startPTY() {
        guard let real = sshService as? RealSSHService else { return }
        isPTYSessionActive = true
        let initial = ptyController.size ?? (cols: 80, rows: 24)
        let ctrl = ptyController
        do {
            try real.startPTYSession(
                cols: initial.cols,
                rows: initial.rows,
                onOutput: { bytes in ctrl.feed(bytes) },
                onEnd: { _ in DispatchQueue.main.async { isPTYSessionActive = false } }
            )
        } catch {
            isPTYSessionActive = false
        }
    }

    // MARK: - Send

    private func handleSend() {
        let text = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        commandInput = ""
        if !commandHistory.contains(text) { commandHistory.append(text) }

        if let real = sshService as? RealSSHService, isPTYSessionActive {
            // PTY: type the command + newline; SwiftTerm shows the echo + output
            real.sendPTYInput(text + "\n")
        } else {
            // Mock: execute command and display output in text view
            runMockCommand(text)
        }
    }

    private func runMockCommand(_ command: String) {
        Task {
            mockOutput.append(TerminalOutput(text: "$ \(command)"))
            isMockCommandRunning = true
            do {
                try await sshService.sendCommandStreaming(command) { output in
                    DispatchQueue.main.async {
                        if !output.isEmpty {
                            mockOutput.append(TerminalOutput(text: output))
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    mockOutput.append(TerminalOutput(text: "Error: \(error.localizedDescription)"))
                }
            }
            isMockCommandRunning = false
        }
    }

    private func stopMockCommand() {
        (sshService as? RealSSHService)?.cancelCommand()
        isMockCommandRunning = false
    }

    private func pasteFromClipboard() {
        if let text = UIPasteboard.general.string { commandInput = text }
    }

    /// Clears the PTY screen by sending the `clear` command (same as Ctrl+L).
    private func clearPTYScreen() {
        (sshService as? RealSSHService)?.sendPTYInput("clear\n")
    }

    /// Copies the current input-field text to the clipboard.
    private func copyPTYInput() {
        guard !commandInput.isEmpty else { return }
        UIPasteboard.general.string = commandInput
    }

    /// Copies all mock text-output lines to the clipboard.
    private func copyMockOutput() {
        UIPasteboard.general.string = mockOutput.map(\.text).joined(separator: "\n")
    }

    // MARK: - Helpers

    private var connectionStateBadge: String {
        switch connectionState {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting"
        case .connected:    return "Connected"
        }
    }

    private var connectionStateColor: Color {
        switch connectionState {
        case .disconnected: return .red
        case .connecting:   return .orange
        case .connected:    return .green
        }
    }

    private var ptyFontSize: CGFloat {
        switch selectedFontSize {
        case .small:  return 11
        case .medium: return 13
        case .large:  return 16
        }
    }

    private func monoFont(size: CGFloat) -> Font {
        let s: CGFloat
        switch selectedFontSize {
        case .small:  s = size * 0.8
        case .medium: s = size
        case .large:  s = size * 1.2
        }
        return .system(size: s, design: .monospaced)
    }

    private func loadPreferences() {
        if let t = UserDefaults.standard.string(forKey: "TerminalTheme") {
            selectedTheme = TerminalTheme(rawValue: t) ?? .dark
        }
        if let f = UserDefaults.standard.string(forKey: "TerminalFontSize") {
            selectedFontSize = TerminalFontSize(rawValue: f) ?? .medium
        }
    }

    private func loadBackendPreference() {
        if let b = UserDefaults.standard.string(forKey: "SelectedSSHBackend") {
            selectedBackend = SSHBackend(rawValue: b) ?? .default
        }
    }
}

#Preview {
    TerminalView(
        host: SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22),
        hostManager: HostManager()
    )
}
