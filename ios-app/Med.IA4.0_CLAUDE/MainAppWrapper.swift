import SwiftUI

struct MainAppWrapper: View {
    @StateObject private var apiKeyManager = APIKeyManager.shared
    @State private var showingAPIKeySetup = false
    @State private var hasCheckedAPIKey = false
    
    var body: some View {
        Group {
            if hasCheckedAPIKey {
                if apiKeyManager.isAPIKeyConfigured {
                    // YOUR EXISTING MAIN VIEW GOES HERE
                    ContentView()
                } else {
                    APIKeyRequiredView()
                }
            } else {
                SplashScreenView()
            }
        }
        .onAppear {
            checkAPIKeyStatus()
        }
    }
    
    private func checkAPIKeyStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            hasCheckedAPIKey = true
        }
    }
}

struct APIKeyRequiredView: View {
    @State private var showingSetup = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                // Use your app's logo here
                Image(systemName: "stethoscope")  // Replace with your app icon
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to Med.IA")  // Replace with your app name
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("AI-Powered Medical Training")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                Text("To get started, you'll need to configure your Claude API key")
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                Text("This enables AI-powered patient interviews and medical training features")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button(action: {
                showingSetup = true
            }) {
                Text("Setup API Key")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showingSetup) {
            APIKeySetupView()
        }
    }
}

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Your app logo
            Image(systemName: "stethoscope")  // Replace with your actual logo
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Med.IA")  // Your app name
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ProgressView()
                .scaleEffect(1.2)
        }
    }
}
