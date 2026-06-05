//
//  SnippetsView.swift
//  SSHOpen
//

import SwiftUI

/// Sheet that shows saved command snippets. Tapping one inserts it into the
/// terminal's input field.
struct SnippetsView: View {
    @ObservedObject var manager: SnippetManager
    var onSelect: (String) -> Void

    @State private var showAdd = false
    @State private var editingSnippet: Snippet?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if manager.snippets.isEmpty {
                    ContentUnavailableView(
                        "No Snippets",
                        systemImage: "text.badge.plus",
                        description: Text("Tap + to save a command for quick access.")
                    )
                } else {
                    List {
                        ForEach(manager.snippets) { snippet in
                            Button {
                                onSelect(snippet.command)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(snippet.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(snippet.command)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 3)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    if let idx = manager.snippets.firstIndex(where: { $0.id == snippet.id }) {
                                        manager.delete(at: IndexSet([idx]))
                                    }
                                } label: { Label("Delete", systemImage: "trash") }

                                Button { editingSnippet = snippet } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete { manager.delete(at: $0) }
                        .onMove  { manager.move(from: $0, to: $1) }
                    }
                }
            }
            .navigationTitle("Snippets")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                SnippetEditView(snippet: nil) { name, command in
                    manager.add(name: name, command: command)
                }
            }
            .sheet(item: $editingSnippet) { snippet in
                SnippetEditView(snippet: snippet) { name, command in
                    var updated = snippet
                    updated.name = name
                    updated.command = command
                    manager.update(updated)
                }
            }
        }
    }
}

/// Add / edit form for a single snippet.
struct SnippetEditView: View {
    let snippet: Snippet?
    let onSave: (String, String) -> Void

    @State private var name: String
    @State private var command: String
    @Environment(\.dismiss) private var dismiss

    init(snippet: Snippet?, onSave: @escaping (String, String) -> Void) {
        self.snippet = snippet
        self.onSave = onSave
        _name    = State(initialValue: snippet?.name    ?? "")
        _command = State(initialValue: snippet?.command ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. GPU Status", text: $name)
                }
                Section("Command") {
                    TextField("e.g. nvidia-smi -l 1", text: $command)
                        .font(.system(size: 14, design: .monospaced))
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                }
            }
            .navigationTitle(snippet == nil ? "New Snippet" : "Edit Snippet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces),
                               command.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              command.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
