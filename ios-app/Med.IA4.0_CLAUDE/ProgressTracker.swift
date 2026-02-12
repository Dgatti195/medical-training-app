import SwiftUI
import Foundation

// MARK: - Progress Data Models
struct DailyProgress: Codable {
    let date: Date
    var sessionsCompleted: Int
    var timeStudied: TimeInterval
    var conditionsStudied: [String]
    var averageAccuracy: Double
    var achievedGoals: [String]

    init(date: Date, sessionsCompleted: Int = 0, timeStudied: TimeInterval = 0, conditionsStudied: [String] = [], averageAccuracy: Double = 0.0, achievedGoals: [String] = []) {
        self.date = date
        self.sessionsCompleted = sessionsCompleted
        self.timeStudied = timeStudied
        self.conditionsStudied = conditionsStudied
        self.averageAccuracy = averageAccuracy
        self.achievedGoals = achievedGoals
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedStudyTime: String {
        let totalMinutes = Int(timeStudied / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct WeeklyGoal: Codable, Identifiable {
    let id: UUID
    let title: String
    let targetValue: Int
    let currentProgress: Int
    let goalType: GoalType
    let weekStartDate: Date

    init(title: String, targetValue: Int, currentProgress: Int = 0, goalType: GoalType, weekStartDate: Date) {
        self.id = UUID()
        self.title = title
        self.targetValue = targetValue
        self.currentProgress = currentProgress
        self.goalType = goalType
        self.weekStartDate = weekStartDate
    }

    enum GoalType: String, Codable, CaseIterable {
        case sessionsPerWeek = "sessions"
        case minutesPerWeek = "minutes"
        case uniqueConditions = "conditions"
        case accuracyTarget = "accuracy"

        func getDisplayName(language: AppLanguage) -> String {
            switch self {
            case .sessionsPerWeek:
                return language == .portuguese ? "Sessões por semana" : "Sessions per week"
            case .minutesPerWeek:
                return language == .portuguese ? "Minutos por semana" : "Minutes per week"
            case .uniqueConditions:
                return language == .portuguese ? "Condições únicas" : "Unique conditions"
            case .accuracyTarget:
                return language == .portuguese ? "Meta de precisão" : "Accuracy target"
            }
        }
    }

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetValue) * 100, 100)
    }

    var isCompleted: Bool {
        return currentProgress >= targetValue
    }
}

// MARK: - Progress Tracker
class ProgressTracker: ObservableObject {
    static let shared = ProgressTracker()

    @Published var dailyProgress: [DailyProgress] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var weeklyGoals: [WeeklyGoal] = []
    @Published var todayProgress: DailyProgress

    private let progressKey = "DailyProgress"
    private let streakKey = "CurrentStreak"
    private let longestStreakKey = "LongestStreak"
    private let weeklyGoalsKey = "WeeklyGoals"

    init() {
        let today = Calendar.current.startOfDay(for: Date())
        self.todayProgress = DailyProgress(date: today)

        loadProgressData()
        setupDefaultWeeklyGoals()
        updateStreakCount()
    }

    // MARK: - Daily Progress Tracking
    func startStudySession() {
        let today = Calendar.current.startOfDay(for: Date())
        if let index = dailyProgress.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            todayProgress = dailyProgress[index]
        } else {
            todayProgress = DailyProgress(date: today)
            dailyProgress.append(todayProgress)
        }
    }

    func completeStudySession(condition: String, timeSpent: TimeInterval, accuracy: Double) {
        todayProgress.sessionsCompleted += 1
        todayProgress.timeStudied += timeSpent

        if !todayProgress.conditionsStudied.contains(condition) {
            todayProgress.conditionsStudied.append(condition)
        }

        // Update average accuracy
        let totalSessions = Double(todayProgress.sessionsCompleted)
        todayProgress.averageAccuracy = ((todayProgress.averageAccuracy * (totalSessions - 1)) + accuracy) / totalSessions

        // Update today's progress in the array
        if let index = dailyProgress.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: todayProgress.date) }) {
            dailyProgress[index] = todayProgress
        } else {
            dailyProgress.append(todayProgress)
        }

        updateWeeklyGoals()
        updateStreakCount()
        saveProgressData()

        // Check for goal achievements
        checkGoalAchievements()
    }

    // MARK: - Streak Calculation
    private func updateStreakCount() {
        let sortedProgress = dailyProgress.sorted { $0.date > $1.date }
        var streak = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())

        for progress in sortedProgress {
            if calendar.isDate(progress.date, inSameDayAs: currentDate) && progress.sessionsCompleted > 0 {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if calendar.isDate(progress.date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate) && progress.sessionsCompleted > 0 {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }

        currentStreak = streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        UserDefaults.standard.set(currentStreak, forKey: streakKey)
        UserDefaults.standard.set(longestStreak, forKey: longestStreakKey)
    }

    // MARK: - Weekly Goals Management
    private func setupDefaultWeeklyGoals() {
        if weeklyGoals.isEmpty {
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()

            weeklyGoals = [
                WeeklyGoal(title: "Complete 5 sessions", targetValue: 5, currentProgress: 0, goalType: .sessionsPerWeek, weekStartDate: weekStart),
                WeeklyGoal(title: "Study for 120 minutes", targetValue: 120, currentProgress: 0, goalType: .minutesPerWeek, weekStartDate: weekStart),
                WeeklyGoal(title: "Learn 10 conditions", targetValue: 10, currentProgress: 0, goalType: .uniqueConditions, weekStartDate: weekStart)
            ]
        }
    }

    private func updateWeeklyGoals() {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekProgress = dailyProgress.filter { progress in
            guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return false }
            return weekInterval.contains(progress.date)
        }

        for i in 0..<weeklyGoals.count {
            switch weeklyGoals[i].goalType {
            case .sessionsPerWeek:
                weeklyGoals[i] = WeeklyGoal(
                    title: weeklyGoals[i].title,
                    targetValue: weeklyGoals[i].targetValue,
                    currentProgress: weekProgress.reduce(0) { $0 + $1.sessionsCompleted },
                    goalType: weeklyGoals[i].goalType,
                    weekStartDate: weekStart
                )
            case .minutesPerWeek:
                weeklyGoals[i] = WeeklyGoal(
                    title: weeklyGoals[i].title,
                    targetValue: weeklyGoals[i].targetValue,
                    currentProgress: Int(weekProgress.reduce(0) { $0 + $1.timeStudied } / 60),
                    goalType: weeklyGoals[i].goalType,
                    weekStartDate: weekStart
                )
            case .uniqueConditions:
                let uniqueConditions = Set(weekProgress.flatMap { $0.conditionsStudied })
                weeklyGoals[i] = WeeklyGoal(
                    title: weeklyGoals[i].title,
                    targetValue: weeklyGoals[i].targetValue,
                    currentProgress: uniqueConditions.count,
                    goalType: weeklyGoals[i].goalType,
                    weekStartDate: weekStart
                )
            case .accuracyTarget:
                let avgAccuracy = weekProgress.isEmpty ? 0 : weekProgress.reduce(0) { $0 + $1.averageAccuracy } / Double(weekProgress.count)
                weeklyGoals[i] = WeeklyGoal(
                    title: weeklyGoals[i].title,
                    targetValue: weeklyGoals[i].targetValue,
                    currentProgress: Int(avgAccuracy),
                    goalType: weeklyGoals[i].goalType,
                    weekStartDate: weekStart
                )
            }
        }
    }

    private func checkGoalAchievements() {
        for goal in weeklyGoals {
            if goal.isCompleted && !todayProgress.achievedGoals.contains(goal.title) {
                todayProgress.achievedGoals.append(goal.title)
                // Could trigger notification or achievement animation here
            }
        }
    }

    // MARK: - Data Persistence
    private func saveProgressData() {
        if let data = try? JSONEncoder().encode(dailyProgress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }

        if let weeklyData = try? JSONEncoder().encode(weeklyGoals) {
            UserDefaults.standard.set(weeklyData, forKey: weeklyGoalsKey)
        }
    }

    private func loadProgressData() {
        // Load daily progress
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let progress = try? JSONDecoder().decode([DailyProgress].self, from: data) {
            dailyProgress = progress
        }

        // Load weekly goals
        if let weeklyData = UserDefaults.standard.data(forKey: weeklyGoalsKey),
           let goals = try? JSONDecoder().decode([WeeklyGoal].self, from: weeklyData) {
            weeklyGoals = goals
        }

        // Load streaks
        currentStreak = UserDefaults.standard.integer(forKey: streakKey)
        longestStreak = UserDefaults.standard.integer(forKey: longestStreakKey)
    }

    // MARK: - Computed Properties
    var totalSessionsCompleted: Int {
        return dailyProgress.reduce(0) { $0 + $1.sessionsCompleted }
    }

    var averageAccuracy: Double {
        let totalSessions = dailyProgress.filter { $0.sessionsCompleted > 0 }
        guard !totalSessions.isEmpty else { return 0.0 }
        return totalSessions.reduce(0.0) { $0 + $1.averageAccuracy } / Double(totalSessions.count)
    }

    var totalStudyTime: TimeInterval {
        return dailyProgress.reduce(0) { $0 + $1.timeStudied }
    }

    // MARK: - Statistics
    func getWeeklyStats() -> (totalSessions: Int, totalTime: TimeInterval, uniqueConditions: Int, avgAccuracy: Double) {
        let weekProgress = dailyProgress.filter { progress in
            guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return false }
            return weekInterval.contains(progress.date)
        }

        let totalSessions = weekProgress.reduce(0) { $0 + $1.sessionsCompleted }
        let totalTime = weekProgress.reduce(0) { $0 + $1.timeStudied }
        let uniqueConditions = Set(weekProgress.flatMap { $0.conditionsStudied }).count
        let avgAccuracy = weekProgress.isEmpty ? 0 : weekProgress.reduce(0) { $0 + $1.averageAccuracy } / Double(weekProgress.count)

        return (totalSessions, totalTime, uniqueConditions, avgAccuracy)
    }

    func getLastSevenDaysProgress() -> [DailyProgress] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        var result: [DailyProgress] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: i, to: sevenDaysAgo) ?? sevenDaysAgo
            if let existingProgress = dailyProgress.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                result.append(existingProgress)
            } else {
                result.append(DailyProgress(date: date))
            }
        }

        return result
    }
}