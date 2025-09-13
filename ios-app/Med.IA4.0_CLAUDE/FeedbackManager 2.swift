import SwiftUI
import UIKit
import Foundation

// MARK: - Feedback Manager
class FeedbackManager: ObservableObject {
    @Published var showingFeedbackSheet = false
    @Published var feedbackText = ""
    @Published var screenshot: UIImage?
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    func takeScreenshot() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        screenshot = renderer.image { context in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
    
    func submitFeedback(language: AppLanguage) {
        if screenshot != nil {
            uploadScreenshotThenSubmit(language: language)
        } else {
            submitToAirtable(language: language, screenshotURL: nil)
        }
    }
    
    private func uploadScreenshotThenSubmit(language: AppLanguage) {
        guard let screenshot = screenshot,
              let imageData = screenshot.jpegData(compressionQuality: 0.8) else {
            submitToAirtable(language: language, screenshotURL: nil)
            return
        }
        
        // Upload to Imgur (free image hosting)
        let imgurURL = URL(string: "https://api.imgur.com/3/image")!
        var request = URLRequest(url: imgurURL)
        request.httpMethod = "POST"
        request.setValue("Client-ID 546c25a59c58ad7", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64String = imageData.base64EncodedString()
        let requestBody: [String: Any] = [
            "image": base64String,
            "type": "base64"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Failed to encode screenshot data")
            submitToAirtable(language: language, screenshotURL: nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                var screenshotURL: String? = nil
                
                if let error = error {
                    print("❌ Screenshot upload network error: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Imgur HTTP Status: \(httpResponse.statusCode)")
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("📄 Imgur response: \(responseString)")
                    }
                    
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataDict = json["data"] as? [String: Any],
                       let link = dataDict["link"] as? String {
                        screenshotURL = link
                        print("📸 Screenshot uploaded: \(link)")
                    } else {
                        print("❌ Screenshot upload failed - invalid response format")
                    }
                }
                
                self?.submitToAirtable(language: language, screenshotURL: screenshotURL)
            }
        }.resume()
    }
    
    private func submitToAirtable(language: AppLanguage, screenshotURL: String?) {
        // Airtable configuration
        let airtableBaseID = "app5caxx3xO8yWqwr"
        let airtableTableName = "Med.IA Feedback"
        let airtableAPIKey = "patvoxSlYC3sTFxbS.f2b036cf4a7afd246aff2867487cab58d0e00d4a8cbd6c80425910cf307f8887"
        
        let url = URL(string: "https://api.airtable.com/v0/\(airtableBaseID)/\(airtableTableName)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(airtableAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        
        // Create record with optional screenshot URL
        var fields: [String: Any] = [
            "Feedback": feedbackText,
            "Language": language == .portuguese ? "Portuguese" : "English",
            "Status": "New"
        ]
        
        if let screenshotURL = screenshotURL {
            fields["Screenshot"] = screenshotURL
        }
        
        let recordData: [String: Any] = [
            "records": [[
                "fields": fields
            ]]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: recordData)
        } catch {
            showErrorMessage(language: language, error: "Failed to prepare data")
            return
        }
        
        // Submit to Airtable
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    self?.showErrorMessage(language: language, error: error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    self?.showErrorMessage(language: language, error: "Invalid response")
                    return
                }
                
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response body: \(responseString)")
                }
                
                if 200...299 ~= httpResponse.statusCode {
                    print("✅ Success! Feedback with screenshot submitted")
                    self?.showSuccessMessage(language: language)
                } else {
                    print("❌ Server error: \(httpResponse.statusCode)")
                    self?.showErrorMessage(language: language, error: "Server error: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    private func showSuccessMessage(language: AppLanguage) {
        alertMessage = language == .portuguese ?
            "Feedback enviado com sucesso! Obrigado pela sua sugestão." :
            "Feedback sent successfully! Thank you for your suggestion."
        showingAlert = true
        resetFeedback()
    }
    
    private func showErrorMessage(language: AppLanguage, error: String) {
        alertMessage = language == .portuguese ?
            "Erro ao enviar feedback. Tente novamente mais tarde." :
            "Error sending feedback. Please try again later."
        showingAlert = true
    }
    
    func resetFeedback() {
        feedbackText = ""
        screenshot = nil
        showingFeedbackSheet = false
    }
}

// MARK: - Feedback Button View
struct FeedbackButton: View {
    @StateObject private var feedbackManager = FeedbackManager()
    let language: AppLanguage
    
    var body: some View {
        Button(action: {
            feedbackManager.takeScreenshot()
            feedbackManager.showingFeedbackSheet = true
        }) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.blue.opacity(0.8))
                .clipShape(Circle())
        }
        .sheet(isPresented: $feedbackManager.showingFeedbackSheet) {
            FeedbackView(feedbackManager: feedbackManager, language: language)
        }
        .alert(language == .portuguese ? "Feedback" : "Feedback", 
               isPresented: $feedbackManager.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(feedbackManager.alertMessage)
        }
    }
}

// MARK: - Feedback View
struct FeedbackView: View {
    @ObservedObject var feedbackManager: FeedbackManager
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text(language == .portuguese ? 
                             "Envie Sugestões" : 
                             "Send Suggestions")
                            .font(.title2)
                            .bold()
                        
                        Text(language == .portuguese ? 
                             "Ajude-nos a melhorar o aplicativo com suas sugestões!" :
                             "Help us improve the app with your suggestions!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Screenshot Preview
                    if let screenshot = feedbackManager.screenshot {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(language == .portuguese ? 
                                 "Captura de Tela (será incluída)" :
                                 "Screenshot (will be included)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Image(uiImage: screenshot)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Feedback Text Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(language == .portuguese ? 
                             "Suas Sugestões" : 
                             "Your Suggestions")
                            .font(.headline)
                        
                        TextEditor(text: $feedbackManager.feedbackText)
                            .frame(height: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Submit Button
                    Button(action: {
                        feedbackManager.submitFeedback(language: language)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text(language == .portuguese ? 
                                 "Enviar Feedback" : 
                                 "Send Feedback")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(feedbackManager.feedbackText.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(feedbackManager.feedbackText.isEmpty)
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle(language == .portuguese ? "Feedback" : "Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language == .portuguese ? "Cancelar" : "Cancel") {
                        feedbackManager.resetFeedback()
                        dismiss()
                    }
                }
            }
        }
    }
}

