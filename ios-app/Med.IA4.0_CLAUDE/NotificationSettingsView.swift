import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var notificationManager = SmartNotificationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var language: AppLanguage {
        userProfile.currentLanguage
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(language == .portuguese ? "Lembretes Diários" : "Daily Reminders")) {
                    Toggle(language == .portuguese ? "Lembretes Habilitados" : "Reminders Enabled",
                           isOn: $notificationManager.dailyRemindersEnabled)

                    if notificationManager.dailyRemindersEnabled {
                        DatePicker(language == .portuguese ? "Horário do Lembrete" : "Reminder Time",
                                 selection: $notificationManager.reminderTime,
                                 displayedComponents: .hourAndMinute)
                    }
                }

                Section(header: Text(language == .portuguese ? "Notificações de Conquista" : "Achievement Notifications")) {
                    Toggle(language == .portuguese ? "Conquistas" : "Achievements",
                           isOn: $notificationManager.achievementNotificationsEnabled)

                    Toggle(language == .portuguese ? "Marcos de Sequência" : "Streak Milestones",
                           isOn: $notificationManager.streakNotificationsEnabled)
                }

                Section(header: Text(language == .portuguese ? "Configurações Avançadas" : "Advanced Settings")) {
                    Toggle(language == .portuguese ? "Notificações Inteligentes" : "Smart Notifications",
                           isOn: $notificationManager.smartNotificationsEnabled)

                    if notificationManager.smartNotificationsEnabled {
                        Text(language == .portuguese ?
                             "Ajusta automaticamente com base no seu padrão de uso" :
                             "Automatically adjusts based on your usage pattern")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text(language == .portuguese ? "Estatísticas" : "Statistics")) {
                    HStack {
                        Text(language == .portuguese ? "Conquistas Desbloqueadas" : "Achievements Unlocked")
                        Spacer()
                        Text("\(notificationManager.achievements.filter { $0.isUnlocked }.count)/\(notificationManager.achievements.count)")
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text(language == .portuguese ? "Sequência Atual" : "Current Streak")
                        Spacer()
                        Text("\(notificationManager.currentStreak)")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle(language == .portuguese ? "Notificações" : "Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(themeManager.getColorScheme())
        .onAppear {
            checkNotificationPermission()
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus != .authorized {
                    // Handle permission request if needed
                }
            }
        }
    }
}