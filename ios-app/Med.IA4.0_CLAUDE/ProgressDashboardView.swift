import SwiftUI
import Charts

// MARK: - Progress Dashboard View
struct ProgressDashboardView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var progressTracker = ProgressTracker.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var language: AppLanguage {
        userProfile.currentLanguage
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak Section
                    StreakCardView(
                        currentStreak: progressTracker.currentStreak,
                        longestStreak: progressTracker.longestStreak,
                        language: language
                    )

                    // Today's Progress
                    TodayProgressCard(
                        progress: progressTracker.todayProgress,
                        language: language
                    )

                    // Weekly Goals
                    WeeklyGoalsSection(
                        goals: progressTracker.weeklyGoals,
                        language: language
                    )

                    // Weekly Chart
                    WeeklyProgressChart(
                        progressData: progressTracker.getLastSevenDaysProgress(),
                        language: language
                    )

                    // Quick Stats
                    WeeklyStatsCard(
                        stats: progressTracker.getWeeklyStats(),
                        language: language
                    )
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(language == .portuguese ? "Progresso" : "Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Streak Card View
struct StreakCardView: View {
    let currentStreak: Int
    let longestStreak: Int
    let language: AppLanguage

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    Text(language == .portuguese ? "Sequência Atual" : "Current Streak")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Text("\(currentStreak) \(language == .portuguese ? "dias" : "days")")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)

                Text("\(language == .portuguese ? "Recorde:" : "Best:") \(longestStreak) \(language == .portuguese ? "dias" : "days")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Streak visualization
            VStack {
                ForEach(0..<min(currentStreak, 7), id: \.self) { _ in
                    Circle()
                        .fill(.orange)
                        .frame(width: 12, height: 12)
                }
                if currentStreak > 7 {
                    Text("+\(currentStreak - 7)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Today's Progress Card
struct TodayProgressCard: View {
    let progress: DailyProgress
    let language: AppLanguage
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text(language == .portuguese ? "Progresso de Hoje" : "Today's Progress")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 4 : 2), spacing: 16) {
                ProgressMetricCard(
                    title: language == .portuguese ? "Sessões" : "Sessions",
                    value: "\(progress.sessionsCompleted)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                ProgressMetricCard(
                    title: language == .portuguese ? "Tempo" : "Time",
                    value: progress.formattedStudyTime,
                    icon: "clock.fill",
                    color: .blue
                )

                ProgressMetricCard(
                    title: language == .portuguese ? "Condições" : "Conditions",
                    value: "\(progress.conditionsStudied.count)",
                    icon: "brain.head.profile",
                    color: .purple
                )

                ProgressMetricCard(
                    title: language == .portuguese ? "Precisão" : "Accuracy",
                    value: String(format: "%.0f%%", progress.averageAccuracy),
                    icon: "target",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Progress Metric Card
struct ProgressMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Weekly Goals Section
struct WeeklyGoalsSection: View {
    let goals: [WeeklyGoal]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundColor(.green)
                    .font(.title2)
                Text(language == .portuguese ? "Metas da Semana" : "Weekly Goals")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(goals) { goal in
                    WeeklyGoalRow(goal: goal, language: language)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Weekly Goal Row
struct WeeklyGoalRow: View {
    let goal: WeeklyGoal
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(goal.currentProgress)/\(goal.targetValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: goal.progressPercentage / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: goal.isCompleted ? .green : .blue))

            if goal.isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(language == .portuguese ? "Concluído!" : "Completed!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Weekly Progress Chart
struct WeeklyProgressChart: View {
    let progressData: [DailyProgress]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.indigo)
                    .font(.title2)
                Text(language == .portuguese ? "Progresso da Semana" : "Weekly Progress")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            // Simple bar chart representation
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(progressData.enumerated()), id: \.offset) { index, progress in
                    VStack {
                        Rectangle()
                            .fill(progress.sessionsCompleted > 0 ? .blue : .gray.opacity(0.3))
                            .frame(width: 30, height: max(CGFloat(progress.sessionsCompleted * 20), 5))
                            .cornerRadius(4)

                        Text(dayOfWeek(for: progress.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .portuguese ? "pt_BR" : "en_US")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

// MARK: - Weekly Stats Card
struct WeeklyStatsCard: View {
    let stats: (totalSessions: Int, totalTime: TimeInterval, uniqueConditions: Int, avgAccuracy: Double)
    let language: AppLanguage
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.cyan)
                    .font(.title2)
                Text(language == .portuguese ? "Estatísticas da Semana" : "Weekly Statistics")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 4 : 2), spacing: 16) {
                StatRow(
                    title: language == .portuguese ? "Total de Sessões" : "Total Sessions",
                    value: "\(stats.totalSessions)"
                )

                StatRow(
                    title: language == .portuguese ? "Tempo Total" : "Total Time",
                    value: formatTime(stats.totalTime)
                )

                StatRow(
                    title: language == .portuguese ? "Condições Únicas" : "Unique Conditions",
                    value: "\(stats.uniqueConditions)"
                )

                StatRow(
                    title: language == .portuguese ? "Precisão Média" : "Average Accuracy",
                    value: String(format: "%.1f%%", stats.avgAccuracy)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}