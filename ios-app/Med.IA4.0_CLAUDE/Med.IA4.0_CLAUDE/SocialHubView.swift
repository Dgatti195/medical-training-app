import SwiftUI

// MARK: - Social Hub View
struct SocialHubView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var socialManager = SocialFeaturesManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: SocialTab = .feed
    @State private var showingProfileSetup = false

    private var language: AppLanguage {
        userProfile.currentLanguage
    }

    enum SocialTab: String, CaseIterable {
        case feed = "feed"
        case leaderboards = "leaderboards"
        case groups = "groups"
        case challenges = "challenges"

        func getDisplayName(language: AppLanguage) -> String {
            switch self {
            case .feed:
                return language == .portuguese ? "Feed" : "Feed"
            case .leaderboards:
                return language == .portuguese ? "Rankings" : "Leaderboards"
            case .groups:
                return language == .portuguese ? "Grupos" : "Groups"
            case .challenges:
                return language == .portuguese ? "Desafios" : "Challenges"
            }
        }

        var icon: String {
            switch self {
            case .feed: return "house.fill"
            case .leaderboards: return "trophy.fill"
            case .groups: return "person.3.fill"
            case .challenges: return "flag.checkered"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if socialManager.currentUser == nil {
                    SocialProfileSetupView(socialManager: socialManager, language: language)
                } else {
                    // Tab selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(SocialTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    selectedTab = tab
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: tab.icon)
                                            .font(.title2)
                                        Text(tab.getDisplayName(language: language))
                                            .font(.caption)
                                    }
                                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)

                    Divider()

                    // Content based on selected tab
                    ScrollView {
                        switch selectedTab {
                        case .feed:
                            SocialFeedView(socialManager: socialManager, language: language)
                        case .leaderboards:
                            LeaderboardsView(socialManager: socialManager, language: language)
                        case .groups:
                            StudyGroupsView(socialManager: socialManager, language: language)
                        case .challenges:
                            ChallengesView(socialManager: socialManager, language: language)
                        }
                    }
                }
            }
            .navigationTitle(language == .portuguese ? "Hub Social" : "Social Hub")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let user = socialManager.currentUser {
                        HStack(spacing: 8) {
                            Image(systemName: user.avatarIcon)
                                .foregroundColor(.blue)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.nickname)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Nível \(user.level)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Social Profile Setup
struct SocialProfileSetupView: View {
    @ObservedObject var socialManager: SocialFeaturesManager
    let language: AppLanguage

    @State private var nickname = ""
    @State private var selectedAvatar = "stethoscope"

    private let avatarOptions = [
        "stethoscope", "heart.fill", "brain.head.profile", "cross.case.fill",
        "pills.fill", "syringe.fill", "lungs.fill", "eye.fill"
    ]

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text(language == .portuguese ? "Bem-vindo ao Hub Social!" : "Welcome to Social Hub!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(language == .portuguese ?
                     "Conecte-se com outros estudantes, participe de desafios e compare seu progresso!" :
                     "Connect with other students, participate in challenges, and compare your progress!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language == .portuguese ? "Seu Apelido" : "Your Nickname")
                        .font(.headline)

                    TextField(
                        language == .portuguese ? "Digite seu apelido" : "Enter your nickname",
                        text: $nickname
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(language == .portuguese ? "Escolha seu Avatar" : "Choose Your Avatar")
                        .font(.headline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(avatarOptions, id: \.self) { avatar in
                            Button(action: {
                                selectedAvatar = avatar
                            }) {
                                Image(systemName: avatar)
                                    .font(.title)
                                    .foregroundColor(selectedAvatar == avatar ? .white : .blue)
                                    .frame(width: 50, height: 50)
                                    .background(selectedAvatar == avatar ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }

            Button(action: {
                socialManager.createSocialUser(nickname: nickname, avatarIcon: selectedAvatar)
            }) {
                Text(language == .portuguese ? "Começar Jornada Social" : "Start Social Journey")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(nickname.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(nickname.isEmpty)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Social Feed View
struct SocialFeedView: View {
    @ObservedObject var socialManager: SocialFeaturesManager
    let language: AppLanguage

    var body: some View {
        LazyVStack(spacing: 16) {
            // Current user stats card
            if let user = socialManager.currentUser {
                UserStatsCard(user: user, language: language)
                    .padding(.horizontal)
            }

            // Active challenge preview
            if let challenge = socialManager.activeChallenge {
                ActiveChallengeCard(challenge: challenge, language: language)
                    .padding(.horizontal)
            }

            // Social feed
            VStack(alignment: .leading, spacing: 12) {
                Text(language == .portuguese ? "Atividades Recentes" : "Recent Activity")
                    .font(.headline)
                    .padding(.horizontal)

                LazyVStack(spacing: 8) {
                    ForEach(socialManager.socialFeed) { item in
                        SocialFeedItemView(item: item, language: language)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - User Stats Card
struct UserStatsCard: View {
    let user: SocialUser
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: user.avatarIcon)
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.nickname)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(language == .portuguese ? "Nível" : "Level") \(user.level)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(user.totalXP) XP")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("\(user.xpToNextLevel) \(language == .portuguese ? "até próximo nível" : "to next level")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar to next level
            ProgressView(value: Double(user.totalXP % 100) / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

            HStack {
                StatBubble(
                    icon: "flame.fill",
                    value: "\(user.streak)",
                    label: language == .portuguese ? "Dias" : "Days",
                    color: .orange
                )

                StatBubble(
                    icon: "calendar",
                    value: formatJoinDate(user.joinDate),
                    label: language == .portuguese ? "Membro" : "Member",
                    color: .green
                )

                StatBubble(
                    icon: "crown.fill",
                    value: "\(user.level)",
                    label: language == .portuguese ? "Nível" : "Level",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func formatJoinDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 30 {
            return "\(days)d"
        } else {
            let months = days / 30
            return "\(months)m"
        }
    }
}

// MARK: - Stat Bubble
struct StatBubble: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Active Challenge Card
struct ActiveChallengeCard: View {
    let challenge: Challenge
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: challenge.type.icon)
                    .foregroundColor(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(challenge.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(challenge.timeRemaining)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)

                    Text(language == .portuguese ? "restante" : "remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            ProgressView(value: challenge.progressPercentage / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

            HStack {
                Text("\(challenge.currentProgress)/\(challenge.targetValue)")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text("🏆 +\(challenge.reward.xp) XP")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Social Feed Item View
struct SocialFeedItemView: View {
    let item: SocialFeedItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.user.avatarIcon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.user.nickname)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Image(systemName: item.activityType.icon)
                        .foregroundColor(item.activityType.color)
                        .font(.caption)

                    Spacer()

                    Text(item.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Leaderboards View
struct LeaderboardsView: View {
    @ObservedObject var socialManager: SocialFeaturesManager
    let language: AppLanguage

    @State private var selectedLeaderboard = 0

    var body: some View {
        VStack(spacing: 20) {
            // Leaderboard selector
            Picker("Leaderboard", selection: $selectedLeaderboard) {
                ForEach(Array(socialManager.leaderboards.enumerated()), id: \.offset) { index, leaderboard in
                    Text(leaderboard.title)
                        .tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            if socialManager.leaderboards.indices.contains(selectedLeaderboard) {
                let leaderboard = socialManager.leaderboards[selectedLeaderboard]

                LazyVStack(spacing: 8) {
                    ForEach(Array(leaderboard.users.prefix(10).enumerated()), id: \.offset) { index, user in
                        LeaderboardRow(
                            rank: index + 1,
                            user: user,
                            leaderboardType: leaderboard.type,
                            isCurrentUser: user.id == socialManager.currentUser?.id,
                            language: language
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let rank: Int
    let user: SocialUser
    let leaderboardType: Leaderboard.LeaderboardType
    let isCurrentUser: Bool
    let language: AppLanguage

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }

    private var metricValue: String {
        switch leaderboardType {
        case .xp: return "\(user.totalXP)"
        case .streak: return "\(user.streak)"
        case .level: return "\(user.level)"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 32, height: 32)

                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rank <= 3 ? .white : .primary)
            }

            // User info
            HStack(spacing: 12) {
                Image(systemName: user.avatarIcon)
                    .foregroundColor(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.nickname)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isCurrentUser ? .blue : .primary)

                    Text("\(language == .portuguese ? "Nível" : "Level") \(user.level)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(metricValue)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(leaderboardType.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Study Groups View
struct StudyGroupsView: View {
    @ObservedObject var socialManager: SocialFeaturesManager
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(language == .portuguese ? "Grupos de Estudo" : "Study Groups")
                    .font(.headline)

                Spacer()

                Button(language == .portuguese ? "Criar Grupo" : "Create Group") {
                    // Create group functionality
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.horizontal)

            LazyVStack(spacing: 12) {
                ForEach(socialManager.studyGroups) { group in
                    StudyGroupCard(
                        group: group,
                        language: language,
                        onJoin: {
                            socialManager.joinStudyGroup(group)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Study Group Card
struct StudyGroupCard: View {
    let group: StudyGroup
    let language: AppLanguage
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(group.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(group.formattedMemberCount)")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(language == .portuguese ? "membros" : "members")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(group.description)
                .font(.body)
                .foregroundColor(.secondary)

            HStack {
                Text(formatCreatedDate(group.createdDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button(language == .portuguese ? "Entrar" : "Join") {
                    onJoin()
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func formatCreatedDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 {
            return language == .portuguese ? "Criado hoje" : "Created today"
        } else if days == 1 {
            return language == .portuguese ? "Criado ontem" : "Created yesterday"
        } else if days < 7 {
            return language == .portuguese ? "Criado há \(days) dias" : "Created \(days) days ago"
        } else {
            let weeks = days / 7
            return language == .portuguese ? "Criado há \(weeks) semana(s)" : "Created \(weeks) week(s) ago"
        }
    }
}

// MARK: - Challenges View
struct ChallengesView: View {
    @ObservedObject var socialManager: SocialFeaturesManager
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Active Challenge
            if let challenge = socialManager.activeChallenge {
                VStack(alignment: .leading, spacing: 12) {
                    Text(language == .portuguese ? "Desafio Ativo" : "Active Challenge")
                        .font(.headline)
                        .padding(.horizontal)

                    ChallengeCard(challenge: challenge, isActive: true, language: language)
                        .padding(.horizontal)
                }
            }

            // Completed Challenges
            if !socialManager.completedChallenges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(language == .portuguese ? "Desafios Completados" : "Completed Challenges")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVStack(spacing: 8) {
                        ForEach(socialManager.completedChallenges.prefix(5)) { challenge in
                            ChallengeCard(challenge: challenge, isActive: false, language: language)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Challenge Card
struct ChallengeCard: View {
    let challenge: Challenge
    let isActive: Bool
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: challenge.type.icon)
                    .foregroundColor(isActive ? .blue : .gray)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(challenge.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if challenge.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else if isActive {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(challenge.timeRemaining)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)

                        Text(language == .portuguese ? "restante" : "remaining")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !challenge.isCompleted {
                ProgressView(value: challenge.progressPercentage / 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: isActive ? .blue : .gray))

                HStack {
                    Text("\(challenge.currentProgress)/\(challenge.targetValue)")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Text("🏆 +\(challenge.reward.xp) XP")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .fontWeight(.medium)
                }
            } else {
                HStack {
                    Text(language == .portuguese ? "✅ Completado!" : "✅ Completed!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)

                    Spacer()

                    Text("🏆 +\(challenge.reward.xp) XP \(language == .portuguese ? "ganhos" : "earned")")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .opacity(challenge.isCompleted ? 0.7 : 1.0)
    }
}