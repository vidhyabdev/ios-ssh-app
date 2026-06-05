//
//  SnippetManager.swift
//  SSHOpen
//

import Foundation
import SwiftUI
import Combine

struct Snippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var command: String
}

class SnippetManager: ObservableObject {
    @Published var snippets: [Snippet] = []
    private let defaultsKey = "SSHOpen.Snippets"

    init() {
        load()
        if snippets.isEmpty { populateDefaults() }
    }

    func add(name: String, command: String) {
        snippets.append(Snippet(name: name, command: command))
        save()
    }

    func update(_ snippet: Snippet) {
        guard let idx = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[idx] = snippet
        save()
    }

    func delete(at offsets: IndexSet) {
        snippets.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        snippets.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data)
        else { return }
        snippets = decoded
    }

    private func populateDefaults() {
        snippets = [
            Snippet(name: "tmux attach",   command: "tmux attach"),
            Snippet(name: "tmux sessions", command: "tmux ls"),
            Snippet(name: "nvtop",         command: "nvtop"),
            Snippet(name: "nvidia-smi",    command: "nvidia-smi"),
            Snippet(name: "GPU watch",     command: "watch -n 1 nvidia-smi"),
            Snippet(name: "htop",          command: "htop"),
            Snippet(name: "Disk usage",    command: "df -h"),
            Snippet(name: "Memory",        command: "free -h"),
            Snippet(name: "Who is logged", command: "who"),
            Snippet(name: "Last logins",   command: "last -n 10"),
        ]
        save()
    }
}
