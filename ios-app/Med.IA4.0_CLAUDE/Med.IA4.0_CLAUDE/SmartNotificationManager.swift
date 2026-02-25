import SwiftUI
import UserNotifications
import Foundation

// MARK: - Smart Notification Manager
class SmartNotificationManager: ObservableObject {
    static let shared = SmartNotificationManager()

    @Published var notificationPermissionGranted = false
    @Published var pendingNotifications: [SmartNotification] = []
    @Published var dailyRemindersEnabled = true
    @Published var reminderTime = Date()
    @Published var achievementNotificationsEnabled = true
    @Published var streakNotificationsEnabled = true
    @Published var smartNotificationsEnabled = true
    @Published var currentStreak = 0
    var achievements: [Achievement] = []

    /// Language used for notification content. Set this before calling scheduleSmartNotifications().
    var language: AppLanguage = .english

    private let center = UNUserNotificationCenter.current()

    init() {
        checkNotificationPermission()
        loadPendingNotifications()
        loadAchievements()
    }

    // MARK: - Permission Management
    func requestNotificationPermission() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = granted
                if granted {
                    self?.scheduleSmartNotifications()
                }
            }
        }
    }

    private func checkNotificationPermission() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Smart Notifications
    func scheduleSmartNotifications() {
        guard notificationPermissionGranted else { return }

        // Schedule daily study reminders
        scheduleDailyReminders()

        // Schedule streak maintenance notifications
        scheduleStreakReminders()

        // Schedule achievement notifications
        scheduleAchievementReminders()
    }

    private func scheduleDailyReminders() {
        guard dailyRemindersEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = language == .portuguese ? "Lembrete de Estudo" : "Study Reminder"
        content.body = language == .portuguese ?
            "Hora da sua sessão diária de treinamento médico!" :
            "Time for your daily medical training session!"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Error scheduling daily reminder: \(error)")
            }
        }
    }

    private func scheduleStreakReminders() {
        guard streakNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = language == .portuguese ? "Mantenha Sua Sequência!" : "Maintain Your Streak!"
        content.body = language == .portuguese ?
            "Não perca sua sequência de \(currentStreak) dias de estudo!" :
            "Don't break your \(currentStreak)-day study streak!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: false) // 24 hours

        let request = UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Error scheduling streak reminder: \(error)")
            }
        }
    }

    private func scheduleAchievementReminders() {
        guard achievementNotificationsEnabled else { return }
        // Achievement reminder logic would go here
    }

    // MARK: - Achievement Notifications
    func triggerAchievementNotification(_ achievement: Achievement) {
        guard achievementNotificationsEnabled && notificationPermissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = language == .portuguese ? "Conquista Desbloqueada!" : "Achievement Unlocked!"
        content.body = achievement.title
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement_\(achievement.id)", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Error showing achievement notification: \(error)")
            }
        }
    }

    // MARK: - Pending Notifications
    private func loadPendingNotifications() {
        center.getPendingNotificationRequests { [weak self] requests in
            DispatchQueue.main.async {
                self?.pendingNotifications = requests.map { SmartNotification(from: $0) }
            }
        }
    }

    private func loadAchievements() {
        // Initialize with empty achievements for now
        achievements = []
    }
}

// MARK: - Smart Notification Model
struct SmartNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let scheduledDate: Date?
    let category: String

    init(from request: UNNotificationRequest) {
        self.id = request.identifier
        self.title = request.content.title
        self.body = request.content.body
        self.category = request.content.categoryIdentifier

        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            self.scheduledDate = trigger.nextTriggerDate()
        } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            self.scheduledDate = Date().addingTimeInterval(trigger.timeInterval)
        } else {
            self.scheduledDate = nil
        }
    }
}

// MARK: - Achievement System
struct Achievement: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let condition: AchievementCondition
    var isUnlocked: Bool = false

    enum AchievementCondition: Codable {
        case sessionsCompleted(Int)
        case accuracyReached(Double)
        case streakReached(Int)
        case timeStudied(TimeInterval)
        case diverseStudy(Int)
    }
}

// MARK: - Achievement Manager
class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    @Published var achievements: [Achievement] = []
    @Published var unlockedAchievements: [Achievement] = []

    private let achievementsKey = "UserAchievements"

    init() {
        setupDefaultAchievements()
        loadAchievements()
    }

    private func setupDefaultAchievements() {
        achievements = [
            Achievement(
                id: UUID(),
                title: "First Steps",
                description: "Complete your first diagnostic session",
                condition: .sessionsCompleted(1)
            ),
            Achievement(
                id: UUID(),
                title: "Accurate Diagnosis",
                description: "Achieve 90% accuracy in a session",
                condition: .accuracyReached(0.9)
            ),
            Achievement(
                id: UUID(),
                title: "Week Warrior",
                description: "Study for 7 consecutive days",
                condition: .streakReached(7)
            ),
            Achievement(
                id: UUID(),
                title: "Study Marathon",
                description: "Study for 2 hours in a single day",
                condition: .timeStudied(7200)
            ),
            Achievement(
                id: UUID(),
                title: "Medical Explorer",
                description: "Study 5 different medical categories",
                condition: .diverseStudy(5)
            )
        ]
    }

    func checkAchievements(progressTracker: ProgressTracker) {
        let stats = progressTracker.getWeeklyStats()

        for i in 0..<achievements.count {
            guard !achievements[i].isUnlocked else { continue }

            let shouldUnlock = checkAchievementCondition(
                achievements[i].condition,
                progressTracker: progressTracker,
                stats: stats
            )

            if shouldUnlock {
                var updatedAchievement = achievements[i]
                updatedAchievement.isUnlocked = true
                achievements[i] = updatedAchievement

                unlockedAchievements.append(updatedAchievement)
                SmartNotificationManager.shared.triggerAchievementNotification(updatedAchievement)

                saveAchievements()
            }
        }
    }

    private func checkAchievementCondition(
        _ condition: Achievement.AchievementCondition,
        progressTracker: ProgressTracker,
        stats: (totalSessions: Int, totalTime: TimeInterval, uniqueConditions: Int, avgAccuracy: Double)
    ) -> Bool {
        switch condition {
        case .sessionsCompleted(let target):
            return progressTracker.totalSessionsCompleted >= target
        case .accuracyReached(let target):
            return progressTracker.averageAccuracy >= target
        case .streakReached(let target):
            return progressTracker.currentStreak >= target
        case .timeStudied(let target):
            return progressTracker.totalStudyTime >= target
        case .diverseStudy(let target):
            return stats.uniqueConditions >= target
        }
    }

    private func saveAchievements() {
        // Save achievements implementation would go here
    }

    private func loadAchievements() {
        // Load achievements implementation would go here
    }
}