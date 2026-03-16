import SwiftUI

// MARK: - User Profile View
struct UserProfileView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        Image(systemName: userProfile.profile.userGender == .preferNotToSay ?
                              "person.circle.fill" : "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(userProfile.profile.userGender == .female ? .pink : .blue)

                        Text(userProfile.profile.userName.isEmpty ?
                             (userProfile.currentLanguage == .portuguese ? "Perfil" : "Profile") :
                             userProfile.profile.userName)
                            .font(.largeTitle)
                            .bold()

                        if !userProfile.profile.userName.isEmpty {
                            Text(userProfile.profile.userGender.displayName(language: userProfile.currentLanguage))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Profile Information
                    if !userProfile.profile.userName.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(userProfile.currentLanguage == .portuguese ? "Informações do Perfil" : "Profile Information")
                                .font(.headline)

                            VStack(spacing: 8) {
                                HStack {
                                    Text(userProfile.currentLanguage == .portuguese ? "Nome:" : "Name:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(userProfile.profile.userName)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text(userProfile.currentLanguage == .portuguese ? "Gênero:" : "Gender:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(userProfile.profile.userGender.displayName(language: userProfile.currentLanguage))
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text(userProfile.currentLanguage == .portuguese ? "Entrada de Voz:" : "Voice Input:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(userProfile.profile.voiceInputEnabled ?
                                         (userProfile.currentLanguage == .portuguese ? "Ativado" : "Enabled") :
                                         (userProfile.currentLanguage == .portuguese ? "Desativado" : "Disabled"))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // Language Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text(userProfile.currentLanguage == .portuguese ? "Configurações" : "Settings")
                            .font(.headline)

                        HStack {
                            Text(userProfile.currentLanguage == .portuguese ? "Idioma:" : "Language:")
                            Spacer()
                            Picker("Language", selection: Binding(
                                get: { userProfile.currentLanguage },
                                set: { userProfile.changeLanguage($0) }
                            )) {
                                ForEach(AppLanguage.allCases, id: \.self) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        Divider()
                            .padding(.vertical, 4)

                        // Training Mode Setting
                        VStack(alignment: .leading, spacing: 8) {
                            Text(userProfile.currentLanguage == .portuguese ? "Nível de Treinamento:" : "Training Level:")
                                .fontWeight(.medium)

                            Text(userProfile.currentLanguage == .portuguese ?
                                 "Escolha seu modo padrão de treinamento" :
                                 "Choose your default training mode")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                TrainingModeButton(
                                    mode: .basic,
                                    isSelected: userProfile.profile.preferredTrainingMode == .basic,
                                    language: userProfile.currentLanguage,
                                    action: { userProfile.setTrainingMode(.basic) }
                                )

                                TrainingModeButton(
                                    mode: .clinical,
                                    isSelected: userProfile.profile.preferredTrainingMode == .clinical,
                                    language: userProfile.currentLanguage,
                                    action: { userProfile.setTrainingMode(.clinical) }
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    // Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        Text(userProfile.currentLanguage == .portuguese ? "Estatísticas" : "Statistics")
                            .font(.headline)

                        VStack(spacing: 12) {
                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Pacientes Entrevistados" : "Patients Interviewed",
                                value: "\(userProfile.profile.totalPatientsInterviewed)",
                                color: .blue
                            )

                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Diagnósticos Tentados" : "Diagnoses Attempted",
                                value: "\(userProfile.profile.totalDiagnosesAttempted)",
                                color: .orange
                            )

                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Precisão Total" : "Total Accuracy",
                                value: String(format: "%.1f%%", userProfile.profile.accuracyPercentage),
                                color: userProfile.profile.accuracyPercentage >= 70 ? .green : .orange
                            )

                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Dicas Usadas" : "Hints Used",
                                value: "\(userProfile.profile.hintsUsed)",
                                color: .yellow
                            )

                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Exames Solicitados" : "Tests Ordered",
                                value: "\(userProfile.profile.testsOrdered)",
                                color: .purple
                            )

                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Tempo de Estudo" : "Study Time",
                                value: formatStudyTime(userProfile.profile.studyTime),
                                color: .green
                            )
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(userProfile.currentLanguage == .portuguese ? "Perfil" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    FeedbackButton(language: userProfile.currentLanguage)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !userProfile.profile.userName.isEmpty {
                            Button(userProfile.currentLanguage == .portuguese ? "Editar" : "Edit") {
                                // Reset profile setup to allow editing
                                userProfile.profile.isProfileSetupComplete = false
                                userProfile.saveProfile()
                                dismiss()
                            }
                            .foregroundColor(.blue)
                        }

                        Button(userProfile.currentLanguage == .portuguese ? "Concluído" : "Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func formatStudyTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Helper Views
struct TrainingModeButton: View {
    let mode: TrainingMode
    let isSelected: Bool
    let language: AppLanguage
    let action: () -> Void

    private var iconName: String {
        mode == .basic ? "list.clipboard" : "stethoscope"
    }

    private var modeTitle: String {
        if mode == .basic {
            return language == .portuguese ? "Básico" : "Basic"
        } else {
            return language == .portuguese ? "Clínico" : "Clinical"
        }
    }

    private var modeSubtitle: String {
        if mode == .basic {
            return language == .portuguese ? "Anamnese" : "History Taking"
        } else {
            return language == .portuguese ? "Diagnóstico" : "Diagnosis"
        }
    }

    private var backgroundColor: Color {
        if !isSelected {
            return Color.gray.opacity(0.1)
        }
        return mode == .basic ? Color.green.opacity(0.2) : Color.blue.opacity(0.2)
    }

    private var strokeColor: Color {
        if !isSelected {
            return Color.clear
        }
        return mode == .basic ? Color.green : Color.blue
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)

                Text(modeTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(modeSubtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(strokeColor, lineWidth: 2)
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("trainingMode_\(mode == .basic ? "basic" : "clinical")")
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .bold()
                    .foregroundColor(color)
            }
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Performance Analytics Visualization Components

struct PerformanceChartView: View {
    let weeklyProgress: [WeeklyProgress]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Progresso Semanal" : "Weekly Progress")
                .font(.headline)
                .foregroundColor(.primary)

            if weeklyProgress.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text(language == .portuguese ?
                         "Complete mais sessões para ver seu progresso" :
                         "Complete more sessions to see your progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(weeklyProgress) { week in
                            WeekProgressBar(
                                week: week,
                                language: language
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeekProgressBar: View {
    let week: WeeklyProgress
    let language: AppLanguage

    private var weekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(weekFormatter.string(from: week.weekStartDate))
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accuracyColor)
                    .frame(width: 20, height: max(4, week.averageAccuracy * 1.5))

                Text("\(Int(week.averageAccuracy))%")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(height: 150, alignment: .bottom)

            Text("\(week.totalSessions)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var accuracyColor: Color {
        switch week.averageAccuracy {
        case 80...100: return .green
        case 60...79: return .blue
        case 40...59: return .orange
        default: return .red
        }
    }
}

struct MetricsOverviewView: View {
    let metrics: PerformanceMetrics
    let language: AppLanguage
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Métricas Detalhadas" : "Detailed Metrics")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 4 : 2), spacing: 12) {
                MetricCard(
                    title: language == .portuguese ? "Tempo Médio" : "Avg Response",
                    value: formatTime(metrics.averageResponseTime),
                    icon: "clock",
                    color: .blue
                )

                MetricCard(
                    title: language == .portuguese ? "Perguntas/Caso" : "Questions/Case",
                    value: String(format: "%.1f", metrics.averageQuestionsPerCase),
                    icon: "questionmark.circle",
                    color: .orange
                )

                MetricCard(
                    title: language == .portuguese ? "Confiança" : "Confidence",
                    value: String(format: "%.0f%%", metrics.averageConfidenceScore * 100),
                    icon: "gauge",
                    color: .green
                )

                MetricCard(
                    title: language == .portuguese ? "Consistência" : "Consistency",
                    value: String(format: "%.0f%%", metrics.consistencyScore * 100),
                    icon: "chart.line.flattrend.xyaxis",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        if timeInterval < 60 {
            return String(format: "%.0fs", timeInterval)
        } else {
            let minutes = Int(timeInterval / 60)
            let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
}

struct MetricCard: View {
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
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct CategoryPerformanceView: View {
    let categoryStats: [String: CategoryStats]
    let strongCategories: [String]
    let weakCategories: [String]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Performance por Categoria" : "Performance by Category")
                .font(.headline)

            if categoryStats.isEmpty {
                Text(language == .portuguese ?
                     "Complete mais casos para ver a análise por categoria" :
                     "Complete more cases to see category analysis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    if !strongCategories.isEmpty {
                        CategorySection(
                            title: language == .portuguese ? "Pontos Fortes" : "Strong Areas",
                            categories: strongCategories,
                            categoryStats: categoryStats,
                            color: .green,
                            icon: "checkmark.circle.fill"
                        )
                    }

                    if !weakCategories.isEmpty {
                        CategorySection(
                            title: language == .portuguese ? "Áreas a Melhorar" : "Areas to Improve",
                            categories: weakCategories,
                            categoryStats: categoryStats,
                            color: .orange,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CategorySection: View {
    let title: String
    let categories: [String]
    let categoryStats: [String: CategoryStats]
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .bold()
            }

            VStack(spacing: 4) {
                ForEach(categories, id: \.self) { category in
                    if let stats = categoryStats[category] {
                        HStack {
                            Text(category)
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f%%", stats.accuracy))
                                .font(.caption)
                                .bold()
                                .foregroundColor(color)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct LearningInsightsView: View {
    let insights: [LearningInsight]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Insights de Aprendizado" : "Learning Insights")
                .font(.headline)

            if insights.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)

                    Text(language == .portuguese ?
                         "Complete mais sessões para receber insights personalizados" :
                         "Complete more sessions to receive personalized insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(insights.prefix(3)) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InsightCard: View {
    let insight: LearningInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(insight.priority.color)
                    .frame(width: 8, height: 8)

                Text(insight.title)
                    .font(.subheadline)
                    .bold()

                Spacer()

                Text(insightTypeIcon)
                    .font(.caption)
            }

            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(insight.recommendation)
                .font(.caption)
                .italic()
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }

    private var insightTypeIcon: String {
        switch insight.insightType {
        case .performance: return "📊"
        case .learning: return "🧠"
        case .efficiency: return "⚡"
        case .knowledge: return "📚"
        case .behavior: return "🎯"
        case .performanceDecline: return "📉"
        case .questioningStrategy: return "❓"
        case .learningVelocity: return "🚀"
        }
    }
}

// MARK: - Enhanced Analytics Dashboard

struct AnalyticsDashboardView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @State private var selectedTab = 0
    @State private var timeRange: TimeRange = .month

    private let tabsData: [(titleEN: String, titlePT: String, icon: String)] = [
        (titleEN: "Overview", titlePT: "Visão Geral", icon: "chart.bar"),
        (titleEN: "Progress", titlePT: "Progresso", icon: "chart.line.uptrend.xyaxis"),
        (titleEN: "Insights", titlePT: "Insights", icon: "lightbulb")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time Range Selector
                timeRangeSelector

                // Tab Selection
                tabSelector

                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedTab {
                        case 0:
                            overviewContent
                        case 1:
                            progressContent
                        case 2:
                            insightsContent
                        default:
                            overviewContent
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(userProfile.currentLanguage == .portuguese ? "Análise Detalhada" : "Detailed Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var timeRangeSelector: some View {
        HStack {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    timeRange = range
                }) {
                    Text(range.displayName(language: userProfile.currentLanguage))
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(timeRange == range ? Color.blue : Color.clear)
                        .foregroundColor(timeRange == range ? .white : .blue)
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var tabSelector: some View {
        HStack {
            ForEach(0..<3) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabsData[index].icon)
                            .font(.title2)
                        Text(userProfile.currentLanguage == .portuguese ?
                             getPortugueseTabTitle(index) :
                             getEnglishTabTitle(index))
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == index ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }

    private func getEnglishTabTitle(_ index: Int) -> String {
        guard index < tabsData.count else { return "Overview" }
        return tabsData[index].titleEN
    }

    private func getPortugueseTabTitle(_ index: Int) -> String {
        guard index < tabsData.count else { return "Visão Geral" }
        return tabsData[index].titlePT
    }

    @ViewBuilder
    private var overviewContent: some View {
        // Current Performance Summary
        PerformanceSummaryCard(
            profile: userProfile.profile,
            language: userProfile.currentLanguage
        )

        // Quick Metrics
        MetricsOverviewView(
            metrics: userProfile.profile.performanceMetrics,
            language: userProfile.currentLanguage
        )

        // Category Performance
        CategoryPerformanceView(
            categoryStats: userProfile.profile.categoryPerformance,
            strongCategories: userProfile.profile.performanceMetrics.strongCategories,
            weakCategories: userProfile.profile.performanceMetrics.weakCategories,
            language: userProfile.currentLanguage
        )

        // Recent Session History
        RecentSessionsView(
            sessions: Array(userProfile.profile.sessions.suffix(5)),
            language: userProfile.currentLanguage
        )
    }

    @ViewBuilder
    private var progressContent: some View {
        // Weekly Progress Chart
        PerformanceChartView(
            weeklyProgress: userProfile.profile.weeklyProgress,
            language: userProfile.currentLanguage
        )

        // Difficulty Progression
        DifficultyProgressionView(
            sessions: userProfile.profile.sessions,
            language: userProfile.currentLanguage
        )

        // Category Improvement Trends (task 5.1)
        CategoryTrendsView(
            sessions: userProfile.profile.sessions,
            language: userProfile.currentLanguage
        )

        // Improvement Trends
        ImprovementTrendsView(
            metrics: userProfile.profile.performanceMetrics,
            weeklyProgress: userProfile.profile.weeklyProgress,
            language: userProfile.currentLanguage
        )
    }

    @ViewBuilder
    private var insightsContent: some View {
        // Learning Insights
        LearningInsightsView(
            insights: userProfile.profile.learningInsights,
            language: userProfile.currentLanguage
        )

        // Performance Recommendations
        RecommendationsView(
            metrics: userProfile.profile.performanceMetrics,
            categoryStats: userProfile.profile.categoryPerformance,
            language: userProfile.currentLanguage
        )

        // Weakest Areas Detail (task 5.1)
        WeakestAreasActionView(
            weakCategories: userProfile.profile.performanceMetrics.weakCategories,
            categoryStats: userProfile.profile.categoryPerformance,
            language: userProfile.currentLanguage
        )

        // Goal Setting
        GoalSettingView(
            currentLevel: userProfile.profile.overallDifficultyLevel,
            language: userProfile.currentLanguage
        )
    }
}

enum TimeRange: String, CaseIterable {
    case week = "week"
    case month = "month"
    case threeMonths = "three_months"
    case year = "year"

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .week:
            return language == .portuguese ? "Semana" : "Week"
        case .month:
            return language == .portuguese ? "Mês" : "Month"
        case .threeMonths:
            return language == .portuguese ? "3 Meses" : "3 Months"
        case .year:
            return language == .portuguese ? "Ano" : "Year"
        }
    }
}

struct PerformanceSummaryCard: View {
    let profile: UserProfile
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(language == .portuguese ? "Desempenho Atual" : "Current Performance")
                        .font(.headline)
                    Text(performanceLevel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                performanceIndicator
            }

            HStack(spacing: 20) {
                StatItemView(
                    title: language == .portuguese ? "Precisão" : "Accuracy",
                    value: String(format: "%.0f%%", profile.accuracyPercentage),
                    trend: accuracyTrend
                )

                Divider()

                StatItemView(
                    title: language == .portuguese ? "Sessões" : "Sessions",
                    value: "\(profile.sessions.count)",
                    trend: .stable
                )

                Divider()

                StatItemView(
                    title: language == .portuguese ? "Nível" : "Level",
                    value: profile.overallDifficultyLevel.displayName(language: language),
                    trend: .improving
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private var performanceLevel: String {
        let accuracy = profile.accuracyPercentage

        switch accuracy {
        case 90...100:
            return language == .portuguese ? "Excelente" : "Excellent"
        case 80..<90:
            return language == .portuguese ? "Muito Bom" : "Very Good"
        case 70..<80:
            return language == .portuguese ? "Bom" : "Good"
        case 60..<70:
            return language == .portuguese ? "Regular" : "Average"
        default:
            return language == .portuguese ? "Precisa Melhorar" : "Needs Improvement"
        }
    }

    private var performanceIndicator: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            Circle()
                .trim(from: 0, to: profile.accuracyPercentage / 100)
                .stroke(performanceColor, lineWidth: 8)
                .rotationEffect(.degrees(-90))

            Text("\(Int(profile.accuracyPercentage))")
                .font(.title2)
                .bold()
                .foregroundColor(performanceColor)
        }
        .frame(width: 60, height: 60)
    }

    private var performanceColor: Color {
        let accuracy = profile.accuracyPercentage
        switch accuracy {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var accuracyTrend: TrendDirection {
        guard profile.weeklyProgress.count >= 2 else { return .stable }

        let recent = profile.weeklyProgress.suffix(2)
        let current = recent.last?.averageAccuracy ?? 0
        let previous = recent.first?.averageAccuracy ?? 0

        if current > previous + 5 { return .improving }
        else if current < previous - 5 { return .declining }
        else { return .stable }
    }
}

struct StatItemView: View {
    let title: String
    let value: String
    let trend: TrendDirection

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .bold()

            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentSessionsView: View {
    let sessions: [SessionData]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Sessões Recentes" : "Recent Sessions")
                .font(.headline)

            if sessions.isEmpty {
                Text(language == .portuguese ?
                     "Nenhuma sessão completada ainda" :
                     "No completed sessions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sessions) { session in
                        SessionRowView(session: session, language: language)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SessionRowView: View {
    let session: SessionData
    let language: AppLanguage

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.diseaseCategory)
                    .font(.caption)
                    .bold()

                Text(dateFormatter.string(from: session.startTime))
                    .font(.caption2)
                    .foregroundColor(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: session.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(session.isCorrect ? .green : .red)

                Text(formatDuration(session.duration))
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%dm %ds", minutes, seconds)
    }
}

// MARK: - Additional Analytics Components

struct DifficultyProgressionView: View {
    let sessions: [SessionData]
    let language: AppLanguage
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Progressão de Dificuldade" : "Difficulty Progression")
                .font(.headline)

            if sessions.isEmpty {
                Text(language == .portuguese ?
                     "Complete mais sessões para ver a progressão" :
                     "Complete more sessions to see progression")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let difficultyBreakdown = calculateDifficultyBreakdown()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 4 : 2), spacing: 12) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        let count = difficultyBreakdown[level] ?? 0
                        let accuracy = calculateAccuracyForLevel(level)

                        DifficultyCard(
                            level: level,
                            count: count,
                            accuracy: accuracy,
                            language: language
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func calculateDifficultyBreakdown() -> [DifficultyLevel: Int] {
        var breakdown: [DifficultyLevel: Int] = [:]

        for session in sessions where session.completionStatus == .completed {
            breakdown[session.difficulty, default: 0] += 1
        }

        return breakdown
    }

    private func calculateAccuracyForLevel(_ level: DifficultyLevel) -> Double {
        let levelSessions = sessions.filter { $0.difficulty == level && $0.completionStatus == .completed }
        guard !levelSessions.isEmpty else { return 0 }

        let correctCount = levelSessions.filter { $0.isCorrect }.count
        return Double(correctCount) / Double(levelSessions.count) * 100
    }
}

struct DifficultyCard: View {
    let level: DifficultyLevel
    let count: Int
    let accuracy: Double
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 8) {
            Text(level.displayName(language: language))
                .font(.caption)
                .bold()

            Text("\(count)")
                .font(.title2)
                .bold()
                .foregroundColor(levelColor)

            Text(language == .portuguese ? "casos" : "cases")
                .font(.caption2)
                .foregroundColor(.secondary)

            if count > 0 {
                Text(String(format: language == .portuguese ? "%.0f%% precisão" : "%.0f%% accuracy", accuracy))
                    .font(.caption2)
                    .foregroundColor(accuracyColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }

    private var levelColor: Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }

    private var accuracyColor: Color {
        switch accuracy {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct ImprovementTrendsView: View {
    let metrics: PerformanceMetrics
    let weeklyProgress: [WeeklyProgress]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Tendências de Melhoria" : "Improvement Trends")
                .font(.headline)

            VStack(spacing: 12) {
                TrendRow(
                    title: language == .portuguese ? "Taxa de Melhoria" : "Improvement Rate",
                    value: String(format: "%.1f%%", metrics.improvementRate * 100),
                    trend: getTrendForImprovementRate(metrics.improvementRate),
                    icon: "chart.line.uptrend.xyaxis"
                )

                TrendRow(
                    title: language == .portuguese ? "Consistência" : "Consistency",
                    value: String(format: "%.1f%%", metrics.consistencyScore * 100),
                    trend: getTrendForConsistencyScore(metrics.consistencyScore),
                    icon: "chart.line.flattrend.xyaxis"
                )

                TrendRow(
                    title: language == .portuguese ? "Eficiência Diagnóstica" : "Diagnostic Efficiency",
                    value: String(format: "%.2f", metrics.diagnosticEfficiency),
                    trend: metrics.diagnosticEfficiency > 1.0 ? .improving : .stable,
                    icon: "gauge"
                )

                if metrics.avgTimeToDiagnosis > 0 {
                    TrendRow(
                        title: language == .portuguese ? "Tempo p/ Diagnóstico" : "Time to Diagnosis",
                        value: formatDiagnosisTime(metrics.avgTimeToDiagnosis),
                        trend: timeToDiagnosisTrend(metrics.avgTimeToDiagnosis),
                        icon: "timer"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func timeToDiagnosisTrend(_ avgTime: TimeInterval) -> TrendDirection {
        if avgTime <= 0 { return .stable }
        if avgTime < 180 { return .improving }   // < 3 min is fast
        if avgTime > 360 { return .declining }   // > 6 min is slow
        return .stable
    }

    private func formatDiagnosisTime(_ timeInterval: TimeInterval) -> String {
        guard timeInterval > 0 else { return "–" }
        let minutes = Int(timeInterval / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        if minutes == 0 { return String(format: "%ds", seconds) }
        return String(format: "%dm %ds", minutes, seconds)
    }

    private func getTrendForImprovementRate(_ rate: Double) -> TrendDirection {
        if rate > 0 {
            return .improving
        } else if rate < 0 {
            return .declining
        } else {
            return .stable
        }
    }

    private func getTrendForConsistencyScore(_ score: Double) -> TrendDirection {
        if score > 0.7 {
            return .improving
        } else if score < 0.5 {
            return .declining
        } else {
            return .stable
        }
    }
}

struct TrendRow: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.headline)
                    .bold()
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)

                Text(trendText)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    private var trendText: String {
        switch trend {
        case .improving: return "↗"
        case .declining: return "↘"
        case .stable: return "→"
        }
    }
}

// MARK: - Category Trends (task 5.1)
struct CategoryTrendData {
    let category: String
    let recentAccuracy: Double
    let previousAccuracy: Double
    let totalSessions: Int

    var direction: TrendDirection {
        let diff = recentAccuracy - previousAccuracy
        if diff > 0.1 { return .improving }
        if diff < -0.1 { return .declining }
        return .stable
    }
}

struct CategoryTrendsView: View {
    let sessions: [SessionData]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Tendências por Categoria" : "Trends by Category")
                .font(.headline)

            let trends = computeCategoryTrends()

            if trends.isEmpty {
                Text(language == .portuguese ?
                     "Faça pelo menos 4 casos em uma categoria para ver tendências" :
                     "Complete at least 4 cases in a category to see trends")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(trends, id: \.category) { trend in
                        CategoryTrendRow(trend: trend, language: language)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func computeCategoryTrends() -> [CategoryTrendData] {
        let completed = sessions.filter { $0.completionStatus == .completed }
        var grouped: [String: [SessionData]] = [:]
        for session in completed {
            grouped[session.diseaseCategory, default: []].append(session)
        }

        var trends: [CategoryTrendData] = []
        for (category, catSessions) in grouped {
            guard catSessions.count >= 2 else { continue }
            let sorted = catSessions.sorted { $0.startTime < $1.startTime }
            let half = sorted.count / 2
            let firstHalf = Array(sorted.prefix(half))
            let secondHalf = Array(sorted.suffix(half))

            let prevCount = Double(firstHalf.filter { $0.isCorrect }.count)
            let recentCount = Double(secondHalf.filter { $0.isCorrect }.count)
            let prevAccuracy = prevCount / Double(firstHalf.count)
            let recentAccuracy = recentCount / Double(secondHalf.count)

            trends.append(CategoryTrendData(
                category: category,
                recentAccuracy: recentAccuracy,
                previousAccuracy: prevAccuracy,
                totalSessions: catSessions.count
            ))
        }
        return trends.sorted { $0.category < $1.category }
    }
}

struct CategoryTrendRow: View {
    let trend: CategoryTrendData
    let language: AppLanguage

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trend.category)
                    .font(.caption)
                    .bold()
                Text(String(format: language == .portuguese ? "%d casos" : "%d cases", trend.totalSessions))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: trend.direction.icon)
                        .font(.caption)
                        .foregroundColor(trend.direction.color)
                    Text(String(format: "%.0f%%", trend.recentAccuracy * 100))
                        .font(.caption)
                        .bold()
                        .foregroundColor(trend.direction.color)
                }
                Text(String(format: language == .portuguese ? "anterior: %.0f%%" : "prev: %.0f%%",
                            trend.previousAccuracy * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Weakest Areas Detail View (task 5.1)
struct WeakestAreasActionView: View {
    let weakCategories: [String]
    let categoryStats: [String: CategoryStats]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.red)
                Text(language == .portuguese ? "Áreas para Melhorar" : "Areas Needing Improvement")
                    .font(.headline)
            }

            if weakCategories.isEmpty {
                Text(language == .portuguese ?
                     "Nenhuma área fraca identificada. Continue praticando!" :
                     "No weak areas identified yet. Keep practicing!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 10) {
                    ForEach(weakCategories, id: \.self) { category in
                        if let stats = categoryStats[category], stats.total > 0 {
                            WeakAreaCard(category: category, stats: stats, language: language)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

struct WeakAreaCard: View {
    let category: String
    let stats: CategoryStats
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category)
                    .font(.subheadline)
                    .bold()
                Spacer()
                Text(String(format: "%.0f%%", stats.accuracy))
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(stats.accuracy < 50 ? .red : .orange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stats.accuracy < 50 ? Color.red : Color.orange)
                        .frame(width: max(geo.size.width * CGFloat(stats.accuracy / 100.0), 4), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(String(format: language == .portuguese ?
                     "%d de %d corretos" : "%d of %d correct",
                     stats.correct, stats.total))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(actionSuggestion)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color(.systemGray4).opacity(0.5), radius: 1)
    }

    private var actionSuggestion: String {
        // Cases needed to reach 70% accuracy: (0.7*total - correct) / 0.3
        let casesNeeded = max(0, Int(ceil((0.7 * Double(stats.total) - Double(stats.correct)) / 0.3)))
        if stats.accuracy < 40 {
            return language == .portuguese ? "Revise o material" : "Review study material"
        } else if stats.accuracy < 60 {
            return language == .portuguese ?
                "Pratique +\(casesNeeded) casos" : "Practice +\(casesNeeded) cases"
        } else {
            return language == .portuguese ? "Foco em precisão" : "Focus on precision"
        }
    }
}

struct RecommendationsView: View {
    let metrics: PerformanceMetrics
    let categoryStats: [String: CategoryStats]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Recomendações" : "Recommendations")
                .font(.headline)

            LazyVStack(spacing: 12) {
                ForEach(generateRecommendations(), id: \.title) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func generateRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // Response time recommendation
        if metrics.averageResponseTime > 300 { // More than 5 minutes
            recommendations.append(Recommendation(
                title: language == .portuguese ? "Melhore o Tempo de Resposta" : "Improve Response Time",
                description: language == .portuguese ?
                    "Você está levando muito tempo para fazer diagnósticos. Tente ser mais decisivo." :
                    "You're taking too long to make diagnoses. Try to be more decisive.",
                actionText: language == .portuguese ? "Pratique casos rápidos" : "Practice quick cases",
                priority: .medium,
                icon: "clock"
            ))
        }

        // Questions per case recommendation
        if metrics.averageQuestionsPerCase > 12 {
            recommendations.append(Recommendation(
                title: language == .portuguese ? "Faça Perguntas Mais Focadas" : "Ask More Focused Questions",
                description: language == .portuguese ?
                    "Você está fazendo muitas perguntas. Concentre-se nos sintomas principais." :
                    "You're asking too many questions. Focus on key symptoms.",
                actionText: language == .portuguese ? "Revise técnicas de entrevista" : "Review interview techniques",
                priority: .high,
                icon: "questionmark.circle"
            ))
        }

        // Weak categories recommendation
        if !metrics.weakCategories.isEmpty {
            recommendations.append(Recommendation(
                title: language == .portuguese ? "Foque nas Áreas Fracas" : "Focus on Weak Areas",
                description: language == .portuguese ?
                    "Você precisa melhorar em: \(metrics.weakCategories.joined(separator: ", "))" :
                    "You need improvement in: \(metrics.weakCategories.joined(separator: ", "))",
                actionText: language == .portuguese ? "Estudar essas categorias" : "Study these categories",
                priority: .high,
                icon: "target"
            ))
        }

        // Consistency recommendation
        if metrics.consistencyScore < 0.6 {
            recommendations.append(Recommendation(
                title: language == .portuguese ? "Melhore a Consistência" : "Improve Consistency",
                description: language == .portuguese ?
                    "Seu desempenho varia muito. Tente manter um padrão mais consistente." :
                    "Your performance varies too much. Try to maintain a more consistent pattern.",
                actionText: language == .portuguese ? "Desenvolva rotina de estudo" : "Develop study routine",
                priority: .medium,
                icon: "chart.line.flattrend.xyaxis"
            ))
        }

        return recommendations
    }
}

struct Recommendation {
    let title: String
    let description: String
    let actionText: String
    let priority: InsightPriority
    let icon: String
}

struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: recommendation.icon)
                    .font(.title3)
                    .foregroundColor(recommendation.priority.color)

                Text(recommendation.title)
                    .font(.subheadline)
                    .bold()

                Spacer()

                Circle()
                    .fill(recommendation.priority.color)
                    .frame(width: 8, height: 8)
            }

            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)

            // Non-interactive action label (navigation not yet wired)
            Text(recommendation.actionText)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(recommendation.priority.color.opacity(0.2))
                .foregroundColor(recommendation.priority.color)
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color(.systemGray4).opacity(0.5), radius: 1)
    }
}

struct GoalSettingView: View {
    let currentLevel: DifficultyLevel
    let language: AppLanguage
    @State private var selectedGoals: Set<String> = []

    private let availableGoals = [
        "improve_accuracy", "reduce_time", "increase_consistency",
        "master_category", "advance_level", "reduce_hints"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Definir Metas" : "Set Goals")
                .font(.headline)

            Text(language == .portuguese ?
                 "Selecione suas metas de aprendizado:" :
                 "Select your learning goals:")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVStack(spacing: 8) {
                ForEach(availableGoals, id: \.self) { goalId in
                    GoalRow(
                        goalId: goalId,
                        language: language,
                        isSelected: selectedGoals.contains(goalId)
                    ) {
                        if selectedGoals.contains(goalId) {
                            selectedGoals.remove(goalId)
                        } else {
                            selectedGoals.insert(goalId)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GoalRow: View {
    let goalId: String
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goalTitle)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.primary)

                    Text(goalDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var goalTitle: String {
        switch goalId {
        case "improve_accuracy":
            return language == .portuguese ? "Melhorar Precisão" : "Improve Accuracy"
        case "reduce_time":
            return language == .portuguese ? "Reduzir Tempo" : "Reduce Time"
        case "increase_consistency":
            return language == .portuguese ? "Aumentar Consistência" : "Increase Consistency"
        case "master_category":
            return language == .portuguese ? "Dominar Categoria" : "Master Category"
        case "advance_level":
            return language == .portuguese ? "Avançar Nível" : "Advance Level"
        case "reduce_hints":
            return language == .portuguese ? "Usar Menos Dicas" : "Use Fewer Hints"
        default:
            return goalId
        }
    }

    private var goalDescription: String {
        switch goalId {
        case "improve_accuracy":
            return language == .portuguese ? "Alcançar 85%+ de precisão" : "Achieve 85%+ accuracy"
        case "reduce_time":
            return language == .portuguese ? "Diagnóstico em < 3 min" : "Diagnose in < 3 min"
        case "increase_consistency":
            return language == .portuguese ? "Manter desempenho estável" : "Maintain stable performance"
        case "master_category":
            return language == .portuguese ? "100% em uma categoria" : "100% in one category"
        case "advance_level":
            return language == .portuguese ? "Próximo nível de dificuldade" : "Next difficulty level"
        case "reduce_hints":
            return language == .portuguese ? "< 2 dicas por caso" : "< 2 hints per case"
        default:
            return ""
        }
    }
}
