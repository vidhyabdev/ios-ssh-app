//
//  SwiftTermView.swift
//  ios-ssh-app
//
//  Wraps SwiftTerm's UIKit TerminalView in a SwiftUI view so the Interactive
//  PTY mode can render full-screen terminal apps (nvtop, top, htop, vim, tmux)
//  with correct cursor positioning, colors and line-drawing characters.
//

import SwiftUI
import UIKit
import SwiftTerm

/// Bridges PTY output bytes from the SwiftUI layer into the live SwiftTerm
/// terminal instance. Holds only a weak reference so it never keeps the UIView
/// alive past its lifetime.
///
/// Also maintains a rolling plain-text copy buffer (ANSI stripped) so the user
/// can copy recent terminal output to the clipboard.
final class PTYTerminalController: @unchecked Sendable {
    weak var terminalView: SwiftTerm.TerminalView?

    // MARK: - Copy buffer

    private var _copyBuffer = ""
    private let copyBufferMax = 60_000   // ~60 KB rolling window

    // Strips the most common ANSI / VT escape sequences, leaving plain text.
    private static let ansiRegex: NSRegularExpression = {
        // Covers: CSI sequences (colors, cursor), OSC, SS2/SS3, charset designations
        let pattern = "\\x1B(?:[@-Z\\\\-_]|\\[[0-?]*[ -/]*[@-~]|\\][^\\x07\\x1B]*(?:\\x07|\\x1B\\\\))"
        return try! NSRegularExpression(pattern: pattern)
    }()

    private func stripANSI(_ raw: String) -> String {
        let ns = raw as NSString
        return Self.ansiRegex.stringByReplacingMatches(
            in: raw, range: NSRange(location: 0, length: ns.length), withTemplate: ""
        )
        .replacingOccurrences(of: "\r", with: "")   // strip lone CR
    }

    /// Feed raw PTY bytes into the emulator. Safe to call from any thread.
    func feed(_ bytes: [UInt8]) {
        if Thread.isMainThread {
            terminalView?.feed(byteArray: bytes[...])
            appendToBuffer(bytes)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.terminalView?.feed(byteArray: bytes[...])
                self.appendToBuffer(bytes)
            }
        }
    }

    private func appendToBuffer(_ bytes: [UInt8]) {
        guard let raw = String(bytes: bytes, encoding: .utf8) else { return }
        let stripped = stripANSI(raw)
        _copyBuffer += stripped
        if _copyBuffer.count > copyBufferMax {
            _copyBuffer = String(_copyBuffer.suffix(copyBufferMax))
        }
    }

    /// The accumulated plain-text output, suitable for pasting into a text editor.
    var copyableText: String { _copyBuffer }

    /// Wipe the copy buffer (e.g. when the user taps Clear).
    func clearBuffer() { _copyBuffer = "" }

    // MARK: - Size

    /// The terminal's current grid size (cols, rows), if a terminal exists.
    @MainActor
    var size: (cols: Int, rows: Int)? {
        guard let terminal = terminalView?.getTerminal() else { return nil }
        return (terminal.cols, terminal.rows)
    }
}

/// SwiftUI wrapper around `SwiftTerm.TerminalView`.
struct SwiftTermView: UIViewRepresentable {
    let fontSize: CGFloat
    let controller: PTYTerminalController
    /// Called when the terminal wants to send bytes to the host (keystrokes).
    var onSend: (ArraySlice<UInt8>) -> Void
    /// Called when the terminal grid size changes (cols, rows).
    var onSizeChange: (Int, Int) -> Void

    func makeUIView(context: Context) -> SwiftTerm.TerminalView {
        let term = SwiftTerm.TerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        term.terminalDelegate = context.coordinator
        term.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        term.nativeBackgroundColor = .black
        term.nativeForegroundColor = UIColor(white: 0.92, alpha: 1.0)
        term.backgroundColor = .black
        controller.terminalView = term
        return term
    }

    func updateUIView(_ uiView: SwiftTerm.TerminalView, context: Context) {
        if abs(uiView.font.pointSize - fontSize) > 0.5 {
            uiView.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, TerminalViewDelegate {
        let parent: SwiftTermView
        private var lastCols = 0
        private var lastRows = 0

        init(_ parent: SwiftTermView) { self.parent = parent }

        // Terminal -> host: deliver keystrokes/escape sequences to the PTY.
        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            parent.onSend(data)
        }

        // Fired on both client-requested and view-driven (layout) size changes.
        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            guard newCols > 0, newRows > 0,
                  newCols != lastCols || newRows != lastRows else { return }
            lastCols = newCols
            lastRows = newRows
            parent.onSizeChange(newCols, newRows)
        }

        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
        func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}
        func bell(source: SwiftTerm.TerminalView) {}
        func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {}
        func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    }
}
