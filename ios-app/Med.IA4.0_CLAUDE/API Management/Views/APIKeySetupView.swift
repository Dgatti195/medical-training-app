import SwiftUI

struct APIKeySetupView: View {
    @StateObject private var apiKeyManager = APIKeyManager.shared
    @State private var apiKey: String = ""
    @State private var isSecureEntry: Bool = true
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isLoading: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Claude API Key Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your Claude API key to use AI features in the app")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // API Key Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("API Key")
                        .font(.headline)
                    
                    HStack {
                        Group {
                            if isSecureEntry {
                                SecureField("sk-ant-api03-...", text: $apiKey)
                            } else {
                                TextField("sk-ant-api03-...", text: $apiKey)
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        
                        Button(action: {
                            isSecureEntry.toggle()
                        }) {
                            Image(systemName: isSecureEntry ? "eye" : "eye.slash")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Validation indicator
                    if !apiKey.isEmpty {
                        HStack {
                            Image(systemName: apiKeyManager.isValidAPIKeyFormat(apiKey) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(apiKeyManager.isValidAPIKeyFormat(apiKey) ? .green : .red)
                            
                            Text(apiKeyManager.isValidAPIKeyFormat(apiKey) ? "Valid format" : "Invalid format")
                                .font(.caption)
                                .foregroundColor(apiKeyManager.isValidAPIKeyFormat(apiKey) ? .green : .red)
                        }
                    }
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to get your API key:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Visit console.anthropic.com", systemImage: "1.circle.fill")
                        Label("Sign in to your account", systemImage: "2.circle.fill")
                        Label("Navigate to API Keys section", systemImage: "3.circle.fill")
                        Label("Create a new API key", systemImage: "4.circle.fill")
                        Label("Copy and paste it here", systemImage: "5.circle.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: saveAPIKey) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Saving..." : "Save API Key")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(apiKey.isEmpty || !apiKeyManager.isValidAPIKeyFormat(apiKey) ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(apiKey.isEmpty || !apiKeyManager.isValidAPIKeyFormat(apiKey) || isLoading)
                    
                    Button(action: {
                        if let url = URL(string: "https://console.anthropic.com") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Get API Key from Anthropic")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .foregroundColor(.blue)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Skip") {
                    dismiss()
                }
                .foregroundColor(.gray)
            )
        }
        .alert("API Key Status", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveAPIKey() {
        isLoading = true
        
        // Simulate API validation (optional)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let success = apiKeyManager.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            
            isLoading = false
            
            if success {
                alertMessage = "API key saved successfully! You can now use all AI features."
                showAlert = true
            } else {
                alertMessage = "Failed to save API key. Please try again."
                showAlert = true
            }
        }
    }
}

#Preview {
    APIKeySetupView()
}
