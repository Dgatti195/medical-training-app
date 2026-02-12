import SwiftUI

struct CleanAnalyticsView: View {
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
                            .foregroundColor(.primary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            AnalyticsCard(
                                title: language == .portuguese ? "Sessões" : "Sessions",
                                value: "\(progressTracker.totalSessionsCompleted)",
                                icon: "list.bullet",
                                color: .blue
                            )

                            AnalyticsCard(
                                title: language == .portuguese ? "Precisão" : "Accuracy",
                                value: String(format: "%.1f%%", progressTracker.averageAccuracy * 100),
                                icon: "target",
                                color: .green
                            )

                            AnalyticsCard(
                                title: language == .portuguese ? "Tempo Total" : "Total Time",
                                value: formatTime(progressTracker.totalStudyTime),
                                icon: "clock",
                                color: .orange
                            )

                            AnalyticsCard(
                                title: language == .portuguese ? "Sequência" : "Streak",
                                value: "\(progressTracker.currentStreak)",
                                icon: "flame.fill",
                                color: .red
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Recent Activity
                    if !progressTracker.dailyProgress.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(language == .portuguese ? "Progresso Recente" : "Recent Progress")
                                .font(.headline)
                                .foregroundColor(.primary)

                            ForEach(progressTracker.dailyProgress.prefix(5), id: \.date) { progress in
                                HStack {
                                    Text(formatDate(progress.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text("\(progress.sessionsCompleted)")
                                        .font(.caption)
                                        .foregroundColor(.primary)

                                    Text(String(format: "%.0f%%", progress.averageAccuracy * 100))
                                        .font(.caption)
                                        .foregroundColor(progress.averageAccuracy > 0.8 ? .green : .orange)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemBackground))
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - StatCard Component
private struct AnalyticsCard: View {
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
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}