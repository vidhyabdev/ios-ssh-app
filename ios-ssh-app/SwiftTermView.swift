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
final class PTYTerminalController: @unchecked Sendable {
    weak var terminalView: SwiftTerm.TerminalView?

    /// Feed raw PTY bytes into the emulator. Safe to call from any thread.
    func feed(_ bytes: [UInt8]) {
        if Thread.isMainThread {
            terminalView?.feed(byteArray: bytes[...])
        } else {
            DispatchQueue.main.async { [weak terminalView] in
                terminalView?.feed(byteArray: bytes[...])
            }
        }
    }

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
