import SwiftUI
import Network
import AudioToolbox

// MARK: - UX Enhancement Manager
class UXEnhancementManager: ObservableObject {
    static let shared = UXEnhancementManager()

    // Network monitoring
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .wifi
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var estimatedLoadTime: TimeInterval = 0

    // Loading states
    @Published var showGlobalLoader = false
    @Published var globalLoadingMessage = ""

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case other
        case none

        var displayName: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .other: return "Connected"
            case .none: return "Offline"
            }
        }

        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .other: return "network"
            case .none: return "wifi.slash"
            }
        }
    }

    init() {
        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else if path.status == .satisfied {
                    self?.connectionType = .other
                } else {
                    self?.connectionType = .none
                }
            }
        }

        monitor.start(queue: queue)
    }

    // MARK: - Loading States
    func showLoading(message: String, estimatedTime: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.loadingMessage = message
            self.estimatedLoadTime = estimatedTime

            // Auto hide after estimated time + buffer
            DispatchQueue.main.asyncAfter(deadline: .now() + estimatedTime + 1.0) {
                if self.loadingMessage == message { // Only hide if it's the same message
                    self.hideLoading()
                }
            }
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadingMessage = ""
            self.estimatedLoadTime = 0
        }
    }

    func showGlobalLoader(message: String) {
        DispatchQueue.main.async {
            self.showGlobalLoader = true
            self.globalLoadingMessage = message
        }
    }

    func hideGlobalLoader() {
        DispatchQueue.main.async {
            self.showGlobalLoader = false
            self.globalLoadingMessage = ""
        }
    }

    // MARK: - Haptic Feedback
    func performHapticFeedback(_ style: HapticStyle) {
        switch style {
        case .light:
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        case .medium:
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        case .heavy:
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        case .success:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        case .warning:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        case .error:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        case .selection:
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
    }

    enum HapticStyle {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case selection
    }

    // MARK: - Smart Loading Messages
    func getContextualLoadingMessage(for context: LoadingContext, language: AppLanguage) -> String {
        switch context {
        case .patientData:
            return language == .portuguese ? "Carregando dados do paciente..." : "Loading patient data..."
        case .medicalDatabase:
            return language == .portuguese ? "Carregando base de dados médica..." : "Loading medical database..."
        case .aiAnalysis:
            return language == .portuguese ? "Analisando com IA..." : "Analyzing with AI..."
        case .savingProgress:
            return language == .portuguese ? "Salvando progresso..." : "Saving progress..."
        case .loadingStats:
            return language == .portuguese ? "Carregando estatísticas..." : "Loading statistics..."
        case .searchSuggestions:
            return language == .portuguese ? "Buscando sugestões..." : "Finding suggestions..."
        case .uploadingFeedback:
            return language == .portuguese ? "Enviando feedback..." : "Uploading feedback..."
        }
    }

    enum LoadingContext {
        case patientData
        case medicalDatabase
        case aiAnalysis
        case savingProgress
        case loadingStats
        case searchSuggestions
        case uploadingFeedback
    }

    func getEstimatedLoadTime(for context: LoadingContext) -> TimeInterval {
        switch context {
        case .patientData: return 1.5
        case .medicalDatabase: return 3.0
        case .aiAnalysis: return 4.0
        case .savingProgress: return 0.5
        case .loadingStats: return 2.0
        case .searchSuggestions: return 1.0
        case .uploadingFeedback: return 2.5
        }
    }
}

// MARK: - Loading View Components
struct SmartLoadingView: View {
    let message: String
    let estimatedTime: TimeInterval
    let language: AppLanguage
    @State private var progress: Double = 0
    @State private var currentTip = 0

    private var loadingTips: [String] {
        if language == .portuguese {
            return [
                "Dica: Use os favoritos para acesso rápido",
                "Dica: Tente o modo aleatório para variedade",
                "Dica: Acompanhe seu progresso diário",
                "Dica: Use as sugestões de pesquisa",
                "Dica: Pratique regularmente para melhores resultados"
            ]
        } else {
            return [
                "Tip: Use favorites for quick access",
                "Tip: Try random mode for variety",
                "Tip: Track your daily progress",
                "Tip: Use search suggestions",
                "Tip: Practice regularly for better results"
            ]
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: estimatedTime), value: progress)

                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            VStack(spacing: 12) {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(loadingTips[currentTip])
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            // Progress bar
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(maxWidth: 200)
        }
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .onAppear {
            startProgress()
            startTipRotation()
        }
    }

    private func startProgress() {
        withAnimation(.linear(duration: estimatedTime)) {
            progress = 1.0
        }
    }

    private func startTipRotation() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut) {
                currentTip = (currentTip + 1) % loadingTips.count
            }
        }
    }
}

// MARK: - Network Status Banner
struct NetworkStatusBanner: View {
    @ObservedObject private var uxManager = UXEnhancementManager.shared
    let language: AppLanguage

    var body: some View {
        if !uxManager.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)

                Text(language == .portuguese ? "Sem conexão com a internet" : "No internet connection")
                    .font(.caption)
                    .foregroundColor(.white)
                    .fontWeight(.medium)

                Spacer()

                Text(language == .portuguese ? "Modo Offline" : "Offline Mode")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.red)
            .transition(.move(edge: .top))
        }
    }
}

// MARK: - Connection Status Indicator
struct ConnectionStatusIndicator: View {
    @ObservedObject private var uxManager = UXEnhancementManager.shared
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: uxManager.connectionType.icon)
                .foregroundColor(uxManager.isConnected ? .green : .red)
                .font(.caption2)

            if !uxManager.isConnected {
                Text(language == .portuguese ? "Offline" : "Offline")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Enhanced Button with Haptic Feedback
struct HapticButton<Content: View>: View {
    let action: () -> Void
    let hapticStyle: UXEnhancementManager.HapticStyle
    let content: Content

    private let uxManager = UXEnhancementManager.shared

    init(
        action: @escaping () -> Void,
        hapticStyle: UXEnhancementManager.HapticStyle = .light,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.hapticStyle = hapticStyle
        self.content = content()
    }

    var body: some View {
        Button(action: {
            uxManager.performHapticFeedback(hapticStyle)
            action()
        }) {
            content
        }
    }
}

// MARK: - Global Loading Overlay
struct GlobalLoadingOverlay: View {
    @ObservedObject private var uxManager = UXEnhancementManager.shared
    let language: AppLanguage

    var body: some View {
        if uxManager.showGlobalLoader {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text(uxManager.globalLoadingMessage)
                        .foregroundColor(.white)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Smart Progress Indicator
struct SmartProgressIndicator: View {
    let progress: Double
    let total: Int
    let currentItem: String
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(language == .portuguese ? "Carregando" : "Loading")
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * Double(total)))/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

            Text(currentItem)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}