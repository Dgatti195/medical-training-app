import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @StateObject private var dataManager = MedicalDatabaseManager()
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var progressTracker = ProgressTracker.shared
    @StateObject private var uxManager = UXEnhancementManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var ratingManager = CaseDifficultyRatingManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingProfile = false
    @State private var showingAnalytics = false
    @State private var showingProgress = false
    @State private var showingNotificationSettings = false
    @State private var showingSocialHub = false
    @State private var showingThemeSettings = false
    @State private var showingStudyTools = false
    @State private var showingHistory = false

    // Smart Search Features
    @State private var recentSearches: [String] = []
    @State private var showingSuggestions = false
    @State private var favoriteConditions: [String] = []
    @State private var showingFavorites = false
    @State private var searchHistory: [String] = []

    // Session Tracking
    @State private var sessionStartTime = Date()

    // Difficulty Selection
    @State private var selectedMode: TrainingMode = .clinical
    @State private var selectedDifficulty: DifficultyLevel = .intermediate
    @State private var showingDifficultyPicker = false
    @State private var selectedDisease: Disease?
    @State private var navigationTrigger: Int?

    // UPDATED: Dynamic categories instead of hardcoded
    private var categories: [String] {
        ["All"] + dataManager.getAllCategories()
    }

    // Search suggestions based on current input
    private var searchSuggestions: [Disease] {
        guard !searchText.isEmpty && searchText.count >= 2 else { return [] }
        return dataManager.diseases.filter { disease in
            disease.nameEnglish.localizedCaseInsensitiveContains(searchText) ||
            disease.namePortuguese.localizedCaseInsensitiveContains(searchText)
        }.prefix(5).map { $0 }
    }

    // Favorite filtered diseases
    private var favoriteFilteredDiseases: [Disease] {
        return dataManager.diseases.filter { disease in
            favoriteConditions.contains(disease.nameEnglish)
        }
    }

    var filteredDiseases: [Disease] {
        let baseDiseases = showingFavorites ? favoriteFilteredDiseases : dataManager.diseases

        let categoryFiltered = selectedCategory == "All" ?
            baseDiseases :
            baseDiseases.filter { $0.category == selectedCategory }

        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { disease in
                let matchesEnglish = disease.nameEnglish.localizedCaseInsensitiveContains(searchText)
                let matchesPortuguese = disease.namePortuguese.localizedCaseInsensitiveContains(searchText)
                return matchesEnglish || matchesPortuguese
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Network Status Banner
                NetworkStatusBanner(language: userProfile.currentLanguage)

                VStack {
                // Enhanced Search Section
                VStack(spacing: 12) {
                    // Progress Summary Bar - All in one line
                    HStack(spacing: 8) {
                        // Daily streak indicator
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .adaptiveCaption()
                            Text("\(progressTracker.currentStreak)")
                                .adaptiveCaption()
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)

                        // Today's sessions
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .adaptiveCaption()
                            Text("\(progressTracker.todayProgress.sessionsCompleted)")
                                .adaptiveCaption()
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)

                        Spacer()

                        // Favorites button
                        HapticButton(
                            action: {
                                showingFavorites.toggle()
                            },
                            hapticStyle: .selection
                        ) {
                            HStack(spacing: 4) {
                                Image(systemName: showingFavorites ? "heart.fill" : "heart")
                                    .foregroundColor(showingFavorites ? .red : .secondary)
                                    .adaptiveCaption()
                            }
                        }
                        .accessibilityLabel(showingFavorites
                            ? (userProfile.currentLanguage == .portuguese ? "Ocultar Favoritos" : "Hide Favorites")
                            : (userProfile.currentLanguage == .portuguese ? "Mostrar Favoritos" : "Show Favorites"))
                        .accessibilityIdentifier("favoritesToggleButton")

                        // Progress button
                        HapticButton(
                            action: {
                                showingProgress = true
                            },
                            hapticStyle: .light
                        ) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .adaptiveCaption()
                            }
                            .foregroundColor(.blue)
                        }
                        .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Ver Progresso" : "View Progress")
                        .accessibilityIdentifier("viewProgressButton")

                        // Random button
                        HapticButton(
                            action: {
                                // Random case functionality
                                if let randomDisease = dataManager.diseases.randomElement() {
                                    searchText = ""
                                    selectedCategory = randomDisease.category
                                    uxManager.showLoading(
                                        message: uxManager.getContextualLoadingMessage(for: .patientData, language: userProfile.currentLanguage),
                                        estimatedTime: uxManager.getEstimatedLoadTime(for: .patientData)
                                    )
                                }
                            },
                            hapticStyle: .medium
                        ) {
                            HStack(spacing: 4) {
                                Image(systemName: "dice")
                                    .adaptiveCaption()
                            }
                            .foregroundColor(.blue)
                        }
                        .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Caso Aleatório" : "Random Case")
                        .accessibilityIdentifier("randomCaseButton")
                    }
                    .adaptivePadding(.horizontal)

                    // Search Bar
                    VStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)

                            TextField(userProfile.currentLanguage == .portuguese ? "Buscar condições..." : "Search conditions...", text: $searchText)
                                .textFieldStyle(.plain)
                                .accessibilityIdentifier("searchField")
                                .onChange(of: searchText) { oldValue, newValue in
                                    showingSuggestions = !newValue.isEmpty && newValue.count >= 2
                                }
                                .onSubmit {
                                    self.addToSearchHistory(searchText)
                                    showingSuggestions = false
                                }

                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    showingSuggestions = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Limpar Busca" : "Clear Search")
                                .accessibilityIdentifier("clearSearchButton")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                        // Search Suggestions Dropdown
                        if showingSuggestions && !searchSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(searchSuggestions, id: \.nameEnglish) { suggestion in
                                    Button(action: {
                                        let name = userProfile.currentLanguage == .portuguese ? suggestion.namePortuguese : suggestion.nameEnglish
                                        searchText = name
                                        self.addToSearchHistory(name)
                                        showingSuggestions = false
                                    }) {
                                        HStack {
                                            Text(userProfile.currentLanguage == .portuguese ? suggestion.namePortuguese : suggestion.nameEnglish)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text(translateMedicalCategory(suggestion.category, to: userProfile.currentLanguage))
                                                .adaptiveCaption()
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    .background(Color(.systemBackground))

                                    if suggestion.nameEnglish != searchSuggestions.last?.nameEnglish {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .frame(maxWidth: .infinity)
                        }

                        // Recent Searches
                        if searchText.isEmpty && !recentSearches.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(recentSearches.prefix(5), id: \.self) { recentSearch in
                                        Button(recentSearch) {
                                            searchText = recentSearch
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(15)
                                        .adaptiveCaption()
                                    }
                                }
                                .adaptivePadding(.horizontal)
                            }
                        }
                    }
                }
                .adaptivePadding(.horizontal)

                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(categories, id: \.self) { category in
                            Button(translateMedicalCategory(category, to: userProfile.currentLanguage)) {
                                selectedCategory = category
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .cornerRadius(20)
                            .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                        }
                    }
                    .adaptivePadding(.horizontal)
                }

                // Disease list — skeleton while loading, error state, or real list
                if dataManager.isLoading {
                    List {
                        ForEach(0..<8, id: \.self) { _ in
                            DiseaseSkeletonRow()
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                } else if let error = dataManager.loadingError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text(userProfile.currentLanguage == .portuguese ? "Erro no Banco de Dados" : "Database Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .adaptiveCaption()
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(userProfile.currentLanguage == .portuguese ? "Tentar Novamente" : "Retry") {
                            dataManager.refreshData()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    if dataManager.diseases.count < 400 {
                        VStack(spacing: 6) {
                            Text(userProfile.currentLanguage == .portuguese ?
                                 "Banco de dados incompleto (\(dataManager.diseases.count) condições)" :
                                 "Database incomplete (\(dataManager.diseases.count) conditions)")
                                .adaptiveCaption()
                                .foregroundColor(.orange)
                            Button(userProfile.currentLanguage == .portuguese ?
                                   "Atualizar Banco de Dados" : "Update Database") {
                                dataManager.forceUpdateDatabase()
                            }
                            .adaptiveCaption()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                    }

                    List(filteredDiseases) { disease in
                        ZStack {
                            NavigationLink(
                                destination: Group {
                                    if userProfile.profile.preferredTrainingMode == .clinical {
                                        PatientSimulationView(disease: disease, difficulty: selectedDifficulty)
                                            .environmentObject(dataManager)
                                    } else {
                                        BasicModePatientSimulationView(disease: disease)
                                            .environmentObject(dataManager)
                                            .environmentObject(userProfile)
                                    }
                                },
                                tag: disease.id,
                                selection: $navigationTrigger
                            ) {
                                EmptyView()
                            }
                            .opacity(0)

                            Button(action: {
                                selectedDisease = disease
                                let preferredMode = userProfile.profile.preferredTrainingMode
                                if preferredMode == .basic {
                                    navigationTrigger = disease.id
                                } else {
                                    showingDifficultyPicker = true
                                }
                            }) {
                                HStack {
                                    PatientRowView(
                                        disease: disease,
                                        language: userProfile.currentLanguage,
                                        isRecommended: ratingManager.isRecommended(
                                            for: disease.nameEnglish,
                                            accuracy: userProfile.profile.accuracyPercentage / 100.0
                                        )
                                    )
                                    .environmentObject(dataManager)

                                    Spacer()

                                    HapticButton(
                                        action: {
                                            self.toggleFavorite(for: disease)
                                        },
                                        hapticStyle: favoriteConditions.contains(disease.nameEnglish) ? .success : .light
                                    ) {
                                        Image(systemName: favoriteConditions.contains(disease.nameEnglish) ? "heart.fill" : "heart")
                                            .foregroundColor(favoriteConditions.contains(disease.nameEnglish) ? .red : .gray)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .accessibilityLabel(favoriteConditions.contains(disease.nameEnglish)
                                        ? (userProfile.currentLanguage == .portuguese ? "Remover dos Favoritos" : "Remove from Favorites")
                                        : (userProfile.currentLanguage == .portuguese ? "Adicionar aos Favoritos" : "Add to Favorites"))
                                    .accessibilityIdentifier("favoriteButton_\(disease.nameEnglish)")
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .swipeActions(edge: .trailing) {
                            Button(action: {
                                self.toggleFavorite(for: disease)
                            }) {
                                Label(
                                    favoriteConditions.contains(disease.nameEnglish) ?
                                    (userProfile.currentLanguage == .portuguese ? "Remover dos Favoritos" : "Remove from Favorites") :
                                    (userProfile.currentLanguage == .portuguese ? "Adicionar aos Favoritos" : "Add to Favorites"),
                                    systemImage: favoriteConditions.contains(disease.nameEnglish) ? "heart.slash" : "heart"
                                )
                            }
                            .tint(favoriteConditions.contains(disease.nameEnglish) ? .gray : .red)
                        }
                    }
                }
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(userProfile.currentLanguage == .portuguese ? "Base de Dados Médica" : "Medical Database")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingProfile = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                    .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Ver Perfil" : "View Profile")
                    .accessibilityIdentifier("profileButton")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        ConnectionStatusIndicator(language: userProfile.currentLanguage)

                        // Keep most important buttons visible
                        Button(action: {
                            showingHistory = true
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                        }
                        .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Ver Histórico" : "View History")
                        .accessibilityIdentifier("historyButton")

                        Button(action: {
                            showingAnalytics = true
                        }) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.title2)
                        }
                        .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Ver Análises" : "View Analytics")
                        .accessibilityIdentifier("analyticsButton")

                        // Group less frequently used features in a menu
                        Menu {
                            Button(action: {
                                showingSocialHub = true
                            }) {
                                Label(userProfile.currentLanguage == .portuguese ? "Hub Social" : "Social Hub",
                                      systemImage: "person.3.fill")
                            }

                            Button(action: {
                                showingNotificationSettings = true
                            }) {
                                Label(userProfile.currentLanguage == .portuguese ? "Notificações" : "Notifications",
                                      systemImage: "bell")
                            }

                            Button(action: {
                                showingThemeSettings = true
                            }) {
                                Label(userProfile.currentLanguage == .portuguese ? "Temas" : "Theme",
                                      systemImage: "paintbrush.fill")
                            }

                            Button(action: {
                                showingStudyTools = true
                            }) {
                                Label(userProfile.currentLanguage == .portuguese ? "Ferramentas" : "Study Tools",
                                      systemImage: "folder.badge.gearshape")
                            }

                            Divider()

                            NavigationLink(destination: APIKeySettingsView(language: userProfile.currentLanguage)) {
                                Label(userProfile.currentLanguage == .portuguese ? "Configurações" : "Settings",
                                      systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                        }
                        .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Mais Opções" : "More Options")
                        .accessibilityIdentifier("moreOptionsMenu")
                    }
                }
            }
            .adaptiveFullSheet(isPresented: $showingProfile) {
                UserProfileView()
                    .environmentObject(userProfile)
            }
            .adaptiveFullSheet(isPresented: $showingAnalytics) {
                CleanAnalyticsView()
                    .environmentObject(userProfile)
            }
            .adaptiveFullSheet(isPresented: $showingProgress) {
                ProgressDashboardView()
                    .environmentObject(userProfile)
            }
            .adaptiveFullSheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
                    .environmentObject(userProfile)
            }
            .adaptiveFullSheet(isPresented: $showingSocialHub) {
                SocialHubView()
                    .environmentObject(userProfile)
            }
            .adaptiveFullSheet(isPresented: $showingThemeSettings) {
                ThemeSettingsView()
                    .environmentObject(userProfile)
            }
            .adaptiveFullSheet(isPresented: $showingStudyTools) {
                StudyToolsView()
                    .environmentObject(userProfile)
            }
            .adaptiveFullSheet(isPresented: $showingHistory) {
                SessionHistoryView(language: userProfile.currentLanguage)
                    .environmentObject(userProfile)
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingDifficultyPicker) {
                DifficultyPickerView(
                    selectedMode: $selectedMode,
                    selectedDifficulty: $selectedDifficulty,
                    language: userProfile.currentLanguage,
                    onStart: {
                        showingDifficultyPicker = false
                        if let disease = selectedDisease {
                            navigationTrigger = disease.id
                        }
                    }
                )
                .presentationDetents([.large])
            }
            .onAppear {
                self.loadRecentSearches()
                self.loadFavorites()
                progressTracker.startStudySession()
            }
            .overlay(
                GlobalLoadingOverlay(language: userProfile.currentLanguage)
            )
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(themeManager.getColorScheme())
    }

    // MARK: - Helper Functions for Smart Search
    private func addToSearchHistory(_ search: String) {
        guard !search.isEmpty && !self.recentSearches.contains(search) else { return }
        self.recentSearches.insert(search, at: 0)
        if self.recentSearches.count > 5 {
            self.recentSearches.removeLast()
        }
        UserDefaults.standard.set(self.recentSearches, forKey: "RecentSearches")
    }

    private func loadRecentSearches() {
        self.recentSearches = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    }

    private func toggleFavorite(for disease: Disease) {
        let diseaseName = disease.nameEnglish
        if self.favoriteConditions.contains(diseaseName) {
            self.favoriteConditions.removeAll { $0 == diseaseName }
        } else {
            self.favoriteConditions.append(diseaseName)
        }
        UserDefaults.standard.set(self.favoriteConditions, forKey: "FavoriteConditions")
    }

    private func loadFavorites() {
        self.favoriteConditions = UserDefaults.standard.stringArray(forKey: "FavoriteConditions") ?? []
    }
}

// MARK: - Patient Row View
struct PatientRowView: View {
    let disease: Disease
    let language: AppLanguage
    /// Whether this case is recommended for the student's current skill level (task 3.4).
    var isRecommended: Bool = false
    @EnvironmentObject var dataManager: MedicalDatabaseManager
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var studyToolsManager = StudyToolsManager.shared
    @StateObject private var ratingManager = CaseDifficultyRatingManager.shared

    private var categoryColor: Color {
        switch disease.category {
        case "Gastrointestinal": return .orange
        case "Neurological": return .purple
        case "Respiratory": return .blue
        case "Cardiovascular": return .red
        case "Endocrine": return .green
        default: return .gray
        }
    }

    var body: some View {
        let resolvedCase = dataManager.getPatientCase(for: disease)
        return VStack(alignment: .leading, spacing: 8) {
            // Patient name (disease name hidden - user must diagnose)
            if let patientCase = resolvedCase {
                Text(patientCase.demographics.name)
                    .adaptiveHeadline()
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(language == .portuguese ? "Queixa Principal:" : "Chief Complaint:")
                        .adaptiveCaption()
                        .foregroundColor(.secondary)

                    let chiefComplaints = patientCase.presentingSymptoms.filter { $0.isChiefComplaint }

                    if chiefComplaints.isEmpty {
                        // Fallback: show first 2 symptoms when no chief complaint is flagged
                        ForEach(patientCase.presentingSymptoms.prefix(2), id: \.id) { symptom in
                            Text("• \(symptom.getText(language))")
                                .adaptiveCaption()
                                .foregroundColor(.primary)
                        }
                    } else {
                        ForEach(chiefComplaints, id: \.id) { symptom in
                            Text("• \(symptom.getText(language))")
                                .adaptiveCaption()
                                .foregroundColor(.primary)
                        }
                    }


                }

                HStack {
                    Text(translateMedicalCategory(disease.category, to: language))
                        .adaptiveCaption()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.2))
                        .foregroundColor(categoryColor)
                        .cornerRadius(8)

                    // Difficulty Rating (computed from DB)
                    DifficultyRatingView(difficulty: disease.computedDifficulty)

                    // Student-rated difficulty (task 3.4)
                    if let avg = ratingManager.averageRating(for: disease.nameEnglish) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .adaptiveCaption2()
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", avg))
                                .adaptiveCaption2()
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Recommended badge (task 3.4)
                    if isRecommended {
                        Text(language == .portuguese ? "Recomendado" : "Recommended")
                            .adaptiveCaption2()
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(6)
                    }

                    Button(action: {
                        studyToolsManager.toggleBookmark(for: disease.nameEnglish)
                    }) {
                        Image(systemName: studyToolsManager.isBookmarked(disease.nameEnglish) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(studyToolsManager.isBookmarked(disease.nameEnglish) ? .blue : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if userProfile.profile.preferredTrainingMode == .basic {
                        Text(language == .portuguese ? "Treino de Anamnese" : "Anamnesis Training")
                            .adaptiveCaption()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    } else {
                        Text(language == .portuguese ? "Desafio Diagnóstico" : "Diagnostic Challenge")
                            .adaptiveCaption()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            } else {
                Text(disease.getDisplayName(language))
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Loading patient data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .adaptivePadding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel(for: resolvedCase))
        .accessibilityHint(language == .portuguese ? "Toque duplo para iniciar uma sessão" : "Double tap to start a session")
    }

    private func buildAccessibilityLabel(for patientCase: PatientCase?) -> String {
        let translatedCategory = translateMedicalCategory(disease.category, to: language)
        let difficultyText: String
        switch disease.computedDifficulty {
        case 1, 2: difficultyText = language == .portuguese ? "Fácil" : "Easy"
        case 3:    difficultyText = language == .portuguese ? "Intermediário" : "Intermediate"
        case 4:    difficultyText = language == .portuguese ? "Avançado" : "Advanced"
        default:   difficultyText = language == .portuguese ? "Especialista" : "Expert"
        }
        let name = patientCase?.demographics.name ?? (language == .portuguese ? "Paciente" : "Patient")
        let recommended = isRecommended ? (language == .portuguese ? " Recomendado." : " Recommended.") : ""
        if language == .portuguese {
            return "\(name). Caso de \(translatedCategory). Dificuldade: \(difficultyText).\(recommended)"
        } else {
            return "\(name). \(translatedCategory) case. Difficulty: \(difficultyText).\(recommended)"
        }
    }
}

// MARK: - Skeleton Loading Row
/// Placeholder row shown while the disease database is loading.
struct DiseaseSkeletonRow: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            VStack(alignment: .leading, spacing: 8) {
                // Patient name placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(isAnimating ? 0.25 : 0.12))
                    .frame(height: 18)
                    .frame(maxWidth: w * 0.45)

                // Chief complaint label placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                    .frame(height: 12)
                    .frame(maxWidth: w * 0.25)

                // Symptom lines
                ForEach(0..<2, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                        .frame(height: 12)
                        .frame(maxWidth: i == 0 ? w * 0.55 : w * 0.40)
                }

                // Badges row
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(isAnimating ? 0.25 : 0.12))
                        .frame(maxWidth: w * 0.20, minHeight: 24, maxHeight: 24)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                        .frame(maxWidth: w * 0.14, minHeight: 24, maxHeight: 24)
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(isAnimating ? 0.25 : 0.12))
                        .frame(maxWidth: w * 0.30, minHeight: 24, maxHeight: 24)
                }
            }
        }
        .frame(height: 110)
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
