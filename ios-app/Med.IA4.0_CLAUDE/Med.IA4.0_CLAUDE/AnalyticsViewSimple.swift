import SwiftUI

struct AnalyticsViewSimple: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var progressTracker = ProgressTracker.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var language: AppLanguage {
        userProfile.currentLanguage
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Key Metrics
                    VStack(alignment: .leading, spacing: 16) {
                        Text(language == .portuguese ? "Métricas Principais" : "Key Metrics")
                            .font(.headline)
                            .themedPrimaryText()

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            BasicCard(
                                title: language == .portuguese ? "Sessões" : "Sessions",
                                value: "\(progressTracker.totalSessionsCompleted)",
                                icon: "list.bullet",
                                color: .blue
                            )

                            SimpleCard(
                                title: language == .portuguese ? "Precisão" : "Accuracy",
                                value: String(format: "%.1f%%", progressTracker.averageAccuracy * 100),
                                icon: "target",
                                color: .green
                            )

                            SimpleCard(
                                title: language == .portuguese ? "Tempo Total" : "Total Time",
                                value: formatTime(progressTracker.totalStudyTime),
                                icon: "clock",
                                color: .orange
                            )

                            SimpleCard(
                                title: language == .portuguese ? "Sequência" : "Streak",
                                value: "\(progressTracker.currentStreak)",
                                icon: "flame.fill",
                                color: .red
                            )
                        }
                    }
                    .padding()
                    .themedSurface()
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle(language == .portuguese ? "Análises" : "Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(themeManager.getColorScheme())
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct BasicCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .bold()
                .themedPrimaryText()

            Text(title)
                .font(.caption)
                .themedSecondaryText()
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .themedSurface()
        .cornerRadius(8)
    }
}