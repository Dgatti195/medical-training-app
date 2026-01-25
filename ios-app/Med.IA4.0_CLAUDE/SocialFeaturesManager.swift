import SwiftUI
import Foundation

// MARK: - Social Features Manager
class SocialFeaturesManager: ObservableObject {
    static let shared = SocialFeaturesManager()

    @Published var currentUser: SocialUser?
    @Published var leaderboards: [Leaderboard] = []
    @Published var studyGroups: [StudyGroup] = []
    @Published var activeChallenge: Challenge?
    @Published var completedChallenges: [Challenge] = []
    @Published var socialFeed: [SocialFeedItem] = []

    private let userKey = "SocialUser"
    private let challengesKey = "CompletedChallenges"

    init() {
        setupMockData()
        loadSocialUser()
        loadCompletedChallenges()
        generateWeeklyChallenges()
    }

    // MARK: - User Management
    func createSocialUser(nickname: String, avatarIcon: String) {
        let user = SocialUser(
            id: UUID(),
            nickname: nickname,
            avatarIcon: avatarIcon,
            level: 1,
            totalXP: 0,
            streak: 0,
            joinDate: Date()
        )

        currentUser = user
        saveSocialUser()
    }

    private func saveSocialUser() {
        if let user = currentUser,
           let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func loadSocialUser() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(SocialUser.self, from: data) {
            currentUser = user
        }
    }

    func updateUserProgress(sessionsCompleted: Int, accuracy: Double, timeSpent: TimeInterval) {
        guard var user = currentUser else { return }

        let xpGained = calculateXP(sessions: sessionsCompleted, accuracy: accuracy, time: timeSpent)
        user.totalXP += xpGained
        user.level = calculateLevel(from: user.totalXP)

        currentUser = user
        saveSocialUser()

        // Update leaderboards
        updateLeaderboards()

        // Check challenge progress
        checkChallengeProgress(xpGained: xpGained, sessions: sessionsCompleted)
    }

    private func calculateXP(sessions: Int, accuracy: Double, time: TimeInterval) -> Int {
        let baseXP = sessions * 10
        let accuracyBonus = Int(accuracy / 10) * sessions
        let timeBonus = min(Int(time / 60), 30) // Max 30 XP for time
        return baseXP + accuracyBonus + timeBonus
    }

    private func calculateLevel(from xp: Int) -> Int {
        // Simple leveling: 100 XP per level initially, increases by 50 each level
        var level = 1
        var requiredXP = 100
        var currentXP = xp

        while currentXP >= requiredXP {
            currentXP -= requiredXP
            level += 1
            requiredXP += 50
        }

        return level
    }

    // MARK: - Leaderboards
    private func updateLeaderboards() {
        guard let user = currentUser else { return }

        // Update user's position in leaderboards
        for i in 0..<leaderboards.count {
            if let userIndex = leaderboards[i].users.firstIndex(where: { $0.id == user.id }) {
                leaderboards[i].users[userIndex] = user
            } else {
                leaderboards[i].users.append(user)
            }

            // Sort by appropriate metric
            switch leaderboards[i].type {
            case .xp:
                leaderboards[i].users.sort { $0.totalXP > $1.totalXP }
            case .streak:
                leaderboards[i].users.sort { $0.streak > $1.streak }
            case .level:
                leaderboards[i].users.sort { $0.level > $1.level }
            }

            // Keep only top 50
            if leaderboards[i].users.count > 50 {
                leaderboards[i].users = Array(leaderboards[i].users.prefix(50))
            }
        }
    }

    // MARK: - Challenges
    private func generateWeeklyChallenges() {
        if activeChallenge == nil || Calendar.current.isDate(activeChallenge!.endDate, inSameDayAs: Date()) {
            // Generate new weekly challenge
            let challengeTypes: [Challenge.ChallengeType] = [.sessions, .accuracy, .streak, .xp, .diversity]
            let randomType = challengeTypes.randomElement()!

            activeChallenge = Challenge(
                id: UUID(),
                title: getChallengeTitle(for: randomType),
                description: getChallengeDescription(for: randomType),
                type: randomType,
                targetValue: getChallengeTarget(for: randomType),
                currentProgress: 0,
                startDate: Calendar.current.startOfDay(for: Date()),
                endDate: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date(),
                reward: Challenge.Reward(xp: 200, badge: "Weekly Champion"),
                participants: 0
            )
        }
    }

    private func getChallengeTitle(for type: Challenge.ChallengeType) -> String {
        switch type {
        case .sessions: return "Sessão Intensiva"
        case .accuracy: return "Precisão Perfeita"
        case .streak: return "Sequência Inabalável"
        case .xp: return "Caçador de XP"
        case .diversity: return "Explorador Médico"
        }
    }

    private func getChallengeDescription(for type: Challenge.ChallengeType) -> String {
        switch type {
        case .sessions: return "Complete 15 sessões de estudo esta semana"
        case .accuracy: return "Mantenha 85% de precisão em 10 sessões"
        case .streak: return "Estude por 7 dias consecutivos"
        case .xp: return "Ganhe 500 XP esta semana"
        case .diversity: return "Estude 8 categorias médicas diferentes"
        }
    }

    private func getChallengeTarget(for type: Challenge.ChallengeType) -> Int {
        switch type {
        case .sessions: return 15
        case .accuracy: return 85
        case .streak: return 7
        case .xp: return 500
        case .diversity: return 8
        }
    }

    private func checkChallengeProgress(xpGained: Int, sessions: Int) {
        guard var challenge = activeChallenge else { return }

        switch challenge.type {
        case .sessions:
            challenge.currentProgress += sessions
        case .xp:
            challenge.currentProgress += xpGained
        case .accuracy:
            // This would need more complex tracking
            break
        case .streak:
            challenge.currentProgress = currentUser?.streak ?? 0
        case .diversity:
            // This would need category tracking
            break
        }

        if challenge.currentProgress >= challenge.targetValue && !challenge.isCompleted {
            challenge.isCompleted = true
            completedChallenges.append(challenge)
            saveCompletedChallenges()

            // Award reward
            if var user = currentUser {
                user.totalXP += challenge.reward.xp
                currentUser = user
                saveSocialUser()
            }

            // Generate new challenge
            activeChallenge = nil
            generateWeeklyChallenges()
        } else {
            activeChallenge = challenge
        }
    }

    private func saveCompletedChallenges() {
        if let data = try? JSONEncoder().encode(completedChallenges) {
            UserDefaults.standard.set(data, forKey: challengesKey)
        }
    }

    private func loadCompletedChallenges() {
        if let data = UserDefaults.standard.data(forKey: challengesKey),
           let challenges = try? JSONDecoder().decode([Challenge].self, from: data) {
            completedChallenges = challenges
        }
    }

    // MARK: - Study Groups
    func joinStudyGroup(_ group: StudyGroup) {
        if let index = studyGroups.firstIndex(where: { $0.id == group.id }) {
            studyGroups[index].memberCount += 1
            // In a real app, this would sync with a server
        }
    }

    func createStudyGroup(name: String, description: String, category: String) {
        let group = StudyGroup(
            id: UUID(),
            name: name,
            description: description,
            category: category,
            memberCount: 1,
            createdDate: Date(),
            isPrivate: false
        )

        studyGroups.append(group)
    }

    // MARK: - Mock Data
    private func setupMockData() {
        // Mock leaderboards
        leaderboards = [
            Leaderboard(
                id: UUID(),
                title: "XP Semanal",
                description: "Maiores pontuadores da semana",
                type: .xp,
                users: generateMockUsers(),
                timeframe: .weekly
            ),
            Leaderboard(
                id: UUID(),
                title: "Sequência Atual",
                description: "Maiores sequências ativas",
                type: .streak,
                users: generateMockUsers(),
                timeframe: .allTime
            ),
            Leaderboard(
                id: UUID(),
                title: "Nível Geral",
                description: "Usuários de maior nível",
                type: .level,
                users: generateMockUsers(),
                timeframe: .allTime
            )
        ]

        // Mock study groups
        studyGroups = [
            StudyGroup(
                id: UUID(),
                name: "Cardiologia Intensiva",
                description: "Estudo focado em condições cardíacas",
                category: "Cardiovascular",
                memberCount: 45,
                createdDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
                isPrivate: false
            ),
            StudyGroup(
                id: UUID(),
                name: "Neurologia Avançada",
                description: "Casos complexos de neurologia",
                category: "Neurological",
                memberCount: 32,
                createdDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date(),
                isPrivate: false
            ),
            StudyGroup(
                id: UUID(),
                name: "Emergências Médicas",
                description: "Preparação para situações de emergência",
                category: "Emergency",
                memberCount: 67,
                createdDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                isPrivate: false
            )
        ]

        // Mock social feed
        socialFeed = generateMockSocialFeed()
    }

    private func generateMockUsers() -> [SocialUser] {
        let mockNames = ["Dr. Silva", "Med Student", "Future Doc", "Study Pro", "Night Owl", "Med Expert"]
        let avatarIcons = ["stethoscope", "heart.fill", "brain.head.profile", "cross.case.fill", "pills.fill", "syringe.fill"]

        return mockNames.enumerated().map { index, name in
            SocialUser(
                id: UUID(),
                nickname: name,
                avatarIcon: avatarIcons[index % avatarIcons.count],
                level: Int.random(in: 1...25),
                totalXP: Int.random(in: 100...5000),
                streak: Int.random(in: 0...30),
                joinDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...100), to: Date()) ?? Date()
            )
        }
    }

    private func generateMockSocialFeed() -> [SocialFeedItem] {
        let activities: [SocialFeedItem.ActivityType] = [.achievementUnlocked, .challengeCompleted, .levelUp, .streakMilestone]

        return (0..<10).map { index in
            let activity = activities.randomElement()!
            return SocialFeedItem(
                id: UUID(),
                user: generateMockUsers().randomElement()!,
                activityType: activity,
                description: getActivityDescription(for: activity),
                timestamp: Calendar.current.date(byAdding: .hour, value: -index, to: Date()) ?? Date()
            )
        }
    }

    private func getActivityDescription(for activity: SocialFeedItem.ActivityType) -> String {
        switch activity {
        case .achievementUnlocked:
            return "desbloqueou a conquista 'Especialista'"
        case .challengeCompleted:
            return "completou o desafio 'Sessão Intensiva'"
        case .levelUp:
            return "subiu para o nível 15!"
        case .streakMilestone:
            return "atingiu 10 dias de sequência!"
        }
    }
}

// MARK: - Social Data Models
struct SocialUser: Identifiable, Codable {
    let id: UUID
    var nickname: String
    var avatarIcon: String
    var level: Int
    var totalXP: Int
    var streak: Int
    let joinDate: Date

    var xpToNextLevel: Int {
        let currentLevelXP = (level - 1) * 100 + ((level - 1) * (level - 2) * 25)
        let nextLevelXP = level * 100 + (level * (level - 1) * 25)
        return nextLevelXP - totalXP
    }
}

struct Leaderboard: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let type: LeaderboardType
    var users: [SocialUser]
    let timeframe: TimeFrame

    enum LeaderboardType: String, Codable, CaseIterable {
        case xp = "xp"
        case streak = "streak"
        case level = "level"

        var displayName: String {
            switch self {
            case .xp: return "XP"
            case .streak: return "Sequência"
            case .level: return "Nível"
            }
        }

        var icon: String {
            switch self {
            case .xp: return "star.fill"
            case .streak: return "flame.fill"
            case .level: return "crown.fill"
            }
        }
    }

    enum TimeFrame: String, Codable {
        case weekly = "weekly"
        case monthly = "monthly"
        case allTime = "all_time"

        var displayName: String {
            switch self {
            case .weekly: return "Semanal"
            case .monthly: return "Mensal"
            case .allTime: return "Todos os Tempos"
            }
        }
    }
}

struct StudyGroup: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    var memberCount: Int
    let createdDate: Date
    let isPrivate: Bool

    var formattedMemberCount: String {
        if memberCount >= 1000 {
            return String(format: "%.1fk", Double(memberCount) / 1000.0)
        }
        return "\(memberCount)"
    }
}

struct Challenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let type: ChallengeType
    let targetValue: Int
    var currentProgress: Int
    let startDate: Date
    let endDate: Date
    let reward: Reward
    var participants: Int
    var isCompleted: Bool = false

    enum ChallengeType: String, Codable {
        case sessions = "sessions"
        case accuracy = "accuracy"
        case streak = "streak"
        case xp = "xp"
        case diversity = "diversity"

        var icon: String {
            switch self {
            case .sessions: return "checkmark.circle.fill"
            case .accuracy: return "target"
            case .streak: return "flame.fill"
            case .xp: return "star.fill"
            case .diversity: return "brain.head.profile"
            }
        }
    }

    struct Reward: Codable {
        let xp: Int
        let badge: String
    }

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetValue) * 100, 100)
    }

    var timeRemaining: String {
        let timeInterval = endDate.timeIntervalSinceNow
        let days = Int(timeInterval / 86400)
        let hours = Int((timeInterval.truncatingRemainder(dividingBy: 86400)) / 3600)

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "< 1h"
        }
    }
}

struct SocialFeedItem: Identifiable, Codable {
    let id: UUID
    let user: SocialUser
    let activityType: ActivityType
    let description: String
    let timestamp: Date

    enum ActivityType: String, Codable {
        case achievementUnlocked = "achievement"
        case challengeCompleted = "challenge"
        case levelUp = "level_up"
        case streakMilestone = "streak"

        var icon: String {
            switch self {
            case .achievementUnlocked: return "trophy.fill"
            case .challengeCompleted: return "flag.checkered"
            case .levelUp: return "arrow.up.circle.fill"
            case .streakMilestone: return "flame.fill"
            }
        }

        var color: Color {
            switch self {
            case .achievementUnlocked: return .yellow
            case .challengeCompleted: return .green
            case .levelUp: return .blue
            case .streakMilestone: return .orange
            }
        }
    }

    var timeAgo: String {
        let timeInterval = Date().timeIntervalSince(timestamp)
        let minutes = Int(timeInterval / 60)
        let hours = Int(timeInterval / 3600)
        let days = Int(timeInterval / 86400)

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "agora"
        }
    }
}