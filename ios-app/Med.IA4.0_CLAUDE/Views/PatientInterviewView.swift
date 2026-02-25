import SwiftUI
import Foundation
import UIKit

// MARK: - Medical Test Synonym Map (task 13.1)
/// Maps common abbreviations and alternate names to canonical English lab-result terms.
/// Keys and values are all lowercase. Used by evaluateOrderedTests() for fuzzy matching.
private let medicalTestSynonyms: [String: [String]] = [
    "cbc":        ["complete blood count", "hemograma completo", "hemograma"],
    "ua":         ["urinalysis", "urinálise", "exame de urina", "urina"],
    "bmp":        ["basic metabolic panel", "painel metabólico básico"],
    "cmp":        ["comprehensive metabolic panel", "painel metabólico completo"],
    "lft":        ["liver function", "função hepática", "hepatic function"],
    "lfts":       ["liver function tests", "testes de função hepática", "provas de função hepática"],
    "ekg":        ["electrocardiogram", "eletrocardiograma", "electrocardiography"],
    "ecg":        ["electrocardiogram", "eletrocardiograma", "electrocardiography"],
    "mri":        ["magnetic resonance imaging", "ressonância magnética", "magnetic resonance"],
    "rmn":        ["magnetic resonance imaging", "ressonância magnética"],
    "ct":         ["computed tomography", "tomografia computadorizada", "ct scan"],
    "cat":        ["computed tomography", "tomografia computadorizada", "cat scan"],
    "cxr":        ["chest x-ray", "chest xray", "raio-x de tórax", "radiografia de tórax"],
    "xray":       ["x-ray", "radiografia", "raio-x"],
    "us":         ["ultrasound", "ultrassonografia", "ultrassom"],
    "usg":        ["ultrasound", "ultrassonografia", "ultrassom"],
    "echo":       ["echocardiogram", "ecocardiograma", "echocardiography"],
    "pft":        ["pulmonary function tests", "provas de função pulmonar", "espirometria"],
    "pfts":       ["pulmonary function tests", "provas de função pulmonar", "espirometria"],
    "bun":        ["blood urea nitrogen", "ureia", "urea"],
    "hba1c":      ["hemoglobin a1c", "hemoglobina glicada", "glycosylated hemoglobin", "glycated hemoglobin"],
    "a1c":        ["hemoglobin a1c", "hemoglobina glicada", "glycosylated hemoglobin"],
    "tsh":        ["thyroid stimulating hormone", "hormônio tireoestimulante", "tireotrofina"],
    "t3":         ["triiodothyronine", "triiodotironina"],
    "t4":         ["thyroxine", "tiroxina"],
    "bnp":        ["brain natriuretic peptide", "peptídeo natriurético cerebral", "natriuretic"],
    "proBNP":     ["brain natriuretic peptide", "peptídeo natriurético cerebral", "natriuretic"],
    "ck":         ["creatine kinase", "creatina quinase", "creatina fosfoquinase"],
    "cpk":        ["creatine kinase", "creatina quinase", "creatina fosfoquinase", "creatine phosphokinase"],
    "trop":       ["troponin", "troponina"],
    "psa":        ["prostate specific antigen", "antígeno prostático específico", "prostate antigen"],
    "ana":        ["antinuclear antibody", "anticorpo antinuclear", "antinuclear"],
    "esr":        ["erythrocyte sedimentation rate", "velocidade de hemossedimentação", "sedimentation"],
    "vhs":        ["erythrocyte sedimentation rate", "velocidade de hemossedimentação", "sedimentation"],
    "crp":        ["c-reactive protein", "proteína c-reativa", "reactive protein"],
    "pcr":        ["c-reactive protein", "proteína c-reativa", "reactive protein", "polymerase chain reaction"],
    "abg":        ["arterial blood gas", "gasometria arterial", "blood gas"],
    "lipase":     ["lipase", "lipase sérica", "serum lipase"],
    "amylase":    ["amylase", "amilase", "serum amylase"],
    "inr":        ["international normalized ratio", "tempo de protrombina", "prothrombin time"],
    "pt":         ["prothrombin time", "tempo de protrombina", "coagulation"],
    "ptt":        ["partial thromboplastin time", "tempo de tromboplastina parcial"],
    "aptt":       ["partial thromboplastin time", "tempo de tromboplastina parcial"],
    "d-dimer":    ["d-dimer", "d-dímero", "fibrin degradation"],
    "ddimer":     ["d-dimer", "d-dímero", "fibrin degradation"],
    "ferritin":   ["ferritin", "ferritina", "serum ferritin"],
    "tibc":       ["total iron binding capacity", "capacidade total de ligação ao ferro", "iron binding"],
    "ldh":        ["lactate dehydrogenase", "desidrogenase lática", "lactic dehydrogenase"],
    "alt":        ["alanine aminotransferase", "alanina aminotransferase", "alanine transaminase", "sgpt"],
    "ast":        ["aspartate aminotransferase", "aspartato aminotransferase", "aspartate transaminase", "sgot"],
    "alp":        ["alkaline phosphatase", "fosfatase alcalina"],
    "ggt":        ["gamma-glutamyl transferase", "gama-glutamiltransferase", "gamma glutamyl"],
    "wbc":        ["white blood cell", "leucócitos", "leukocyte count", "white cell count"],
    "rbc":        ["red blood cell", "eritrócitos", "erythrocyte count", "red cell count"],
    "hgb":        ["hemoglobin", "hemoglobina"],
    "hct":        ["hematocrit", "hematócrito"],
    "plt":        ["platelet count", "contagem de plaquetas", "plaquetas", "thrombocyte"],
    "eeg":        ["electroencephalogram", "eletroencefalograma"],
    "emg":        ["electromyography", "eletromiografia"],
    "lp":         ["lumbar puncture", "punção lombar", "spinal tap", "cerebrospinal fluid"],
    "csf":        ["cerebrospinal fluid", "líquido cefalorraquidiano", "lumbar puncture"],
    "echo echo":  ["echocardiogram", "ecocardiograma"],
    "bone scan":  ["bone scintigraphy", "cintilografia óssea", "nuclear bone scan"],
    "pet":        ["positron emission tomography", "tomografia por emissão de pósitrons", "pet scan"],
    "spect":      ["single photon emission computed tomography", "cintilografia"],
]

// MARK: - Updated Patient Simulation View (Complete with all features)
struct PatientSimulationView: View {
    let disease: Disease
    let difficulty: DifficultyLevel
    @EnvironmentObject var userProfile: UserProfileManager
    @EnvironmentObject var dataManager: MedicalDatabaseManager
    @StateObject private var aiService = ClaudeAIService() // UPDATED: No hardcoded API key

    @State private var currentQuestion = ""
    @State private var conversationHistory: [ConversationTurn] = []
    @State private var showingDiagnosisEntry = false
    @State private var showingTestEntry = false
    @State private var showingPersonalityDetails = false
    @State private var userDiagnosis = ""
    @State private var testRequest = ""
    @State private var showingResults = false
    @State private var showingStudyMaterials = false
    @State private var diagnosisResult: DiagnosisResult?
    @State private var hintsUsed = 0
    @State private var testsOrdered = 0
    @State private var orderedTestNames: [String] = []  // Track test names for feedback (task 3.1)
    @State private var sessionStartTime = Date()
    @State private var showingPersonalityAdjustment = false
    @State private var showingSummaryCard = false
    @State private var patientCase: PatientCase?
    @State private var showingTreatmentEntry = false
    @State private var showingTreatmentEvaluation = false
    @State private var userTreatment = ""
    @State private var treatmentResult: TreatmentResult?
    @State private var showingAPIError = false
    @State private var apiErrorMessage = ""

    var body: some View {
        VStack {
            // Patient Header
            if let patient = patientCase {
                // Redesigned patient info card (task 4.3)
                VStack(alignment: .leading, spacing: 0) {
                    // Identity row: avatar + name + mode badge
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 46, height: 46)
                            Text(patientInitials(patient))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(patient.demographics.name)
                                    .font(.headline)
                                Spacer()
                                Text("CLINICAL")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(5)
                            }
                            Text(getPatientAgeGenderText(patient: patient))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("ID: \(patient.demographics.patientID)")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    Divider().padding(.horizontal)

                    // Personality badge
                    Button(action: {
                        showingPersonalityDetails = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.shield.checkmark")
                                .foregroundColor(.purple)
                                .font(.caption)
                            Text(getPersonalityDisplayName(for: patient))
                                .font(.caption)
                                .foregroundColor(.purple)
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundColor(.purple.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Ver Personalidade do Paciente" : "View Patient Personality")
                    .accessibilityIdentifier("patientPersonalityButton")

                    // Chief complaints
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getChiefComplaintTitle())
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if getChiefComplaints(from: patient).isEmpty {
                            Text("Symptoms being evaluated...")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            ForEach(getChiefComplaints(from: patient), id: \.id) { symptom in
                                Text("• \(symptom.getText(userProfile.currentLanguage))")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(width: 3)
                        .foregroundColor(.blue)
                        .padding(.vertical, 6),
                    alignment: .leading
                )
                .shadow(color: Color(.systemGray4).opacity(0.5), radius: 3, x: 0, y: 2)

                // Patient Summary Card
                if let patient = patientCase {
                    PatientSummaryCard(
                        patient: patient,
                        isExpanded: $showingSummaryCard,
                        language: userProfile.currentLanguage
                    )
                }
            }

            // Conversation History
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conversationHistory) { turn in
                            ConversationBubbleView(turn: turn, language: userProfile.currentLanguage)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                ))
                                .id(turn.id)
                        }

                        if aiService.isGeneratingResponse {
                            TypingIndicatorView(language: userProfile.currentLanguage)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .id("typing-indicator")
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: aiService.isGeneratingResponse)
                    .padding()
                }
                .onChangeCompat(of: conversationHistory.count) { _ in
                    withAnimation {
                        if let lastTurn = conversationHistory.last {
                            proxy.scrollTo(lastTurn.id, anchor: .bottom)
                        }
                    }
                }
                .onChangeCompat(of: aiService.isGeneratingResponse) { isGenerating in
                    if isGenerating {
                        withAnimation {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
                        }
                    }
                }
            }

            // Quick Questions — visible only before first message
            if conversationHistory.isEmpty && !aiService.isGeneratingResponse {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(getQuickQuestions(), id: \.self) { question in
                            Button(question) {
                                currentQuestion = question
                                askQuestion()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity)
            }

            // Input Section
            VStack(spacing: 8) {
                HStack {
                    TextField(getTextFieldPlaceholder(), text: $currentQuestion)
                        .textFieldStyle(.roundedBorder)
                        .disabled(aiService.isGeneratingResponse)
                        .accessibilityIdentifier("questionTextField")

                    Button(action: askQuestion) {
                        if aiService.isGeneratingResponse {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .disabled(currentQuestion.isEmpty || aiService.isGeneratingResponse)
                    .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Enviar Pergunta" : "Send Question")
                    .accessibilityIdentifier("sendButton")
                }

                // Quick Response Templates
                if !conversationHistory.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(getQuickResponseTemplates(), id: \.self) { template in
                                Button(action: {
                                    currentQuestion = template
                                }) {
                                    Text(template)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.15))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                }
                                .disabled(aiService.isGeneratingResponse)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                HStack(spacing: 12) {
                    Button(action: { showingTestEntry = true }) {
                        HStack {
                            Image(systemName: "testtube.2")
                            Text(getOrderTestText())
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(10)
                    }
                    .disabled(aiService.isGeneratingResponse)
                    .accessibilityIdentifier("orderTestButton")
                    .buttonStyle(PressScaleButtonStyle())

                    Button(action: { showingDiagnosisEntry = true }) {
                        HStack {
                            Image(systemName: "stethoscope")
                            Text(getFinalDiagnosisText())
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                    .disabled(conversationHistory.isEmpty || aiService.isGeneratingResponse)
                    .accessibilityIdentifier("diagnosisButton")
                    .buttonStyle(PressScaleButtonStyle())

                    Button(action: { showingStudyMaterials = true }) {
                        HStack {
                            Image(systemName: "book.fill")
                            Text(getStudyMaterialsText())
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    .accessibilityIdentifier("studyMaterialsButton")
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding()
        }
        .onDisappear {
            let sessionTime = Date().timeIntervalSince(sessionStartTime)
            userProfile.addStudyTime(sessionTime)

            if userProfile.profile.currentSessionData != nil {
                userProfile.abandonSession()
            }
        }
        .sheet(isPresented: $showingDiagnosisEntry) {
            DiagnosisEntryView(
                userDiagnosis: $userDiagnosis,
                language: userProfile.currentLanguage,
                onSubmit: { diagnosis in
                    userDiagnosis = diagnosis
                    showingDiagnosisEntry = false
                    checkDiagnosis(diagnosis)
                }
            )
        }
        .sheet(isPresented: $showingTestEntry) {
            TestEntryView(
                testRequest: $testRequest,
                language: userProfile.currentLanguage,
                onSubmit: { test in
                    testRequest = test
                    showingTestEntry = false
                    orderTest(test)
                }
            )
        }
        .sheet(isPresented: $showingResults) {
            if let result = diagnosisResult {
                DiagnosisResultView(
                    result: result,
                    language: userProfile.currentLanguage,
                    diseaseNameEnglish: disease.nameEnglish,
                    onDismiss: {
                        showingResults = false
                        if result.isCorrect && !disease.treatments.isEmpty {
                            showingTreatmentEntry = true
                        } else {
                            showingStudyMaterials = true
                        }
                    },
                    onTestTreatment: !disease.treatments.isEmpty ? {
                        // Test button: Allow treatment prescription even with wrong diagnosis
                        showingResults = false
                        showingTreatmentEntry = true
                    } : nil
                )
            }
        }
        .sheet(isPresented: $showingTreatmentEntry) {
            TreatmentPrescriptionEntryView(
                userTreatment: $userTreatment,
                language: userProfile.currentLanguage,
                onSubmit: {
                    evaluateTreatment()
                    showingTreatmentEntry = false
                    showingTreatmentEvaluation = true
                },
                onCancel: {
                    showingTreatmentEntry = false
                    showingStudyMaterials = true
                }
            )
        }
        .sheet(isPresented: $showingTreatmentEvaluation) {
            if let result = treatmentResult {
                TreatmentEvaluationView(
                    result: result,
                    language: userProfile.currentLanguage,
                    onDismiss: {
                        showingTreatmentEvaluation = false
                        showingStudyMaterials = true
                    }
                )
            }
        }
        .sheet(isPresented: $showingStudyMaterials) {
            StudyMaterialsView(
                disease: disease,
                language: userProfile.currentLanguage
            )
        }
        .sheet(isPresented: $showingPersonalityDetails) {
            if let patient = patientCase {
                PersonalityDetailsView(
                    personality: patient.personality,
                    language: userProfile.currentLanguage
                )
            }
        }
        .sheet(isPresented: $showingPersonalityAdjustment) {
            if let patientCase = patientCase {
                PersonalityAdjustmentView(
                    patientCase: Binding(
                        get: { patientCase },
                        set: { self.patientCase = $0 }
                    ),
                    language: userProfile.currentLanguage
                )
            }
        }
        .onAppear {
            if patientCase == nil {
                patientCase = dataManager.getPatientCase(for: disease)
                // Apply difficulty adjustments to patient personality
                if var case_ = patientCase {
                    case_.personality = adjustPersonalityForDifficulty(case_.personality, difficulty: difficulty)
                    patientCase = case_
                }
            }
            if let patientCase = patientCase {
                userProfile.startNewSession(patientCase: patientCase, difficulty: difficulty)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        exportConversation()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                    }
                    .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Exportar Conversa" : "Export Conversation")
                    .disabled(conversationHistory.isEmpty)

                    Button(action: {
                        showingPersonalityAdjustment = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                    }
                    .accessibilityLabel(userProfile.currentLanguage == .portuguese ? "Ajustar Personalidade" : "Adjust Personality")

                    FeedbackButton(language: userProfile.currentLanguage)
                }
            }
        }
        .onChangeCompat(of: aiService.lastError) { error in
            guard let error = error else { return }
            // Skip "no API key" errors — handled by the key setup flow
            guard !error.contains("No API key") else { return }
            apiErrorMessage = error
            showingAPIError = true
            aiService.lastError = nil
        }
        .alert(
            userProfile.currentLanguage == .portuguese ? "Erro de Conexão" : "Connection Error",
            isPresented: $showingAPIError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(userProfile.currentLanguage == .portuguese
                 ? "Não foi possível contatar o servidor de IA. Usando resposta padrão."
                 : "Could not reach the AI server. Using a default response.")
        }
    }

    private func getQuickQuestions() -> [String] {
        return self.userProfile.currentLanguage == .portuguese ? [
            "Como você se sente?",
            "Onde dói?",
            "Quando começou?",
            "Pode descrever seus sintomas?"
        ] : [
            "How are you feeling?",
            "Where does it hurt?",
            "When did this start?",
            "Can you describe your symptoms?"
        ]
    }

    private func getQuickResponseTemplates() -> [String] {
        return userProfile.currentLanguage == .portuguese ? [
            "Pode descrever a dor?",
            "Em uma escala de 1-10?",
            "Quando começou?",
            "Algo melhora os sintomas?",
            "Historico familiar?",
            "Medicamentos atuais?",
            "Alergias conhecidas?",
            "Sintomas associados?"
        ] : [
            "Can you describe the pain?",
            "On a scale of 1-10?",
            "When did this start?",
            "Anything that helps?",
            "Family history?",
            "Current medications?",
            "Known allergies?",
            "Associated symptoms?"
        ]
    }

    private func exportConversation() {
        guard let patient = patientCase else { return }

        let exportText = generateConversationExport(patient: patient)
        let activityVC = UIActivityViewController(
            activityItems: [exportText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {

            // For iPad - set popover presentation
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            rootVC.present(activityVC, animated: true)
        }
    }

    private func generateConversationExport(patient: PatientCase) -> String {
        let title = userProfile.currentLanguage == .portuguese ?
            "RELATÓRIO DE CONSULTA MÉDICA" : "MEDICAL CONSULTATION REPORT"

        let patientInfo = userProfile.currentLanguage == .portuguese ?
            "INFORMAÇÕES DO PACIENTE" : "PATIENT INFORMATION"

        let conversationLabel = userProfile.currentLanguage == .portuguese ?
            "CONVERSA CLÍNICA" : "CLINICAL CONVERSATION"

        var export = """
        \(title)
        \(String(repeating: "=", count: title.count))

        \(patientInfo):
        • \(userProfile.currentLanguage == .portuguese ? "Nome" : "Name"): \(patient.demographics.name)
        • \(userProfile.currentLanguage == .portuguese ? "ID" : "ID"): \(patient.demographics.patientID)
        • \(userProfile.currentLanguage == .portuguese ? "Idade" : "Age"): \(patient.demographics.age)
        • \(userProfile.currentLanguage == .portuguese ? "Sexo" : "Gender"): \(patient.demographics.gender)
        • \(userProfile.currentLanguage == .portuguese ? "Data da Consulta" : "Consultation Date"): \(Date().formatted(.dateTime.day().month().year()))

        \(conversationLabel):
        \(String(repeating: "-", count: conversationLabel.count))

        """

        for (index, turn) in conversationHistory.enumerated() {
            let questionLabel = userProfile.currentLanguage == .portuguese ? "Médico" : "Doctor"
            let responseLabel = userProfile.currentLanguage == .portuguese ? "Paciente" : "Patient"

            export += """

            [\(index + 1)] \(questionLabel): \(turn.question)

            \(responseLabel): \(turn.response)

            """
        }

        export += """

        \(String(repeating: "=", count: 40))
        \(userProfile.currentLanguage == .portuguese ? "Exportado via Med.IA" : "Exported via Med.IA") - \(Date().formatted(.dateTime))
        """

        return export
    }

    private func askQuestion() {
        guard !self.currentQuestion.isEmpty && !self.aiService.isGeneratingResponse,
              let patient = self.patientCase else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let question = self.currentQuestion
        self.currentQuestion = ""

        Task {
            let response = await self.aiService.generatePatientResponse(
                question: question,
                patientCase: patient,
                conversationHistory: self.conversationHistory,
                language: self.userProfile.currentLanguage,
                difficulty: self.difficulty
            )

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.conversationHistory.append(ConversationTurn(
                        question: question,
                        response: response,
                        timestamp: Date(),
                        isTest: false
                    ))
                }

                // Update session progress
                let questionsAsked = self.conversationHistory.filter { !$0.isTest }.count
                let sessionTime = Date().timeIntervalSince(self.sessionStartTime)
                self.userProfile.updateSessionProgress(
                    questionsAsked: questionsAsked,
                    hintsUsed: self.hintsUsed,
                    testsOrdered: self.testsOrdered,
                    responseTime: sessionTime
                )
            }
        }
    }

    private func orderTest(_ test: String) {
        guard let patient = self.patientCase else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self.testsOrdered += 1
        self.orderedTestNames.append(test)  // Track name for test feedback (task 3.1)

        Task {
            let response = await self.aiService.generateTestResult(
                testRequest: test,
                patientCase: patient,
                language: self.userProfile.currentLanguage
            )

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.conversationHistory.append(ConversationTurn(
                        question: self.userProfile.currentLanguage == .portuguese ? "Teste solicitado: \(test)" : "Test ordered: \(test)",
                        response: response,
                        timestamp: Date(),
                        isTest: true
                    ))
                }
            }
        }
    }

    private func getHint() {
        guard let patient = self.patientCase else { return }

        self.hintsUsed += 1

        Task {
            let hint = await self.aiService.generateHint(
                patientCase: patient,
                conversationHistory: self.conversationHistory,
                language: self.userProfile.currentLanguage
            )

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    let hintQuestion = self.userProfile.currentLanguage == .portuguese ? "Solicitou uma dica" : "Requested a hint"
                    self.conversationHistory.append(ConversationTurn(
                        question: hintQuestion,
                        response: "💡 \(hint)",
                        timestamp: Date(),
                        isTest: false
                    ))
                }
            }
        }
    }

    private func checkDiagnosis(_ diagnosis: String) {
        guard let patient = self.patientCase else { return }

        let isCorrect = isDiagnosisCorrect(diagnosis)

        // Simplify complex ternary expression to avoid type-checking timeout
        let feedbackMessage: String
        if isCorrect {
            feedbackMessage = self.userProfile.currentLanguage == .portuguese ?
                "Diagnóstico correto! Bem feito." :
                "Correct diagnosis! Well done."
        } else {
            let correctCondition = patient.disease.getDisplayName(self.userProfile.currentLanguage)
            feedbackMessage = self.userProfile.currentLanguage == .portuguese ?
                "Diagnóstico incorreto. A condição correta é: \(correctCondition)" :
                "Incorrect diagnosis. The correct condition is: \(correctCondition)"
        }

        // Evaluate test ordering quality (task 3.1)
        let testEval = evaluateOrderedTests()

        // Compute differential diagnosis (task 3.3)
        let differentials = dataManager.findDifferentialDiagnoses(
            for: self.disease,
            language: userProfile.currentLanguage
        )
        let studyNotes = Array(self.disease.hints.prefix(5).map { $0.getText(userProfile.currentLanguage) })

        self.diagnosisResult = DiagnosisResult(
            userDiagnosis: diagnosis,
            isCorrect: isCorrect,
            conversationTurns: self.conversationHistory.filter { !$0.isTest }.count,
            patientName: patient.demographics.name,
            hintsUsed: self.hintsUsed,
            testsOrdered: self.testsOrdered,
            feedback: feedbackMessage,
            orderedTestNames: self.orderedTestNames,
            relevantTests: testEval.relevant,
            unnecessaryTests: testEval.unnecessary,
            missedKeyTests: testEval.missed,
            differentialDiagnoses: differentials,
            studyNotes: studyNotes
        )

        self.userProfile.recordDiagnosis(
            disease: self.disease,
            isCorrect: isCorrect,
            questionCount: self.conversationHistory.filter { !$0.isTest }.count,
            hintsUsed: self.hintsUsed,
            testsOrdered: self.testsOrdered
        )

        // Enhanced session tracking: Complete session with detailed analytics
        let confidenceScore = isCorrect ? 0.9 : 0.3 // Simple confidence scoring

        self.userProfile.completeSession(
            finalDiagnosis: diagnosis,
            isCorrect: isCorrect,
            confidenceScore: confidenceScore
        )

        UINotificationFeedbackGenerator().notificationOccurred(isCorrect ? .success : .error)
        self.showingResults = true
    }

    private func isDiagnosisCorrect(_ diagnosis: String) -> Bool {
        let diagnosisLower = diagnosis.lowercased()
        let conditionNameLower = self.disease.nameEnglish.lowercased()
        let conditionPortugueseLower = self.disease.namePortuguese.lowercased()

        return diagnosisLower.contains(conditionNameLower) ||
               conditionNameLower.contains(diagnosisLower) ||
               diagnosisLower.contains(conditionPortugueseLower) ||
               conditionPortugueseLower.contains(diagnosisLower)
    }

    // MARK: - Test Evaluation (task 3.1, enhanced task 13.1)
    /// Classifies each ordered test as relevant or unnecessary, and lists missed key tests.
    /// Uses medicalTestSynonyms to handle common abbreviations (CBC, UA, EKG, MRI, etc.)
    private func evaluateOrderedTests() -> (relevant: [String], unnecessary: [String], missed: [String]) {
        let labResults = disease.labResults
        let stopWords: Set<String> = ["a", "an", "the", "of", "for", "and", "or", "test", "level", "count"]

        func significantWords(_ text: String) -> Set<String> {
            Set(text.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 2 && !stopWords.contains($0) })
        }

        /// Expand a test name through the synonym map, returning a set of all canonical
        /// terms it could refer to (plus the original words).
        func expandedWords(_ text: String) -> Set<String> {
            var words = significantWords(text)
            let textLower = text.lowercased().trimmingCharacters(in: .whitespaces)
            // Check the whole string as a key first (e.g. "d-dimer")
            if let synonyms = medicalTestSynonyms[textLower] {
                synonyms.forEach { words.formUnion(significantWords($0)) }
            }
            // Also check each individual word token (e.g. "ekg" in "order ekg now")
            for word in text.lowercased().split(separator: " ").map(String.init) {
                if let synonyms = medicalTestSynonyms[word] {
                    synonyms.forEach { words.formUnion(significantWords($0)) }
                }
            }
            return words
        }

        var relevantTests: [String] = []
        var unnecessaryTests: [String] = []
        var matchedLabResultIds = Set<Int>()

        for testName in orderedTestNames {
            let testWords = expandedWords(testName)
            var matched = false

            for lab in labResults {
                let labWords = significantWords(lab.resultEnglish)
                    .union(significantWords(lab.resultPortuguese))
                let overlap = testWords.intersection(labWords)
                let testLower = testName.lowercased()
                let labLower = lab.resultEnglish.lowercased()

                // Also expand the lab name for reverse-lookup (e.g. lab = "Complete Blood Count", test = "cbc")
                let labExpandedWords = expandedWords(lab.resultEnglish)
                    .union(expandedWords(lab.resultPortuguese))
                let expandedOverlap = testWords.intersection(labExpandedWords)

                if !overlap.isEmpty ||
                   !expandedOverlap.isEmpty ||
                   testLower.contains(labLower) ||
                   labLower.contains(testLower) {
                    matched = true
                    matchedLabResultIds.insert(lab.id)
                }
            }

            if matched {
                relevantTests.append(testName)
            } else {
                unnecessaryTests.append(testName)
            }
        }

        // Missed tests: lab results not matched by any ordered test.
        // When no tests were ordered at all, show ALL missed tests for maximum educational value.
        // When tests were ordered, cap at 3 to avoid overwhelming the student.
        let unmatched = labResults.filter { !matchedLabResultIds.contains($0.id) }
        let missedTests: [String]
        if orderedTestNames.isEmpty {
            missedTests = unmatched.map { $0.getText(userProfile.currentLanguage) }
        } else {
            missedTests = unmatched.prefix(3).map { $0.getText(userProfile.currentLanguage) }
        }

        return (relevantTests, unnecessaryTests, missedTests)
    }

    private func evaluateTreatment() {
        let treatments = disease.treatments
        let userInput = userTreatment.lowercased()

        var matchedTreatments: [Treatment] = []
        var score: Double = 0.0

        // Check each treatment for matches
        for treatment in treatments {
            let treatmentTextEn = treatment.treatmentEnglish.lowercased()
            let treatmentTextPt = treatment.treatmentPortuguese.lowercased()

            // Check for substring matches or word overlap
            let wordsUser = Set(userInput.split(separator: " ").map { String($0) })
            let wordsEn = Set(treatmentTextEn.split(separator: " ").map { String($0) })
            let wordsPt = Set(treatmentTextPt.split(separator: " ").map { String($0) })

            let matchesEn = userInput.contains(treatmentTextEn) || treatmentTextEn.contains(userInput) || !wordsUser.intersection(wordsEn).isEmpty
            let matchesPt = userInput.contains(treatmentTextPt) || treatmentTextPt.contains(userInput) || !wordsUser.intersection(wordsPt).isEmpty

            if matchesEn || matchesPt {
                matchedTreatments.append(treatment)
                // Primary treatments weighted higher
                score += treatment.isPrimaryTreatment ? 0.5 : 0.2
            }
        }

        // Cap score at 1.0
        score = min(score, 1.0)

        // Find missed primary treatments
        let primaryTreatments = treatments.filter { $0.isPrimaryTreatment }
        let missedTreatments = primaryTreatments.filter { primaryTreatment in
            !matchedTreatments.contains(where: { $0.id == primaryTreatment.id })
        }

        // Acceptable if score >= 0.6 OR matched at least one primary treatment
        let matchedPrimary = matchedTreatments.contains(where: { $0.isPrimaryTreatment })
        let isAcceptable = score >= 0.6 || matchedPrimary

        // Generate feedback
        let feedbackMessage: String
        if isAcceptable {
            feedbackMessage = userProfile.currentLanguage == .portuguese ?
                "Tratamento apropriado! Você identificou os principais tratamentos." :
                "Appropriate treatment! You identified the key treatments."
        } else {
            feedbackMessage = userProfile.currentLanguage == .portuguese ?
                "Tratamento precisa de melhoria. Revise os tratamentos primários recomendados." :
                "Treatment needs improvement. Review the recommended primary treatments."
        }

        // Create treatment result
        self.treatmentResult = TreatmentResult(
            userTreatment: userTreatment,
            correctTreatments: treatments,
            matchedTreatments: matchedTreatments,
            missedTreatments: missedTreatments,
            score: score,
            feedback: feedbackMessage,
            isAcceptable: isAcceptable
        )

        // Update session data with treatment information
        if userProfile.profile.currentSessionData != nil {
            userProfile.profile.currentSessionData?.treatmentPrescribed = userTreatment
            userProfile.profile.currentSessionData?.treatmentScore = score
            userProfile.profile.currentSessionData?.treatmentIsAcceptable = isAcceptable
        }
    }

    private func getPatientAgeGenderText(patient: PatientCase) -> String {
        let ageText = self.userProfile.currentLanguage == .portuguese ? "anos" : "years old"
        let genderText = translateGender(patient.demographics.gender, to: self.userProfile.currentLanguage)
        return "\(patient.demographics.age) \(ageText), \(genderText)"
    }

    private func patientInitials(_ patient: PatientCase) -> String {
        let parts = patient.demographics.name.split(separator: " ")
        let initials = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "?" : initials
    }

    private func getChiefComplaints(from patient: PatientCase) -> [Symptom] {
        return patient.presentingSymptoms.filter { $0.isChiefComplaint }
    }

    private func getPersonalityDisplayName(for patient: PatientCase) -> String {
        return patient.personality.type.displayName(language: self.userProfile.currentLanguage)
    }

    private func getChiefComplaintTitle() -> String {
        return self.userProfile.currentLanguage == .portuguese ? "Queixa Principal:" : "Chief Complaint:"
    }

    private func adjustPersonalityForDifficulty(_ personality: PatientPersonality, difficulty: DifficultyLevel) -> PatientPersonality {
        var adjusted = personality

        switch difficulty {
        case .beginner:
            // Very cooperative, clear communicator
            adjusted.cooperationLevel = max(0.8, personality.cooperationLevel)
            adjusted.memoryClarity = max(0.9, personality.memoryClarity)
            adjusted.anxietyLevel = min(0.3, personality.anxietyLevel)

        case .intermediate:
            // Standard patient - use default personality
            break

        case .advanced:
            // More challenging - less cooperative
            adjusted.cooperationLevel = min(0.5, personality.cooperationLevel)
            adjusted.memoryClarity = min(0.6, personality.memoryClarity)
            adjusted.anxietyLevel = max(0.6, personality.anxietyLevel)

        case .expert:
            // Very challenging - vague, uncooperative
            adjusted.cooperationLevel = min(0.3, personality.cooperationLevel)
            adjusted.memoryClarity = min(0.4, personality.memoryClarity)
            adjusted.anxietyLevel = max(0.8, personality.anxietyLevel)
            adjusted.painTolerance = max(0.7, personality.painTolerance) // Downplays pain
        }

        return adjusted
    }

    private func getProcessingText() -> String {
        return self.userProfile.currentLanguage == .portuguese ? "Processando..." : "Processing..."
    }

    private func getTextFieldPlaceholder() -> String {
        return self.userProfile.currentLanguage == .portuguese ?
            "Faça uma pergunta ao paciente..." :
            "Ask the patient a question..."
    }

    private func getOrderTestText() -> String {
        return self.userProfile.currentLanguage == .portuguese ? "Solicitar Exame" : "Order Test"
    }

    private func getFinalDiagnosisText() -> String {
        return self.userProfile.currentLanguage == .portuguese ? "Diagnóstico Final" : "Final Diagnosis"
    }

    private func getStudyMaterialsText() -> String {
        return self.userProfile.currentLanguage == .portuguese ? "Material de Estudo" : "Study Materials"
    }
}

// MARK: - Press Scale Button Style (task 4.3)
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Supporting Views

struct ConversationBubbleView: View {
    let turn: ConversationTurn
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(getQuestionTypeLabel())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(turn.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(turn.question)
                .font(.body)
                .padding(.bottom, 4)

            Text(turn.response)
                .font(.body)
                .foregroundColor(.blue)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }

    private func getQuestionTypeLabel() -> String {
        if turn.isTest {
            return language == .portuguese ? "Teste" : "Test"
        } else {
            return language == .portuguese ? "Pergunta" : "Question"
        }
    }
}

struct TestEntryView: View {
    @Binding var testRequest: String
    let language: AppLanguage
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var localTest = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(language == .portuguese ? "Que teste você gostaria de solicitar?" : "What test would you like to order?")
                .font(.title2)
                .bold()
                .padding(.top)

            TextField(
                language == .portuguese ? "Digite o teste..." : "Enter test...",
                text: $localTest
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)

            HStack(spacing: 20) {
                Button(language == .portuguese ? "Cancelar" : "Cancel") {
                    dismiss()
                }
                .foregroundColor(.red)

                Button(language == .portuguese ? "Solicitar" : "Order") {
                    testRequest = localTest
                    onSubmit(localTest)
                    dismiss()
                }
                .foregroundColor(.blue)
                .disabled(localTest.isEmpty)
            }
            .padding(.bottom)
        }
        .presentationDetents([.medium])
    }
}

struct VoiceInputButton: View {
    @Binding var text: String
    let language: AppLanguage

    var body: some View {
        Button(action: {
            // Voice input implementation would go here
        }) {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.red)
                .clipShape(Circle())
        }
    }
}

// MARK: - Typing Indicator View
/// Animated three-dot typing indicator shown while the AI patient is generating a response.
struct TypingIndicatorView: View {
    let language: AppLanguage
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffsets[index])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .cornerRadius(16)

            Text(language == .portuguese ? "digitando..." : "typing...")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.45)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15)
            ) {
                dotOffsets[i] = -6
            }
        }
    }
}
