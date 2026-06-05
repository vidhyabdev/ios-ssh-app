//
//  TerminalView.swift
//  ios-ssh-app
//

import SwiftUI

/// Represents a single line in the terminal output
struct TerminalOutput: Identifiable {
    let id = UUID()
    let text: String
}

/// Two operating modes for the terminal
enum TerminalMode: String, CaseIterable {
    case command = "Command"
    case interactive = "Interactive PTY"

    var displayName: String { rawValue }
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

    // Terminal mode — command vs interactive PTY
    @State private var terminalMode: TerminalMode = .command
    @State private var isPTYSessionActive = false

    // Scrollback: only auto-follow output when the user is already at the bottom.
    @State private var isAtBottom = true
    private let bottomAnchorID = "terminal-bottom-anchor"

    // SwiftTerm emulator bridge for interactive PTY rendering.
    @State private var ptyController = PTYTerminalController()

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

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }

    var body: some View {
        VStack(spacing: 0) {
            // Session banner
            sessionBanner

            // Connection controls
            connectionControls

            // Mode selector (shown when connected)
            if connectionState == .connected {
                modePicker
            }

            if terminalMode == .interactive && connectionState == .connected {
                // Interactive PTY: control bar + live SwiftTerm emulator.
                // SwiftTerm handles its own keyboard input (tap to type), so the
                // line-based output view and command input bar are not shown here.
                ptyControlBar
                swiftTermArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Command mode (or not yet connected): line-based output + input bar.
                terminalOutputView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                inputBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeBackground.ignoresSafeArea())
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
        .onChange(of: terminalMode) { _, newMode in
            handleModeChange(newMode)
        }
    }

    // MARK: - Sub-views

    private var sessionBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(host.username)@\(host.hostname):\(host.port)")
                    .font(monoFont(size: 12))
                    .foregroundColor(selectedTheme == .dark ? .white : .black)
                Text(host.hostName)
                    .font(monoFont(size: 10))
                    .foregroundColor(selectedTheme == .dark ? .gray : .secondary)
                HStack(spacing: 6) {
                    Text("Backend: \(selectedBackend.displayName)")
                        .font(monoFont(size: 10))
                        .foregroundColor(selectedTheme == .dark ? .blue : .primary)
                    if connectionState == .connected {
                        Text("• \(terminalMode.displayName)")
                            .font(monoFont(size: 10))
                            .foregroundColor(terminalMode == .interactive ? .orange : .green)
                    }
                }
            }
            Spacer()
            Text(connectionStateText)
                .font(monoFont(size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(connectionStateColor)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(selectedTheme == .dark ? Color.black : Color.gray)
    }

    private var connectionControls: some View {
        Group {
            if connectionState == .disconnected {
                Button("Connect") { connect() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
            } else if connectionState == .connecting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting…")
                        .font(monoFont(size: 13))
                }
                .padding(.vertical, 6)
            } else {
                // Connected: compact disconnect strip
                HStack {
                    Spacer()
                    Button(role: .destructive) { disconnect() } label: {
                        Label("Disconnect", systemImage: "xmark.circle.fill")
                            .font(monoFont(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    /// Custom segmented toggle. Replaces SwiftUI's Picker(.segmented) because the
    /// system control renders unselected text dark-on-dark in the dark theme,
    /// making the "Interactive PTY" option effectively invisible.
    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(TerminalMode.allCases, id: \.self) { mode in
                let isSelected = terminalMode == mode
                Button {
                    terminalMode = mode
                } label: {
                    Text(mode.displayName)
                        .font(monoFont(size: 13).weight(isSelected ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor : Color.clear)
                        .foregroundColor(
                            isSelected ? .white : (selectedTheme == .dark ? .white : .primary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(selectedTheme == .dark ? Color(white: 0.18) : Color(white: 0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    /// Control-key shortcuts bar shown only in Interactive PTY mode
    private var ptyControlBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    controlKeyButton("Ctrl+C", char: "\u{03}")
                    controlKeyButton("Ctrl+D", char: "\u{04}")
                    controlKeyButton("Ctrl+Z", char: "\u{1A}")
                    controlKeyButton("Ctrl+L", char: "\u{0C}")
                    controlKeyButton("Ctrl+B", char: "\u{02}")
                    controlKeyButton("Tab", char: "\t")
                    controlKeyButton("Esc", char: "\u{1B}")
                    controlKeyButton("↑", char: "\u{1B}[A")
                    controlKeyButton("↓", char: "\u{1B}[B")
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)
            .background(selectedTheme == .dark ? Color(white: 0.1) : Color(white: 0.9))

            if isPTYSessionActive {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(.orange)
                    Text("PTY session active")
                        .font(monoFont(size: 11))
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Stop PTY") { stopInteractiveMode() }
                        .font(monoFont(size: 11))
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 3)
                .background(selectedTheme == .dark ? Color(white: 0.08) : Color(white: 0.92))
            } else {
                HStack {
                    Image(systemName: "terminal")
                        .foregroundColor(.gray)
                    Text("PTY session inactive")
                        .font(monoFont(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    Button("Start PTY") { startInteractiveMode() }
                        .font(monoFont(size: 11))
                        .buttonStyle(.bordered)
                        .tint(.orange)
                }
                .padding(.horizontal)
                .padding(.vertical, 3)
                .background(selectedTheme == .dark ? Color(white: 0.08) : Color(white: 0.92))
            }
        }
    }

    /// Live terminal emulator for interactive PTY mode.
    private var swiftTermArea: some View {
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
        .overlay(alignment: .center) {
            if !isPTYSessionActive {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("PTY session not running")
                        .font(monoFont(size: 13))
                        .foregroundColor(.gray)
                    Button("Start PTY") { startInteractiveMode() }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                }
            }
        }
    }

    private var ptyFontSize: CGFloat {
        switch selectedFontSize {
        case .small: return 11
        case .medium: return 13
        case .large: return 16
        }
    }

    private var terminalOutputView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(terminalOutput) { line in
                        Text(line.text)
                            .font(monoFont(size: 14))
                            .foregroundColor(selectedTheme == .dark ? .green : .primary)
                            .textSelection(.enabled)
                    }
                    // Invisible anchor used to detect "at bottom" and to scroll to.
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            // Track whether the bottom of the content is currently within view.
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.containerSize.height >= geo.contentSize.height - 24
            } action: { _, atBottom in
                isAtBottom = atBottom
            }
            // Auto-follow only when the user hasn't scrolled up.
            .onChange(of: terminalOutput.count) { _, _ in
                guard isAtBottom else { return }
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            }
            // Floating "jump to bottom" button, shown only when scrolled up.
            .overlay(alignment: .bottomTrailing) {
                if !isAtBottom {
                    Button {
                        withAnimation {
                            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                        }
                        isAtBottom = true
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white, Color.accentColor)
                            .shadow(radius: 3)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            // Row 1: full-width text field + primary Send/Stop button
            HStack(spacing: 8) {
                TextField(
                    terminalMode == .interactive ? "Type input… (↵ sends)" : "Enter command…",
                    text: $commandInput
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(monoFont(size: 15))
                .autocapitalization(.none)
                .autocorrectionDisabled(true)
                .frame(maxWidth: .infinity)
                .disabled(connectionState != .connected || (terminalMode == .command && isCommandRunning))
                .onSubmit { handleSend() }

                if terminalMode == .command && isCommandRunning {
                    Button { stopCommand() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button { handleSend() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.borderless)
                    .tint(terminalMode == .interactive ? .orange : .accentColor)
                    .disabled(commandInput.isEmpty || connectionState != .connected)
                }
            }

            // Row 2: compact secondary action buttons
            HStack(spacing: 6) {
                actionButton("Clear", "trash") { clearTerminal() }
                    .disabled(terminalOutput.isEmpty)
                actionButton("Copy", "doc.on.doc") { copyToClipboard() }
                    .disabled(terminalOutput.isEmpty)
                actionButton("Paste", "doc.on.clipboard") { pasteFromClipboard() }
                if terminalMode == .command {
                    actionButton("History", "clock.arrow.circlepath") { showHistory = true }
                        .disabled(connectionState != .connected || isCommandRunning)
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
                    Text(cmd)
                        .onTapGesture {
                            commandInput = cmd
                            showHistory = false
                        }
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

    /// Compact labeled icon button used for the secondary action row.
    private func actionButton(_ label: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.system(size: 12))
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Control Key Button

    private func controlKeyButton(_ label: String, char: String) -> some View {
        Button(label) {
            guard isPTYSessionActive else { return }
            sendInteractiveInput(char)
        }
        .font(monoFont(size: 12))
        .buttonStyle(.bordered)
        .disabled(!isPTYSessionActive)
    }

    // MARK: - Connection

    private func connect() {
        Task {
            connectionState = .connecting
            do {
                sshService = selectedBackend.createSSHService()
                if let realSSHService = sshService as? RealSSHService {
                    realSSHService.setHost(host)
                }
                try await sshService.connect()
                connectionState = .connected
                terminalOutput.append(TerminalOutput(text: "Connected to \(host.hostName) using \(selectedBackend.displayName)"))

                // Auto-start PTY if we're already in interactive mode
                if terminalMode == .interactive {
                    startInteractiveMode()
                }
            } catch {
                connectionState = .disconnected
                terminalOutput.append(TerminalOutput(text: "Connection failed: \(error.localizedDescription)"))
            }
        }
    }

    private func disconnect() {
        stopInteractiveMode()
        sshService.disconnect()
        connectionState = .disconnected
        terminalOutput.removeAll()
    }

    // MARK: - Mode switching

    private func handleModeChange(_ newMode: TerminalMode) {
        if newMode == .interactive {
            if connectionState == .connected && !isPTYSessionActive {
                startInteractiveMode()
            }
        } else {
            // Switching back to command mode
            stopInteractiveMode()
        }
    }

    // MARK: - Command Mode

    private func handleSend() {
        if terminalMode == .interactive {
            sendInteractiveCommand()
        } else {
            sendCommand()
        }
    }

    private func sendCommand() {
        Task {
            let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { return }

            terminalOutput.append(TerminalOutput(text: "$ \(command)"))
            if !commandHistory.contains(command) {
                commandHistory.append(command)
            }
            commandInput = ""

            if let realSSH = sshService as? RealSSHService {
                isCommandRunning = true
                do {
                    try await realSSH.sendCommandStreaming(command) { output in
                        DispatchQueue.main.async {
                            if !output.isEmpty {
                                terminalOutput.append(TerminalOutput(text: output))
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        terminalOutput.append(TerminalOutput(text: "Error: \(error.localizedDescription)"))
                    }
                }
                isCommandRunning = false
            } else {
                do {
                    let response = try await sshService.sendCommand(command)
                    if !response.isEmpty {
                        terminalOutput.append(TerminalOutput(text: response))
                    }
                } catch {
                    terminalOutput.append(TerminalOutput(text: "Error: \(error.localizedDescription)"))
                }
            }
        }
    }

    private func stopCommand() {
        if let realSSH = sshService as? RealSSHService {
            realSSH.cancelCommand()
        }
        isCommandRunning = false
    }

    // MARK: - Interactive PTY Mode

    private func startInteractiveMode() {
        guard connectionState == .connected else {
            terminalOutput.append(TerminalOutput(text: "⚠ Connect to a host before starting interactive mode"))
            return
        }
        guard let realSSH = sshService as? RealSSHService else {
            terminalOutput.append(TerminalOutput(
                text: "⚠ Interactive PTY requires the Real SSH backend. Switch in Settings."
            ))
            return
        }

        isPTYSessionActive = true

        // Start with the emulator's current grid size if it has laid out already,
        // otherwise a sane default; the view reports its real size shortly after and
        // RealSSHService applies it (SIGWINCH) once the channel is ready.
        let initial = ptyController.size ?? (cols: 80, rows: 24)
        let controller = ptyController

        // Raw PTY bytes are fed straight into the SwiftTerm emulator, which
        // interprets cursor movement, colors and line-drawing characters.
        do {
            try realSSH.startPTYSession(
                cols: initial.cols,
                rows: initial.rows,
                onOutput: { bytes in
                    controller.feed(bytes)
                },
                onEnd: { _ in
                    DispatchQueue.main.async {
                        isPTYSessionActive = false
                    }
                }
            )
        } catch {
            isPTYSessionActive = false
        }
    }

    private func stopInteractiveMode() {
        guard isPTYSessionActive else { return }
        if let realSSH = sshService as? RealSSHService {
            realSSH.stopPTYSession()
        }
        isPTYSessionActive = false
        terminalOutput.append(TerminalOutput(text: "[PTY] Session stopped"))
    }

    /// Sends text input followed by a newline to the active PTY session.
    private func sendInteractiveCommand() {
        let text = commandInput
        guard !text.isEmpty else { return }
        commandInput = ""
        terminalOutput.append(TerminalOutput(text: "> \(text)"))
        sendInteractiveInput(text + "\n")
    }

    /// Sends raw text directly to the PTY stdin (used for control chars and sendInteractiveCommand).
    private func sendInteractiveInput(_ text: String) {
        guard let realSSH = sshService as? RealSSHService else { return }
        realSSH.sendPTYInput(text)
    }

    // MARK: - Helpers

    private var connectionStateText: String {
        switch connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        }
    }

    private var connectionStateColor: Color {
        switch connectionState {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected: return .green
        }
    }

    private var themeBackground: Color {
        selectedTheme == .dark ? Color.black : Color(.systemBackground)
    }

    private func monoFont(size: CGFloat) -> Font {
        let scaled: CGFloat
        switch selectedFontSize {
        case .small: scaled = size * 0.8
        case .medium: scaled = size
        case .large: scaled = size * 1.2
        }
        return Font.system(size: scaled, design: .monospaced)
    }

    // MARK: - Preferences

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

    // MARK: - Terminal Output Operations

    private func clearTerminal() {
        terminalOutput.removeAll()
    }

    private func copyToClipboard() {
        let text = terminalOutput.map { $0.text }.joined(separator: "\n")
        UIPasteboard.general.string = text
    }

    private func pasteFromClipboard() {
        if let pasted = UIPasteboard.general.string {
            commandInput = pasted
        }
    }
}

#Preview {
    TerminalView(
        host: SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "developer", port: 22),
        hostManager: HostManager()
    )
}
