import SwiftUI
import Foundation

// MARK: - User Profile Manager
class UserProfileManager: ObservableObject {
    @Published var profile = UserProfile()
    @Published var currentLanguage: AppLanguage = .english

    private let userDefaults = UserDefaults.standard
    private let profileKey = "UserProfile"

    init() {
        loadProfile()
        currentLanguage = AppLanguage(rawValue: self.profile.selectedLanguage) ?? .english
    }

    func saveProfile() {
        if let encoded = try? JSONEncoder().encode(self.profile) {
            userDefaults.set(encoded, forKey: profileKey)
        }
    }

    func loadProfile() {
        if let data = userDefaults.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded
        }
    }

    func recordDiagnosis(disease: Disease, isCorrect: Bool, questionCount: Int, hintsUsed: Int, testsOrdered: Int) {
        self.profile.totalPatientsInterviewed += 1
        self.profile.totalDiagnosesAttempted += 1
        self.profile.hintsUsed += hintsUsed
        self.profile.testsOrdered += testsOrdered

        if isCorrect {
            self.profile.totalCorrectDiagnoses += 1
        }

        var categoryStats = self.profile.categoryPerformance[disease.category] ?? CategoryStats()
        if isCorrect {
            categoryStats.correct += 1
        } else {
            categoryStats.incorrect += 1
        }
        self.profile.categoryPerformance[disease.category] = categoryStats

        saveProfile()
    }

    func changeLanguage(_ language: AppLanguage) {
        currentLanguage = language
        self.profile.selectedLanguage = language.rawValue
        saveProfile()
    }

    func setTrainingMode(_ mode: TrainingMode) {
        self.profile.preferredTrainingMode = mode
        saveProfile()
        print("🎯 Training mode set to: \(mode == .basic ? "BASIC" : "CLINICAL")")
    }

    func addStudyTime(_ time: TimeInterval) {
        self.profile.studyTime += time
        saveProfile()
    }

    // MARK: - Session Management Methods
    func startNewSession(patientCase: PatientCase, difficulty: DifficultyLevel) {
        let sessionData = SessionData(
            startTime: Date(),
            patientCaseId: patientCase.disease.id.description,
            diseaseCategory: patientCase.disease.category,
            difficulty: difficulty
        )

        self.profile.currentSessionData = sessionData
    }

    private func determineDifficultyLevel(for patientCase: PatientCase) -> DifficultyLevel {
        // Logic to determine difficulty based on case complexity
        let complexityFactors = [
            patientCase.presentingSymptoms.count,
            patientCase.availableLabResults.count,
            patientCase.availableHints.count
        ]

        let totalComplexity = complexityFactors.reduce(0, +)

        switch totalComplexity {
        case 0...3: return .beginner
        case 4...7: return .intermediate
        case 8...12: return .advanced
        default: return .expert
        }
    }

    func updateSessionProgress(questionsAsked: Int, hintsUsed: Int, testsOrdered: Int, responseTime: TimeInterval) {
        guard var currentSession = self.profile.currentSessionData else { return }

        currentSession.questionsAsked = questionsAsked
        currentSession.hintsUsed = hintsUsed
        currentSession.testsOrdered = testsOrdered
        currentSession.responseTimeSeconds = responseTime

        self.profile.currentSessionData = currentSession
    }

    func completeSession(finalDiagnosis: String, isCorrect: Bool, confidenceScore: Double) {
        guard var currentSession = self.profile.currentSessionData else { return }

        currentSession.endTime = Date()
        currentSession.finalDiagnosis = finalDiagnosis
        currentSession.isCorrect = isCorrect
        currentSession.confidenceScore = confidenceScore
        currentSession.completionStatus = .completed

        // Add to sessions history
        self.profile.sessions.append(currentSession)

        // Update overall metrics
        updatePerformanceMetrics()
        updateWeeklyProgress()
        generateLearningInsights()

        self.profile.currentSessionData = nil
        saveProfile()
    }

    func abandonSession() {
        guard var currentSession = self.profile.currentSessionData else { return }

        currentSession.endTime = Date()
        currentSession.completionStatus = .abandoned
        self.profile.sessions.append(currentSession)

        self.profile.currentSessionData = nil
        saveProfile()
    }

    private func updatePerformanceMetrics() {
        let completedSessions = self.profile.sessions.filter { $0.completionStatus == .completed }
        guard !completedSessions.isEmpty else { return }

        // Calculate average response time
        let totalResponseTime = completedSessions.reduce(0) { $0 + $1.responseTimeSeconds }
        self.profile.performanceMetrics.averageResponseTime = totalResponseTime / Double(completedSessions.count)

        // Calculate average time to diagnosis (session duration)
        let totalDuration = completedSessions.reduce(0.0) { $0 + $1.duration }
        self.profile.performanceMetrics.avgTimeToDiagnosis = totalDuration / Double(completedSessions.count)

        // Calculate average questions per case
        let totalQuestions = completedSessions.reduce(0) { $0 + $1.questionsAsked }
        self.profile.performanceMetrics.averageQuestionsPerCase = Double(totalQuestions) / Double(completedSessions.count)

        // Calculate average confidence
        let totalConfidence = completedSessions.reduce(0) { $0 + $1.confidenceScore }
        self.profile.performanceMetrics.averageConfidenceScore = totalConfidence / Double(completedSessions.count)

        // Calculate diagnostic efficiency (correct diagnoses per minute)
        let correctSessions = completedSessions.filter { $0.isCorrect }
        let totalStudyTimeMinutes = completedSessions.reduce(0) { $0 + $1.duration } / 60.0
        self.profile.performanceMetrics.diagnosticEfficiency = totalStudyTimeMinutes > 0 ? Double(correctSessions.count) / totalStudyTimeMinutes : 0

        // Identify strong and weak categories
        updateCategoryStrengths()

        // Calculate learning velocity and consistency
        calculateAdvancedMetrics()
    }

    private func updateWeeklyProgress() {
        let calendar = Calendar.current
        let now = Date()

        // Get current week's start date
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return }

        // Find or create current week's progress
        var currentWeek = self.profile.weeklyProgress.first { calendar.isDate($0.weekStartDate, inSameDayAs: weekStart) }

        if currentWeek == nil {
            currentWeek = WeeklyProgress(weekStartDate: weekStart)
        }

        // Update current week's data
        let weekSessions = self.profile.sessions.filter { session in
            calendar.isDate(session.startTime, equalTo: weekStart, toGranularity: .weekOfYear)
        }

        let completedWeekSessions = weekSessions.filter { $0.completionStatus == .completed }

        if var week = currentWeek {
            week.totalSessions = weekSessions.count
            // Break down complex calculations to avoid type-checking timeout
            if completedWeekSessions.isEmpty {
                week.averageAccuracy = 0
                week.averageResponseTime = 0
            } else {
                let correctCount = completedWeekSessions.filter { $0.isCorrect }.count
                week.averageAccuracy = Double(correctCount) / Double(completedWeekSessions.count)

                let totalResponseTime = completedWeekSessions.reduce(0) { $0 + $1.responseTimeSeconds }
                week.averageResponseTime = totalResponseTime / Double(completedWeekSessions.count)
            }

            let totalDuration = weekSessions.reduce(0) { $0 + $1.duration }
            week.studyTimeHours = totalDuration / 3600.0

            for session in completedWeekSessions {
                week.difficultyCasesCompleted[session.difficulty, default: 0] += 1
            }

            // Update or add to weekly progress
            if let index = self.profile.weeklyProgress.firstIndex(where: { calendar.isDate($0.weekStartDate, inSameDayAs: weekStart) }) {
                self.profile.weeklyProgress[index] = week
            } else {
                self.profile.weeklyProgress.append(week)
            }
        }

        // Keep only last 12 weeks
        self.profile.weeklyProgress = self.profile.weeklyProgress.suffix(12)
    }

    private func generateLearningInsights() {
        var newInsights: [LearningInsight] = []

        // Insight 1: Performance decline detection
        if self.profile.performanceMetrics.improvementRate < -0.1 {
            newInsights.append(
                LearningInsight(
                    generatedDate: Date(),
                    insightType: .performanceDecline,
                    title: "Performance Decline Detected",
                    description: "Your diagnostic accuracy has decreased recently. Consider reviewing fundamental concepts.",
                    recommendation: "Focus on your weak categories and take more time with each case.",
                    priority: .high,
                    relatedCategories: self.profile.performanceMetrics.weakCategories
                )
            )
        }

        // Insight 2: Question efficiency
        if self.profile.performanceMetrics.averageQuestionsPerCase > 15 {
            newInsights.append(
                LearningInsight(
                    generatedDate: Date(),
                    insightType: .questioningStrategy,
                    title: "Consider More Focused Questioning",
                    description: "You're asking many questions per case. Try to focus on key diagnostic indicators.",
                    recommendation: "Practice systematic approaches: chief complaint → associated symptoms → physical exam → targeted tests.",
                    priority: .medium,
                    relatedCategories: []
                )
            )
        }

        // Insight 3: Learning velocity (positive feedback)
        if self.profile.sessions.count >= 10 && self.profile.performanceMetrics.learningVelocity > 0.8 {
            newInsights.append(
                LearningInsight(
                    generatedDate: Date(),
                    insightType: .learningVelocity,
                    title: "Excellent Learning Progress!",
                    description: "You're showing strong improvement across multiple categories.",
                    recommendation: "Consider challenging yourself with more complex cases in your strong areas.",
                    priority: .medium,
                    relatedCategories: self.profile.performanceMetrics.strongCategories
                )
            )
        }

        // Add new insights and maintain reasonable list size
        self.profile.learningInsights.append(contentsOf: newInsights)
        self.profile.learningInsights = self.profile.learningInsights.suffix(10) // Keep only last 10 insights
    }

    private func updateCategoryStrengths() {
        var categoryPerformance: [String: (correct: Int, total: Int)] = [:]

        let completedSessions = self.profile.sessions.filter { $0.completionStatus == .completed }
        for session in completedSessions {
            let category = session.diseaseCategory
            let current = categoryPerformance[category] ?? (correct: 0, total: 0)
            categoryPerformance[category] = (
                correct: current.correct + (session.isCorrect ? 1 : 0),
                total: current.total + 1
            )
        }

        // Sort categories by accuracy
        let sortedCategories = categoryPerformance.sorted { first, second in
            let firstAccuracy = Double(first.value.correct) / Double(first.value.total)
            let secondAccuracy = Double(second.value.correct) / Double(second.value.total)
            return firstAccuracy > secondAccuracy
        }

        // Update strong/weak categories
        let topCategories = Array(sortedCategories.prefix(3))
        let bottomCategories = Array(sortedCategories.suffix(3))

        self.profile.performanceMetrics.strongCategories = topCategories.map { $0.key }
        self.profile.performanceMetrics.weakCategories = bottomCategories.map { $0.key }
    }

    private func calculateAdvancedMetrics() {
        let recentSessions = self.profile.sessions.suffix(20) // Last 20 sessions
        guard recentSessions.count >= 5 else { return }

        // Calculate consistency score (how consistent performance is)
        let accuracyScores = recentSessions.map { $0.isCorrect ? 1.0 : 0.0 }
        let meanAccuracy = accuracyScores.reduce(0, +) / Double(accuracyScores.count)

        // Calculate variance in smaller steps to avoid type-checking timeout
        let squaredDeviations = accuracyScores.map { pow($0 - meanAccuracy, 2) }
        let variance = squaredDeviations.reduce(0, +) / Double(accuracyScores.count)
        self.profile.performanceMetrics.consistencyScore = max(0, 1 - variance) // Higher score = more consistent

        // Calculate improvement rate (comparing first half vs second half of recent sessions)
        let firstHalf = Array(recentSessions.prefix(recentSessions.count / 2))
        let secondHalf = Array(recentSessions.suffix(recentSessions.count / 2))

        let firstHalfAccuracy = firstHalf.filter { $0.isCorrect }.count
        let secondHalfAccuracy = secondHalf.filter { $0.isCorrect }.count

        let firstHalfRate = Double(firstHalfAccuracy) / Double(firstHalf.count)
        let secondHalfRate = Double(secondHalfAccuracy) / Double(secondHalf.count)

        self.profile.performanceMetrics.improvementRate = secondHalfRate - firstHalfRate
    }
}
