//
//  FingerprintTrustView.swift
//  ios-ssh-app
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

/// View for displaying and trusting SSH host fingerprints
struct FingerprintTrustView: View {
    let host: SSHHost
    let fingerprint: String
    @Binding var isPresented: Bool
    @State private var trustHost = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Trust This Host?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("The authenticity of host '\(host.hostname):\(host.port)' can't be established.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("RSA key fingerprint is:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(fingerprint)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .monospaced()
                
                // Trust checkbox
                Button(action: { trustHost.toggle() }) {
                    HStack {
                        Image(systemName: trustHost ? "checkmark.square.fill" : "square")
                            .foregroundColor(trustHost ? .blue : .gray)
                        Text("Trust this host")
                    }
                }
                .buttonStyle(.borderless)
                .padding(.top)
                
                HStack {
                    Spacer()
                    
                    Button("Reject") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Trust")
                        .disabled(!trustHost)
                        .buttonStyle(.borderedProminent)
                        .onTapGesture {
                            isPresented = false
                        }
                    
                    Spacer()
                }
                .padding(.top)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Host Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    FingerprintTrustView(
        host: SSHHost(hostName: "Test Server", hostname: "test.example.org", username: "user", port: 22),
        fingerprint: "SHA256:abc123def456",
        isPresented: .constant(true)
    )
}