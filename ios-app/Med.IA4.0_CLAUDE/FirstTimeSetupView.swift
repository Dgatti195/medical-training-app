import SwiftUI

struct FirstTimeSetupView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var userName = ""
    @State private var selectedGender: UserGender = .preferNotToSay
    @State private var voiceInputEnabled = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(userProfile.currentLanguage == .portuguese ? 
                             "Configure seu Perfil" : 
                             "Set Up Your Profile")
                            .font(.largeTitle)
                            .bold()
                            .multilineTextAlignment(.center)
                        
                        Text(userProfile.currentLanguage == .portuguese ? 
                             "Complete seu perfil para uma experiência personalizada" :
                             "Complete your profile for a personalized experience")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 24) {
                        // Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text(userProfile.currentLanguage == .portuguese ? "Nome" : "Name")
                                .font(.headline)
                            
                            TextField(
                                userProfile.currentLanguage == .portuguese ? "Digite seu nome" : "Enter your name",
                                text: $userName
                            )
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Gender Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text(userProfile.currentLanguage == .portuguese ? "Gênero" : "Gender")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                ForEach(UserGender.allCases, id: \.self) { gender in
                                    Button(action: {
                                        selectedGender = gender
                                    }) {
                                        HStack {
                                            Image(systemName: gender == .preferNotToSay ? 
                                                  "person.circle.fill" : "person.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(gender == .female ? .pink : .blue)
                                                .frame(width: 40)
                                            
                                            Text(gender.displayName(language: userProfile.currentLanguage))
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: selectedGender == gender ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedGender == gender ? .blue : .gray)
                                        }
                                        .padding()
                                        .background(selectedGender == gender ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // Voice Input Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Text(userProfile.currentLanguage == .portuguese ? 
                                 "Entrada de Voz" : 
                                 "Voice Input")
                                .font(.headline)
                            
                            Toggle(isOn: $voiceInputEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(userProfile.currentLanguage == .portuguese ? 
                                         "Ativar comando de voz" :
                                         "Enable voice commands")
                                        .font(.body)
                                    
                                    Text(userProfile.currentLanguage == .portuguese ? 
                                         "Fale suas perguntas em vez de digitá-las" :
                                         "Speak your questions instead of typing them")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle())
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    
                    // Continue Button
                    Button(action: {
                        saveProfileAndContinue()
                    }) {
                        HStack {
                            Text(userProfile.currentLanguage == .portuguese ? 
                                 "Continuar" : 
                                 "Continue")
                                .font(.headline)
                            
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(userName.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(userName.isEmpty)
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 30)
                }
            }
            .navigationTitle(userProfile.currentLanguage == .portuguese ? "Configuração" : "Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(userProfile.currentLanguage == .portuguese ? "Pular" : "Skip") {
                        skipSetup()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func saveProfileAndContinue() {
        userProfile.profile.userName = userName
        userProfile.profile.userGender = selectedGender
        userProfile.profile.voiceInputEnabled = voiceInputEnabled
        userProfile.profile.isProfileSetupComplete = true
        userProfile.saveProfile()
        dismiss()
    }
    
    private func skipSetup() {
        userProfile.profile.isProfileSetupComplete = true
        userProfile.saveProfile()
        dismiss()
    }
}

#Preview {
    FirstTimeSetupView()
        .environmentObject(UserProfileManager())
}