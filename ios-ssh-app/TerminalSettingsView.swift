//
//  TerminalSettingsView.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

struct TerminalSettingsView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTheme: TerminalTheme
    @Binding var selectedFontSize: TerminalFontSize
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(TerminalTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue.capitalized).tag(theme)
                        }
                    }
                    
                    Picker("Font Size", selection: $selectedFontSize) {
                        ForEach(TerminalFontSize.allCases, id: \.self) { fontSize in
                            Text(fontSize.rawValue.capitalized).tag(fontSize)
                        }
                    }
                }
            }
            .navigationTitle("Terminal Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    // Save preferences when saving
                    UserDefaults.standard.set(selectedTheme.rawValue, forKey: "TerminalTheme")
                    UserDefaults.standard.set(selectedFontSize.rawValue, forKey: "TerminalFontSize")
                    isPresented = false
                }
            )
        }
    }
}

enum TerminalTheme: String, CaseIterable, Codable {
    case dark = "dark"
    case light = "light"
}

enum TerminalFontSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
}

#Preview {
    TerminalSettingsView(
        isPresented: .constant(true),
        selectedTheme: .constant(.dark),
        selectedFontSize: .constant(.medium)
    )
}