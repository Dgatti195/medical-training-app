import SwiftUI

struct APIKeySettingsView: View {
    @ObservedObject private var apiKeyManager = APIKeyManager.shared
    @State private var showingAPIKeySetup = false
    @State private var showingDeleteAlert = false
    @State private var maskedKey = ""
    
    var body: some View {
        List {
            Section {
                // API Key Status Row
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Claude API Key")
                            .font(.headline)
                        
                        if apiKeyManager.isAPIKeyConfigured {
                            Text("sk-ant-***\(getMaskedKey())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontDesign(.monospaced)
                        } else {
                            Text("Not configured")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                    
                    if apiKeyManager.isAPIKeyConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingAPIKeySetup = true
                }
                
                // Action Buttons
                if apiKeyManager.isAPIKeyConfigured {
                    Button("Update API Key") {
                        showingAPIKeySetup = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Remove API Key") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                } else {
                    Button(action: {
                        print("Add API Key button tapped")
                        showingAPIKeySetup = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add API Key")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(.vertical, 8)
                    }
                    .foregroundColor(.blue)
                }
                
            } header: {
                Text("API Configuration")
            } footer: {
                Text("Your API key is stored securely in the device keychain and never shared with anyone.")
            }
            
            // Usage Information Section
            Section {
                Label("Secure Storage", systemImage: "lock.fill")
                    .foregroundColor(.green)
                Label("Local Processing", systemImage: "iphone")
                    .foregroundColor(.blue)
                Label("No Data Sharing", systemImage: "hand.raised.fill")
                    .foregroundColor(.orange)
            } header: {
                Text("Privacy & Security")
            } footer: {
                Text("All API requests are made directly from your device to Claude's servers. Your conversations and data never pass through our servers.")
            }
        }
        .navigationTitle("API Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                FeedbackButton(language: .english) // TODO: Get current language from environment
            }
        }
        .sheet(isPresented: $showingAPIKeySetup) {
            APIKeySetupView()
                .environmentObject(UserProfileManager())
        }
        .alert("Remove API Key", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                _ = apiKeyManager.removeAPIKey()
            }
        } message: {
            Text("Are you sure you want to remove your API key? You'll need to enter it again to use AI features.")
        }
        .onAppear {
            loadMaskedKey()
            print("API Settings View appeared")
            print("API Key configured: \(apiKeyManager.isAPIKeyConfigured)")
        }
    }
    
    private func getMaskedKey() -> String {
        return maskedKey
    }
    
    private func loadMaskedKey() {
        if let key = apiKeyManager.getAPIKey() {
            // Show last 6 characters
            let suffix = String(key.suffix(6))
            maskedKey = suffix
        }
    }
}
