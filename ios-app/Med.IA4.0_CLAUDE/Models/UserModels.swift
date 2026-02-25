import Foundation
import SwiftUI

// MARK: - User Profile and Settings Models
struct UserProfile: Codable {
    var totalPatientsInterviewed: Int = 0
    var totalDiagnosesAttempted: Int = 0
    var totalCorrectDiagnoses: Int = 0
    var categoryPerformance: [String: CategoryStats] = [:]
    var dailyStats: [String: DayStats] = [:]
    var selectedLanguage: String = AppLanguage.english.rawValue
    var createdDate: Date = Date()
    var studyTime: TimeInterval = 0
    var hintsUsed: Int = 0
    var testsOrdered: Int = 0

    // New profile fields
    var userName: String = ""
    var userGender: UserGender = .preferNotToSay
    var isProfileSetupComplete: Bool = false
    var voiceInputEnabled: Bool = false
    var preferredTrainingMode: TrainingMode = .clinical  // User's default training mode

    // Enhanced Performance Analytics Fields
    var sessions: [SessionData] = []
    var weeklyProgress: [WeeklyProgress] = []
    var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    var learningInsights: [LearningInsight] = []
    var performanceTrends: [PerformanceTrend] = []
    var currentSessionData: SessionData?
    var overallDifficultyLevel: DifficultyLevel = .beginner

    var accuracyPercentage: Double {
        guard totalDiagnosesAttempted > 0 else { return 0 }
        return (Double(totalCorrectDiagnoses) / Double(totalDiagnosesAttempted)) * 100
    }
}

struct CategoryStats: Codable {
    var correct: Int = 0
    var incorrect: Int = 0
    var total: Int { correct + incorrect }
    var accuracy: Double {
        guard total > 0 else { return 0 }
        return (Double(correct) / Double(total)) * 100
    }
}

struct DayStats: Codable {
    var date: Date
    var patientsInterviewed: Int = 0
    var diagnosesAttempted: Int = 0
    var correctDiagnoses: Int = 0
    var studyTime: TimeInterval = 0
}

// MARK: - Enhanced Performance Analytics Structures

struct SessionData: Codable, Identifiable {
    var id = UUID()
    let startTime: Date
    var endTime: Date?
    var patientCaseId: String
    var diseaseCategory: String
    var difficulty: DifficultyLevel
    var responseTimeSeconds: TimeInterval = 0
    var questionsAsked: Int = 0
    var hintsUsed: Int = 0
    var testsOrdered: Int = 0
    var finalDiagnosis: String = ""
    var isCorrect: Bool = false
    var confidenceScore: Double = 0.0 // 0.0-1.0
    var completionStatus: SessionStatus = .inProgress
    var treatmentPrescribed: String = ""
    var treatmentScore: Double = 0.0
    var treatmentIsAcceptable: Bool = false

    var duration: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime)
    }
}

struct PerformanceMetrics: Codable {
    var averageResponseTime: TimeInterval = 0
    var avgTimeToDiagnosis: TimeInterval = 0   // average session duration for completed cases
    var averageQuestionsPerCase: Double = 0
    var averageConfidenceScore: Double = 0
    var diagnosticEfficiency: Double = 0 // Correct diagnoses per minute
    var improvementRate: Double = 0 // Week-over-week improvement
    var consistencyScore: Double = 0 // How consistent performance is
    var strongCategories: [String] = [] // Top performing categories
    var weakCategories: [String] = [] // Categories needing improvement
    var learningVelocity: Double = 0 // Rate of skill acquisition
    var retentionRate: Double = 0 // Knowledge retention over time
}

struct WeeklyProgress: Codable, Identifiable {
    var id = UUID()
    let weekStartDate: Date
    var totalSessions: Int = 0
    var averageAccuracy: Double = 0
    var averageResponseTime: TimeInterval = 0
    var studyTimeHours: Double = 0
    var difficultyCasesCompleted: [DifficultyLevel: Int] = [:]
    var categoryBreakdown: [String: CategoryStats] = [:]
    var improvementFromLastWeek: Double = 0

    var weekEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
    }
}

struct LearningInsight: Codable, Identifiable {
    var id = UUID()
    let generatedDate: Date
    let insightType: InsightType
    let title: String
    let description: String
    let recommendation: String
    let priority: InsightPriority
    let relatedCategories: [String]
    var isViewed: Bool = false
    var isActionTaken: Bool = false
}

enum InsightType: String, CaseIterable, Codable {
    case performance = "performance"
    case learning = "learning"
    case efficiency = "efficiency"
    case knowledge = "knowledge"
    case behavior = "behavior"
    case performanceDecline = "performanceDecline"
    case questioningStrategy = "questioningStrategy"
    case learningVelocity = "learningVelocity"
}

enum InsightPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct PerformanceTrend: Codable {
    let metric: String
    let dataPoints: [TrendDataPoint]
    let trendDirection: TrendDirection
    let changePercentage: Double
}

struct TrendDataPoint: Codable {
    let date: Date
    let value: Double
}

enum TrendDirection: String, CaseIterable, Codable {
    case improving = "improving"
    case declining = "declining"
    case stable = "stable"

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        }
    }
}
