import SwiftUI
import UIKit
import Foundation

// MARK: - Feedback History Data Model
struct FeedbackHistoryItem: Identifiable, Codable {
    let id = UUID()
    let feedback: String
    let language: String
    let timestamp: Date
    let screenshotURL: String?
    let status: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Feedback Manager
class FeedbackManager: ObservableObject {
    @Published var showingFeedbackSheet = false
    @Published var feedbackText = ""
    @Published var screenshot: UIImage?
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var debugInfo = ""
    @Published var feedbackHistory: [FeedbackHistoryItem] = []
    @Published var showingFeedbackHistory = false

    // Debug mode - set to true only for internal team builds
    let debugMode = false

    // Feedback service configuration — set airtableAPIKey via a server-side proxy in production
    // NOTE: airtableAPIKey is intentionally left empty. Set it via a secure configuration mechanism.
    private static let airtableAPIKey = "" // Do NOT hardcode a real key here
    private static let airtableBaseID = "app5caxx3xO8yWqwr"
    private static let airtableTableName = "Med.IA Feedback"
    // Imgur Client-ID for anonymous image uploads — this is a public API credential (not secret)
    private static let imgurClientID = "546c25a59c58ad7"

    // UserDefaults key for storing feedback history
    private let feedbackHistoryKey = "FeedbackHistory"

    init() {
        loadFeedbackHistory()
    }
    
    func takeScreenshot() {
        debugInfo = "" // Reset debug info

        // First try to get a clean screenshot of just the main content without overlays
        if let cleanScreenshot = takeCleanScreenshot() {
            screenshot = cleanScreenshot
            debugInfo += "✅ Clean screenshot captured successfully\n"
            debugInfo += "📐 Size: \(cleanScreenshot.size)\n"
        } else {
            // Fallback to traditional method if clean capture fails
            takeFallbackScreenshot()
            debugInfo += "⚠️ Used fallback screenshot method\n"
        }

        // Add device and orientation info for debugging
        debugInfo += "📱 Device: \(UIDevice.current.model)\n"
        debugInfo += "🔄 Orientation: \(getOrientationString())\n"
        debugInfo += "📏 Screen: \(UIScreen.main.bounds.size)\n"

        if debugMode {
            print("📸 Screenshot Debug Info:\n\(debugInfo)")
        }
    }

    private func getOrientationString() -> String {
        switch UIDevice.current.orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait (Upside Down)"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        default: return "Unknown"
        }
    }

    private func takeCleanScreenshot() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            debugInfo += "❌ Failed to get window scene\n"
            return nil
        }

        // Find the main content window (not including sidebars, sheets, or overlays)
        let windows = windowScene.windows.filter { window in
            // Filter out system windows, sheets, and overlay windows
            return window.isKeyWindow || window.windowLevel == UIWindow.Level.normal
        }

        debugInfo += "🪟 Found \(windows.count) main windows\n"

        guard let mainWindow = windows.first else {
            debugInfo += "❌ No main window found\n"
            return nil
        }

        debugInfo += "🎯 Using window with bounds: \(mainWindow.bounds)\n"

        // Try to find the main content view controller
        if let rootVC = mainWindow.rootViewController {
            debugInfo += "🎮 Root VC: \(type(of: rootVC))\n"
            return captureMainContent(from: rootVC, in: mainWindow)
        }

        debugInfo += "❌ No root view controller found\n"
        return nil
    }

    private func captureMainContent(from viewController: UIViewController, in window: UIWindow) -> UIImage? {
        // Look for the main content view that doesn't include sidebars
        var targetView: UIView = viewController.view
        var vcType = "Base ViewController"

        // Navigate to find the actual content view if we're in a split view or navigation structure
        if let splitVC = viewController as? UISplitViewController,
           let detailVC = splitVC.viewController(for: .secondary) {
            targetView = detailVC.view
            vcType = "Split View (Detail)"
            debugInfo += "📱 iPad Split View detected - using detail view\n"
            debugInfo += "🔧 Split display mode: \(splitVC.displayMode.rawValue)\n"
            debugInfo += "📏 Primary width: \(splitVC.viewController(for: .primary)?.view.frame.width ?? 0)\n"
        } else if let navVC = viewController as? UINavigationController,
                  let topVC = navVC.topViewController {
            targetView = topVC.view
            vcType = "Navigation Controller"
            debugInfo += "🧭 Navigation Controller detected\n"
        } else if let tabVC = viewController as? UITabBarController,
                  let selectedVC = tabVC.selectedViewController {
            targetView = selectedVC.view
            vcType = "Tab Bar Controller"
            debugInfo += "📑 Tab Bar Controller detected\n"
        }

        debugInfo += "🎯 Target view: \(vcType)\n"
        debugInfo += "📐 Target view bounds: \(targetView.bounds)\n"

        // Calculate the safe content bounds (excluding sidebars and system UI)
        let safeFrame = calculateSafeContentFrame(for: targetView, in: window)
        debugInfo += "📦 Safe content frame: \(safeFrame)\n"

        // Create renderer for the safe content area
        let renderer = UIGraphicsImageRenderer(bounds: safeFrame)
        return renderer.image { context in
            // Translate the context to capture only the safe content area
            context.cgContext.translateBy(x: -safeFrame.origin.x, y: -safeFrame.origin.y)
            targetView.drawHierarchy(in: targetView.bounds, afterScreenUpdates: true)
        }
    }

    private func calculateSafeContentFrame(for view: UIView, in window: UIWindow) -> CGRect {
        let windowBounds = window.bounds
        let safeAreaInsets = window.safeAreaInsets

        // Start with full window bounds
        var contentFrame = windowBounds

        // Adjust for safe areas (notch, home indicator, etc.)
        contentFrame.origin.x += safeAreaInsets.left
        contentFrame.origin.y += safeAreaInsets.top
        contentFrame.size.width -= (safeAreaInsets.left + safeAreaInsets.right)
        contentFrame.size.height -= (safeAreaInsets.top + safeAreaInsets.bottom)

        // For iPad, check if we're in a split view configuration and adjust accordingly
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Try to detect sidebar presence by checking view hierarchy
            if let splitViewController = findSplitViewController(from: view) {
                contentFrame = adjustForSplitView(frame: contentFrame, splitVC: splitViewController)
            }
        }

        return contentFrame
    }

    private func findSplitViewController(from view: UIView) -> UISplitViewController? {
        var responder: UIResponder? = view.next
        while responder != nil {
            if let splitVC = responder as? UISplitViewController {
                return splitVC
            }
            responder = responder?.next
        }
        return nil
    }

    private func adjustForSplitView(frame: CGRect, splitVC: UISplitViewController) -> CGRect {
        var adjustedFrame = frame

        // If primary view is visible (sidebar), adjust the content frame
        if !splitVC.isCollapsed && splitVC.displayMode != .secondaryOnly {
            if let primaryWidth = splitVC.viewController(for: .primary)?.view.frame.width,
               primaryWidth > 0 {
                // Sidebar is visible, adjust content frame to exclude it
                adjustedFrame.origin.x += primaryWidth
                adjustedFrame.size.width -= primaryWidth
            }
        }

        return adjustedFrame
    }

    private func takeFallbackScreenshot() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        print("📸 Debug: Using fallback screenshot method")

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        screenshot = renderer.image { context in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
    
    func submitFeedback(language: AppLanguage) {
        // Always save locally first
        addToHistory(language: language, screenshotURL: nil)
        showSuccessMessage(language: language, screenshotURL: nil)

        // Optionally submit to Airtable if configured
        if !Self.airtableAPIKey.isEmpty {
            if screenshot != nil {
                uploadScreenshotThenSubmit(language: language)
            } else {
                submitToAirtable(language: language, screenshotURL: nil)
            }
        }
    }
    
    private func uploadScreenshotThenSubmit(language: AppLanguage) {
        guard let screenshot = screenshot,
              let imageData = screenshot.jpegData(compressionQuality: 0.8) else {
            submitToAirtable(language: language, screenshotURL: nil)
            return
        }
        
        // Upload to Imgur (free image hosting)
        guard let imgurURL = URL(string: "https://api.imgur.com/3/image") else {
            submitToAirtable(language: language, screenshotURL: nil)
            return
        }
        var request = URLRequest(url: imgurURL)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(Self.imgurClientID)", forHTTPHeaderField: "Authorization")
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
        // Use class-level configuration constants — key is validated in submitFeedback() before this is called
        let airtableAPIKey = Self.airtableAPIKey
        let airtableBaseID = Self.airtableBaseID
        let airtableTableName = Self.airtableTableName

        guard !airtableAPIKey.isEmpty else {
            showErrorMessage(language: language, error: "Feedback service not configured")
            return
        }

        guard let url = URL(string: "https://api.airtable.com/v0/\(airtableBaseID)/\(airtableTableName)") else {
            showErrorMessage(language: language, error: "Invalid Airtable URL")
            return
        }

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
                
                if 200...299 ~= httpResponse.statusCode {
                    print("✅ Success! Feedback with screenshot submitted")
                    self?.showSuccessMessage(language: language, screenshotURL: screenshotURL)
                } else {
                    print("❌ Server error: \(httpResponse.statusCode)")
                    self?.showErrorMessage(language: language, error: "Server error: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    private func showSuccessMessage(language: AppLanguage, screenshotURL: String? = nil) {
        alertMessage = language == .portuguese ?
            "Feedback enviado com sucesso! Obrigado pela sua sugestão." :
            "Feedback sent successfully! Thank you for your suggestion."
        showingAlert = true
        addToHistory(language: language, screenshotURL: screenshotURL)
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

    // MARK: - Feedback History Management
    private func loadFeedbackHistory() {
        if let data = UserDefaults.standard.data(forKey: feedbackHistoryKey),
           let history = try? JSONDecoder().decode([FeedbackHistoryItem].self, from: data) {
            feedbackHistory = history.sorted { $0.timestamp > $1.timestamp }
        }
    }

    private func saveFeedbackHistory() {
        if let data = try? JSONEncoder().encode(feedbackHistory) {
            UserDefaults.standard.set(data, forKey: feedbackHistoryKey)
        }
    }

    private func addToHistory(language: AppLanguage, screenshotURL: String?) {
        let historyItem = FeedbackHistoryItem(
            feedback: feedbackText,
            language: language == .portuguese ? "Portuguese" : "English",
            timestamp: Date(),
            screenshotURL: screenshotURL,
            status: "Submitted"
        )

        feedbackHistory.insert(historyItem, at: 0) // Add to beginning for newest first
        saveFeedbackHistory()
    }

    func isDuplicateFeedback(_ text: String) -> Bool {
        return feedbackHistory.contains { $0.feedback.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Generates a formatted text report of all feedback history for sharing.
    func generateFeedbackReport() -> String {
        guard !feedbackHistory.isEmpty else { return "No feedback recorded." }

        var report = "Med.IA 4.0 — Feedback Report\n"
        report += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n"
        report += "Total entries: \(feedbackHistory.count)\n"
        report += String(repeating: "─", count: 40) + "\n\n"

        for (index, item) in feedbackHistory.enumerated() {
            report += "[\(index + 1)] \(item.formattedDate) (\(item.language))\n"
            report += item.feedback + "\n"
            if item.screenshotURL != nil {
                report += "(screenshot attached)\n"
            }
            report += "\n"
        }
        return report
    }

    /// Presents the system share sheet with the feedback report.
    func exportFeedbackReport() {
        let report = generateFeedbackReport()
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let activityVC = UIActivityViewController(activityItems: [report], applicationActivities: nil)
        // iPad popover anchor
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        rootVC.present(activityVC, animated: true)
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

                    // Debug Info for Team (only show if debug mode is enabled)
                    if feedbackManager.debugMode && !feedbackManager.debugInfo.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("🐛 Debug Info (Team Only)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .bold()

                                Spacer()

                                Button("📸 Retake") {
                                    feedbackManager.takeScreenshot()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(feedbackManager.debugInfo)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .frame(maxHeight: 100)
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
                        if feedbackManager.isDuplicateFeedback(feedbackManager.feedbackText) {
                            feedbackManager.alertMessage = language == .portuguese ?
                                "Este feedback já foi enviado anteriormente. Tente algo diferente." :
                                "This feedback has already been sent. Please try something different."
                            feedbackManager.showingAlert = true
                        } else {
                            feedbackManager.submitFeedback(language: language)
                            dismiss()
                        }
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        feedbackManager.showingFeedbackHistory = true
                    }) {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text(language == .portuguese ? "Histórico" : "History")
                        }
                    }
                }
            }
            .sheet(isPresented: $feedbackManager.showingFeedbackHistory) {
                FeedbackHistoryView(feedbackManager: feedbackManager, language: language)
            }
        }
    }
}

// MARK: - Feedback History View
struct FeedbackHistoryView: View {
    @ObservedObject var feedbackManager: FeedbackManager
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if feedbackManager.feedbackHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)

                        Text(language == .portuguese ?
                             "Nenhum feedback enviado ainda" :
                             "No feedback sent yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(language == .portuguese ?
                             "Seus feedbacks aparecerão aqui após o envio" :
                             "Your feedback will appear here after submission")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(feedbackManager.feedbackHistory) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(language == .portuguese ? "Enviado" : "Sent")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(item.feedback)
                                .font(.body)
                                .lineLimit(3)

                            if let screenshotURL = item.screenshotURL {
                                HStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text(language == .portuguese ?
                                         "Incluiu captura de tela" :
                                         "Included screenshot")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }

                            Text("\(language == .portuguese ? "Idioma" : "Language"): \(item.language)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(language == .portuguese ? "Histórico de Feedback" : "Feedback History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !feedbackManager.feedbackHistory.isEmpty {
                        Button(action: {
                            feedbackManager.exportFeedbackReport()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text(language == .portuguese ? "Exportar" : "Export")
                            }
                            .font(.caption)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

