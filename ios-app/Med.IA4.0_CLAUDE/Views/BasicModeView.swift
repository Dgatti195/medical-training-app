import SwiftUI
import Foundation

// MARK: - Basic Mode Patient Simulation View (Anamnese Training)
struct BasicModePatientSimulationView: View {
    let disease: Disease
    @EnvironmentObject var userProfile: UserProfileManager
    @EnvironmentObject var dataManager: MedicalDatabaseManager
    @StateObject private var aiService = ClaudeAIService()
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    // Session State
    @State private var session = BasicModeSession()
    @State private var conversationHistory: [(question: String, answer: String, detectedQuestionId: Int?)] = []
    @State private var currentMessage = ""
    @State private var isLoading = false
    @State private var showingChecklist = true
    @State private var showingResults = false
    @State private var sessionResult: BasicModeResult?
    @State private var showingAPIError = false
    @State private var apiErrorMessage = ""

    // Patient case
    @State private var patientCase: PatientCase?
    @State private var patientData: [String: String] = [:]

    // Section timing: first question timestamp per section
    @State private var sectionFirstAsked: [AnamneseSection: Date] = [:]

    private var language: AppLanguage {
        userProfile.currentLanguage
    }

    private let questionDatabase = AnamneseQuestionDatabase.shared

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Sidebar: Checklist
                if showingChecklist {
                    checklistSidebar
                        .frame(width: geometry.size.width * 0.45)
                        .background(Color(.systemGray6))
                }

                // Main Content: Conversation
                VStack(spacing: 0) {
                    // Header
                    headerView

                    Divider()

                    // Conversation Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Welcome message
                                welcomeMessage

                                // Conversation messages
                                ForEach(conversationHistory.indices, id: \.self) { index in
                                    let item = conversationHistory[index]

                                    // User question
                                    HStack {
                                        Spacer()
                                        Text(item.question)
                                            .padding(12)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(12)
                                            .frame(maxWidth: geometry.size.width * 0.6, alignment: .trailing)
                                    }
                                    .id("question-\(index)")

                                    // Patient answer
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.answer)
                                                .padding(12)
                                                .background(Color(.systemGray5))
                                                .cornerRadius(12)

                                            // Show detected question if matched
                                            if let questionId = item.detectedQuestionId,
                                               let question = questionDatabase.allQuestions.first(where: { $0.id == questionId }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(.green)
                                                    Text(question.getText(language))
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                        .italic()
                                                }
                                                .padding(.leading, 12)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .frame(maxWidth: geometry.size.width * 0.6, alignment: .leading)
                                    .id("answer-\(index)")
                                }

                                if isLoading {
                                    HStack {
                                        ProgressView()
                                            .padding(12)
                                        Spacer()
                                    }
                                    .id("loading")
                                }
                            }
                            .padding()
                        }
                        .onChangeCompat(of: conversationHistory.count) { newCount in
                            withAnimation {
                                if newCount > 0 {
                                    proxy.scrollTo("answer-\(newCount - 1)", anchor: .bottom)
                                }
                            }
                        }
                        .onChangeCompat(of: isLoading) { loading in
                            if loading {
                                withAnimation {
                                    proxy.scrollTo("loading", anchor: .bottom)
                                }
                            }
                        }
                    }

                    Divider()

                    // Input Area
                    inputArea
                }
            }
        }
        .navigationTitle(language == .portuguese ? "Treinamento de Anamnese" : "Anamnese Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingChecklist.toggle()
                }) {
                    Image(systemName: showingChecklist ? "sidebar.left" : "sidebar.left.slash")
                }
                .accessibilityLabel(showingChecklist
                    ? (language == .portuguese ? "Ocultar Roteiro" : "Hide Checklist")
                    : (language == .portuguese ? "Mostrar Roteiro" : "Show Checklist"))
                .accessibilityIdentifier("toggleChecklistButton")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(language == .portuguese ? "Finalizar" : "Finish") {
                    finishSession()
                }
                .disabled(conversationHistory.isEmpty)
            }
        }
        .sheet(isPresented: $showingResults, onDismiss: {
            dismiss()
        }) {
            if let result = sessionResult {
                BasicModeResultsView(
                    result: result,
                    disease: disease,
                    language: language,
                    onDismiss: {
                        showingResults = false
                    }
                )
            }
        }
        .onAppear {
            initializeSession()
        }
        .alert(
            language == .portuguese ? "Erro" : "Error",
            isPresented: $showingAPIError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(apiErrorMessage)
        }
        .preferredColorScheme(themeManager.getColorScheme())
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let patientCase = patientCase {
                HStack {
                    // Mode indicator
                    Text(language == .portuguese ? "BÁSICO" : "BASIC")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(6)

                    Text(patientCase.demographics.name)
                        .font(.headline)

                    Spacer()
                }

                HStack(spacing: 16) {
                    Label("\(patientCase.demographics.age) \(language == .portuguese ? "anos" : "years")", systemImage: "person.fill")
                    Label(patientCase.demographics.gender, systemImage: "heart.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text(disease.getDisplayName(language))
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
    }

    private var welcomeMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .portuguese ? "Bem-vindo!" : "Welcome!")
                .font(.headline)

            Text(language == .portuguese ?
                 "Conduza uma anamnese completa seguindo as seções na ordem. O paciente responderá suas perguntas de forma direta e objetiva." :
                 "Conduct a complete anamnesis following the sections in order. The patient will answer your questions directly and objectively.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(language == .portuguese ?
                 "Dica: Comece pela identificação do paciente." :
                 "Tip: Start with patient identification.")
                .font(.caption)
                .foregroundColor(.blue)
                .italic()
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }

    private var checklistSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(language == .portuguese ? "Roteiro" : "Checklist")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Progress Summary
                let progress = calculateProgress()
                VStack(spacing: 6) {
                    HStack {
                        Text(language == .portuguese ? "Progresso:" : "Progress:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(progress.asked)/\(progress.total)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    ProgressView(value: Double(progress.asked), total: Double(progress.total))
                        .tint(.blue)
                        .scaleEffect(x: 1, y: 1.2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .padding(.horizontal, 8)

                Divider()

                // Sections
                ForEach(AnamneseSection.allCases, id: \.self) { section in
                    sectionRow(for: section)
                }
            }
            .padding(.vertical)
        }
    }

    private func sectionRow(for section: AnamneseSection) -> some View {
        let questions = questionDatabase.getQuestions(for: section)
        let askedCount = questions.filter { session.questionsAsked.contains($0.id) }.count
        let totalCount = questions.count
        let isComplete = askedCount == totalCount
        let isActive = !isComplete && (section.rawValue == 1 ||
                       questionDatabase.getQuestions(for: AnamneseSection(rawValue: section.rawValue - 1) ?? .identification)
                           .allSatisfy { session.questionsAsked.contains($0.id) })

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                // Status icon
                Image(systemName: isComplete ? "checkmark.circle.fill" :
                                   isActive ? "circle.fill" : "circle")
                    .foregroundColor(isComplete ? .green : isActive ? .blue : .gray)
                    .font(.caption2)
                    .frame(width: 12)

                // Section name
                Text(section.displayName(language))
                    .font(.caption)
                    .fontWeight(isActive ? .bold : .medium)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                // Count
                Text("\(askedCount)/\(totalCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize()
            }

            // Progress bar for this section
            ProgressView(value: Double(askedCount), total: Double(totalCount))
                .tint(isComplete ? .green : .blue)
                .scaleEffect(x: 1, y: 0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isActive ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 4)
    }

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField(
                language == .portuguese ? "Digite sua pergunta..." : "Type your question...",
                text: $currentMessage,
                axis: .vertical
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .lineLimit(1...3)
            .disabled(isLoading)
            .onSubmit {
                sendMessage()
            }
            .accessibilityIdentifier("basicModeQuestionTextField")

            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(currentMessage.isEmpty ? .gray : .blue)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(currentMessage.isEmpty || isLoading)
            .accessibilityLabel(language == .portuguese ? "Enviar Pergunta" : "Send Question")
            .accessibilityIdentifier("basicModeSendButton")
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Session Management

    private func initializeSession() {
        session = BasicModeSession()
        patientCase = dataManager.getPatientCase(for: disease)
        generatePatientData()
    }

    private func generatePatientData() {
        guard let patientCase = patientCase else { return }

        // Build chief complaint from presenting symptoms
        let chiefComplaints = patientCase.presentingSymptoms.filter { $0.isChiefComplaint }
        let chiefComplaintText = chiefComplaints.isEmpty ?
            patientCase.presentingSymptoms.first?.getText(language) ?? "" :
            chiefComplaints.first?.getText(language) ?? ""

        // Build comprehensive patient data dictionary for all anamnese questions
        patientData = [
            "name": patientCase.demographics.name,
            "age": "\(patientCase.demographics.age)",
            "gender": patientCase.demographics.gender,
            "birthplace": "São Paulo", // Default values
            "residence": "São Paulo",
            "chiefComplaint": chiefComplaintText,
            // Will be expanded with more data
        ]
    }

    private func sendMessage() {
        guard !currentMessage.isEmpty else { return }

        let userQuestion = currentMessage
        currentMessage = ""
        isLoading = true

        Task {
            do {
                // Step 1: Detect which question was asked (non-throwing — returns nil on error)
                let detectedQuestionId = await aiService.detectQuestion(
                    userQuestion: userQuestion,
                    questionDatabase: questionDatabase,
                    language: language
                )

                // Step 2: Generate simple patient response
                let patientAnswer = try await aiService.generateBasicModeResponse(
                    question: userQuestion,
                    patientCase: patientCase,
                    language: language
                )

                // Step 3: Update session
                await MainActor.run {
                    if let questionId = detectedQuestionId {
                        session.questionsAsked.insert(questionId)
                        session.questionOrder.append(questionId)

                        // Update current section based on question
                        if let question = questionDatabase.allQuestions.first(where: { $0.id == questionId }) {
                            session.currentSection = question.section
                            // Record the first time this section was entered
                            if sectionFirstAsked[question.section] == nil {
                                sectionFirstAsked[question.section] = Date()
                            }
                        }
                    }

                    conversationHistory.append((
                        question: userQuestion,
                        answer: patientAnswer,
                        detectedQuestionId: detectedQuestionId
                    ))

                    isLoading = false
                }
            } catch {
                let nsError = error as NSError
                let isAPIKeyError = nsError.domain == "APIKey"
                let isUnauthorized = nsError.code == 401
                await MainActor.run {
                    if isAPIKeyError {
                        // Missing API key — show inline hint, no alert
                        apiErrorMessage = language == .portuguese
                            ? "Chave de API não configurada. Vá em Configurações para adicionar."
                            : "API key not configured. Go to Settings to add one."
                        showingAPIError = true
                    } else if isUnauthorized {
                        // Invalid API key
                        apiErrorMessage = language == .portuguese
                            ? "Chave de API inválida. Verifique sua chave nas Configurações."
                            : "Invalid API key. Please check your key in Settings."
                        showingAPIError = true
                    } else {
                        // Real network/server error
                        apiErrorMessage = language == .portuguese
                            ? "Não foi possível contatar o servidor de IA. Verifique sua conexão."
                            : "Could not reach the AI server. Please check your connection."
                        showingAPIError = true
                    }
                    conversationHistory.append((
                        question: userQuestion,
                        answer: language == .portuguese ?
                            "Desculpe, não entendi. Pode reformular a pergunta?" :
                            "Sorry, I didn't understand. Can you rephrase the question?",
                        detectedQuestionId: nil
                    ))
                    isLoading = false
                }
            }
        }
    }

    private func calculateProgress() -> (asked: Int, total: Int) {
        let total = questionDatabase.getTotalQuestionCount()
        let asked = session.questionsAsked.count
        return (asked, total)
    }

    private func finishSession() {
        // Calculate results
        sessionResult = calculateSessionResults()
        showingResults = true
    }

    private func calculateSessionResults() -> BasicModeResult {
        let allQuestions = questionDatabase.allQuestions
        let requiredQuestions = questionDatabase.getRequiredQuestions()
        let totalQuestions = allQuestions.count
        let questionsAsked = session.questionsAsked.count

        // Completeness Score (50%)
        let completenessScore = (Double(questionsAsked) / Double(totalQuestions)) * 100.0

        // Required Questions Score (20%)
        let requiredAsked = requiredQuestions.filter { session.questionsAsked.contains($0.id) }.count
        let requiredScore = (Double(requiredAsked) / Double(requiredQuestions.count)) * 100.0

        // Sequence Score (30%)
        var sequenceScore = 100.0
        var outOfOrderCount = 0

        for i in session.questionOrder.indices.dropFirst() {
            let prevId = session.questionOrder[i-1]
            let currId = session.questionOrder[i]

            if let prevQ = allQuestions.first(where: { $0.id == prevId }),
               let currQ = allQuestions.first(where: { $0.id == currId }) {

                // Penalize if jumping backwards in sections
                if currQ.section.rawValue < prevQ.section.rawValue {
                    sequenceScore -= 5
                    outOfOrderCount += 1
                }
                // Small penalty for asking out of order within same section
                else if currQ.section == prevQ.section && currQ.orderInSection < prevQ.orderInSection {
                    sequenceScore -= 2
                    outOfOrderCount += 1
                }
            }
        }
        sequenceScore = max(0, sequenceScore)

        // Overall Score (weighted average)
        let overallScore = (completenessScore * 0.5) + (requiredScore * 0.2) + (sequenceScore * 0.3)

        // Missed important questions
        let missedImportant = requiredQuestions.filter { !session.questionsAsked.contains($0.id) }

        // Missed required questions only (avoid overwhelming students with optional ones)
        let allMissedQuestions = requiredQuestions.filter { !session.questionsAsked.contains($0.id) }

        // Section timings: map sectionFirstAsked to seconds using ordered section times
        let sessionEndTime = Date()
        var sectionTimings: [Int: Double] = [:]
        let sortedSectionEntries = sectionFirstAsked.sorted { $0.value < $1.value }
        for (i, entry) in sortedSectionEntries.enumerated() {
            let endTime: Date = i + 1 < sortedSectionEntries.count
                ? sortedSectionEntries[i + 1].value
                : sessionEndTime
            sectionTimings[entry.key.rawValue] = endTime.timeIntervalSince(entry.value)
        }

        // Generate feedback
        let feedback = generateFeedback(
            completeness: completenessScore,
            required: requiredScore,
            sequence: sequenceScore,
            overall: overallScore
        )

        // Generate strengths and improvements
        let (strengths, improvements) = generateStrengthsAndImprovements(
            completenessScore: completenessScore,
            requiredScore: requiredScore,
            sequenceScore: sequenceScore,
            missedImportant: missedImportant
        )

        return BasicModeResult(
            totalQuestions: totalQuestions,
            questionsAsked: questionsAsked,
            requiredQuestionsTotal: requiredQuestions.count,
            requiredQuestionsAsked: requiredAsked,
            questionOrder: session.questionOrder,
            completenessScore: completenessScore,
            sequenceScore: sequenceScore,
            requiredScore: requiredScore,
            overallScore: overallScore,
            missedImportantQuestions: missedImportant,
            questionsOutOfOrder: outOfOrderCount,
            feedback: feedback,
            strengths: strengths,
            improvements: improvements,
            sectionTimings: sectionTimings,
            allMissedQuestions: allMissedQuestions
        )
    }

    private func generateFeedback(completeness: Double, required: Double, sequence: Double, overall: Double) -> String {
        if language == .portuguese {
            if overall >= 90 {
                return "Excelente! Você conduziu uma anamnese muito completa e bem estruturada."
            } else if overall >= 75 {
                return "Muito bom! Sua anamnese foi bem conduzida, mas há espaço para melhorias."
            } else if overall >= 60 {
                return "Bom trabalho! Continue praticando para aperfeiçoar sua técnica de anamnese."
            } else {
                return "Continue praticando! Revise o roteiro de anamnese e tente ser mais completo."
            }
        } else {
            if overall >= 90 {
                return "Excellent! You conducted a very complete and well-structured anamnesis."
            } else if overall >= 75 {
                return "Very good! Your anamnesis was well conducted, but there's room for improvement."
            } else if overall >= 60 {
                return "Good work! Keep practicing to perfect your anamnesis technique."
            } else {
                return "Keep practicing! Review the anamnesis guide and try to be more thorough."
            }
        }
    }

    private func generateStrengthsAndImprovements(
        completenessScore: Double,
        requiredScore: Double,
        sequenceScore: Double,
        missedImportant: [AnamneseQuestion]
    ) -> (strengths: [String], improvements: [String]) {
        var strengths: [String] = []
        var improvements: [String] = []

        if language == .portuguese {
            // Strengths
            if completenessScore >= 80 {
                strengths.append("Boa cobertura das questões da anamnese")
            }
            if requiredScore >= 80 {
                strengths.append("Coletou as informações essenciais")
            }
            if sequenceScore >= 80 {
                strengths.append("Seguiu bem a sequência lógica da anamnese")
            }

            // Improvements
            if completenessScore < 70 {
                improvements.append("Fazer mais perguntas para uma anamnese completa")
            }
            if requiredScore < 70 {
                improvements.append("Não esquecer das perguntas obrigatórias")
            }
            if sequenceScore < 70 {
                improvements.append("Seguir a ordem das seções da anamnese")
            }
            if !missedImportant.isEmpty {
                improvements.append("Perguntas importantes não realizadas: \(missedImportant.count)")
            }
        } else {
            // Strengths
            if completenessScore >= 80 {
                strengths.append("Good coverage of anamnesis questions")
            }
            if requiredScore >= 80 {
                strengths.append("Collected essential information")
            }
            if sequenceScore >= 80 {
                strengths.append("Followed the logical sequence well")
            }

            // Improvements
            if completenessScore < 70 {
                improvements.append("Ask more questions for a complete anamnesis")
            }
            if requiredScore < 70 {
                improvements.append("Don't forget required questions")
            }
            if sequenceScore < 70 {
                improvements.append("Follow the order of anamnesis sections")
            }
            if !missedImportant.isEmpty {
                improvements.append("Important questions not asked: \(missedImportant.count)")
            }
        }

        return (strengths, improvements)
    }
}

// MARK: - Basic Mode Results View
struct BasicModeResultsView: View {
    let result: BasicModeResult
    let disease: Disease
    let language: AppLanguage
    let onDismiss: () -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var ratingManager = CaseDifficultyRatingManager.shared
    @State private var selectedRating: Int = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall Score
                    VStack(spacing: 8) {
                        Text(String(format: "%.0f%%", result.overallScore))
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(scoreColor)

                        Text(result.feedback)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    // Score Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text(language == .portuguese ? "Detalhamento" : "Breakdown")
                            .font(.headline)

                        scoreRow(
                            title: language == .portuguese ? "Completude" : "Completeness",
                            score: result.completenessScore,
                            detail: "\(result.questionsAsked)/\(result.totalQuestions) \(language == .portuguese ? "perguntas" : "questions")"
                        )

                        scoreRow(
                            title: language == .portuguese ? "Perguntas Obrigatórias" : "Required Questions",
                            score: result.requiredScore,
                            detail: ""
                        )

                        scoreRow(
                            title: language == .portuguese ? "Sequência" : "Sequence",
                            score: result.sequenceScore,
                            detail: result.questionsOutOfOrder > 0 ?
                                "\(result.questionsOutOfOrder) \(language == .portuguese ? "fora de ordem" : "out of order")" : ""
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Strengths
                    if !result.strengths.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(
                                language == .portuguese ? "Pontos Fortes" : "Strengths",
                                systemImage: "star.fill"
                            )
                            .font(.headline)
                            .foregroundColor(.green)

                            ForEach(result.strengths, id: \.self) { strength in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(strength)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Improvements
                    if !result.improvements.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(
                                language == .portuguese ? "Áreas para Melhorar" : "Areas to Improve",
                                systemImage: "lightbulb.fill"
                            )
                            .font(.headline)
                            .foregroundColor(.orange)

                            ForEach(result.improvements, id: \.self) { improvement in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(improvement)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Section Timing Breakdown
                    if !result.sectionTimings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(
                                language == .portuguese ? "Tempo por Seção" : "Time per Section",
                                systemImage: "clock.fill"
                            )
                            .font(.headline)
                            .foregroundColor(.indigo)

                            ForEach(AnamneseSection.allCases, id: \.self) { section in
                                if let seconds = result.sectionTimings[section.rawValue] {
                                    HStack {
                                        Text(section.displayName(language))
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(formatDuration(seconds))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.indigo)
                                    }
                                    Divider()
                                }
                            }

                            // Longest section callout
                            if let longestRaw = result.sectionTimings.max(by: { $0.value < $1.value }),
                               let longestSection = AnamneseSection(rawValue: longestRaw.key) {
                                Text(language == .portuguese
                                     ? "Você passou mais tempo em: \(longestSection.displayName(language))"
                                     : "You spent the most time on: \(longestSection.displayName(language))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding()
                        .background(Color.indigo.opacity(0.07))
                        .cornerRadius(12)
                    }

                    // Missed Required Questions (grouped by section)
                    if !result.allMissedQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(
                                language == .portuguese
                                    ? "Perguntas Obrigatórias Não Realizadas (\(result.allMissedQuestions.count))"
                                    : "Required Questions Not Asked (\(result.allMissedQuestions.count))",
                                systemImage: "exclamationmark.circle.fill"
                            )
                            .font(.headline)
                            .foregroundColor(.red)

                            ForEach(AnamneseSection.allCases, id: \.self) { section in
                                let sectionMissed = result.allMissedQuestions.filter { $0.section == section }
                                if !sectionMissed.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(section.displayName(language))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                            .padding(.top, 4)

                                        ForEach(sectionMissed) { question in
                                            HStack(alignment: .top, spacing: 8) {
                                                Image(systemName: "exclamationmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.caption)
                                                Text(question.getText(language))
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            }

                            Text(language == .portuguese
                                 ? "Apenas perguntas obrigatórias"
                                 : "Required questions only")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding()
                        .background(Color.red.opacity(0.07))
                        .cornerRadius(12)
                    } else {
                        // All questions asked
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text(language == .portuguese
                                 ? "Parabéns! Você fez todas as perguntas obrigatórias."
                                 : "Great job! You asked all required questions.")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // MARK: Difficulty Rating (task 10.4)
                    difficultyRatingSection

                    // Done Button
                    Button(action: {
                        if selectedRating > 0 {
                            ratingManager.submitRating(for: disease.nameEnglish, rating: selectedRating)
                        }
                        onDismiss()
                    }) {
                        Text(language == .portuguese ? "Concluir" : "Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle(language == .portuguese ? "Resultados" : "Results")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(themeManager.getColorScheme())
    }

    private func scoreRow(title: String, score: Double, detail: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.0f%%", score))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }

            ProgressView(value: score, total: 100)
                .tint(scoreColor(for: score))

            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var scoreColor: Color {
        scoreColor(for: result.overallScore)
    }

    private func scoreColor(for score: Double) -> Color {
        if score >= 90 { return .green }
        else if score >= 75 { return .blue }
        else if score >= 60 { return .orange }
        else { return .red }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes == 0 {
            return "\(secs)s"
        } else {
            return "\(minutes)m \(secs)s"
        }
    }

    private var difficultyRatingSection: some View {
        VStack(spacing: 10) {
            Text(language == .portuguese ? "Qual foi a dificuldade deste caso?" : "How difficult was this case?")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        selectedRating = star
                    }) {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(star <= selectedRating ? .yellow : Color.gray.opacity(0.4))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .accessibilityLabel(language == .portuguese
                        ? "\(star) estrela\(star == 1 ? "" : "s")"
                        : "\(star) star\(star == 1 ? "" : "s")")
                    .accessibilityValue(star == selectedRating
                        ? (language == .portuguese ? "Selecionado" : "Selected")
                        : "")
                }
            }

            if selectedRating > 0 {
                Text(basicRatingLabel(for: selectedRating))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(language == .portuguese ? "Toque nas estrelas para avaliar (opcional)" : "Tap stars to rate (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.06))
        .cornerRadius(12)
    }

    private func basicRatingLabel(for rating: Int) -> String {
        let labels: [(String, String)] = [
            ("Very Easy", "Muito Fácil"),
            ("Easy", "Fácil"),
            ("Moderate", "Moderado"),
            ("Hard", "Difícil"),
            ("Very Hard", "Muito Difícil")
        ]
        let (en, pt) = labels[rating - 1]
        return language == .portuguese ? pt : en
    }
}

// Extension for AnamneseSection display names
extension AnamneseSection {
    func displayName(_ language: AppLanguage) -> String {
        if language == .portuguese {
            switch self {
            case .identification: return "1. Identificação"
            case .chiefComplaint: return "2. Queixa"
            case .presentIllness: return "3. HDA"
            case .guidingSymptom: return "4. Sintoma Guia"
            case .personalHistory: return "5. Ant. Pessoais"
            case .familyHistory: return "6. Ant. Familiares"
            case .lifestyle: return "7. Hábitos"
            }
        } else {
            switch self {
            case .identification: return "1. ID"
            case .chiefComplaint: return "2. Complaint"
            case .presentIllness: return "3. HPI"
            case .guidingSymptom: return "4. Guide Symptom"
            case .personalHistory: return "5. Past History"
            case .familyHistory: return "6. Family Hx"
            case .lifestyle: return "7. Lifestyle"
            }
        }
    }
}
