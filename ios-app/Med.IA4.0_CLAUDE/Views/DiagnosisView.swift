import SwiftUI
import UIKit

struct DiagnosisEntryView: View {
    @Binding var userDiagnosis: String
    let language: AppLanguage
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var localDiagnosis = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(language == .portuguese ? "Qual é o seu diagnóstico?" : "What is your diagnosis?")
                .font(.title2)
                .bold()
                .padding(.top)

            TextField(
                language == .portuguese ? "Digite o diagnóstico..." : "Enter diagnosis...",
                text: $localDiagnosis
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)
            .accessibilityIdentifier("diagnosisTextField")

            HStack(spacing: 20) {
                Button(language == .portuguese ? "Cancelar" : "Cancel") {
                    dismiss()
                }
                .foregroundColor(.red)
                .accessibilityIdentifier("cancelDiagnosisButton")

                Button(language == .portuguese ? "Submeter" : "Submit") {
                    userDiagnosis = localDiagnosis
                    onSubmit(localDiagnosis)
                    dismiss()
                }
                .foregroundColor(.blue)
                .disabled(localDiagnosis.isEmpty)
                .accessibilityIdentifier("submitDiagnosisButton")
            }
            .padding(.bottom)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Diagnosis Result View
struct DiagnosisResultView: View {
    let result: DiagnosisResult
    let language: AppLanguage
    /// English name of the disease — used to save the student's difficulty rating.
    let diseaseNameEnglish: String
    let onDismiss: () -> Void
    let onTestTreatment: (() -> Void)?

    @StateObject private var ratingManager = CaseDifficultyRatingManager.shared
    @State private var selectedRating: Int = 0
    @State private var verdictScale: CGFloat = 0.3
    @State private var verdictOpacity: Double = 0
    @State private var showDifferential: Bool = false
    @State private var showStudyNotes: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: Diagnosis verdict (animated icon + polished card)
                VStack(spacing: 10) {
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(result.isCorrect ? .green : .red)
                        .scaleEffect(verdictScale)
                        .opacity(verdictOpacity)

                    Text(result.isCorrect ?
                         (language == .portuguese ? "Correto!" : "Correct!") :
                         (language == .portuguese ? "Incorreto" : "Incorrect"))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(result.isCorrect ? .green : .red)
                        .opacity(verdictOpacity)
                }
                .padding(.top, 8)

                Text(result.feedback)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background((result.isCorrect ? Color.green : Color.red).opacity(0.07))
                    .cornerRadius(12)
                    .padding(.horizontal, 4)

                // MARK: Test Ordering Feedback (task 3.1 + 9.1)
                if result.testsOrdered > 0 {
                    testOrderingFeedbackSection
                } else if !result.missedKeyTests.isEmpty {
                    noTestsOrderedSection
                }

                // MARK: Differential Diagnosis (task 3.3) — collapsed by default
                if !result.differentialDiagnoses.isEmpty {
                    collapsibleHeader(
                        icon: "list.bullet.clipboard",
                        color: .purple,
                        title: language == .portuguese ? "Diagnóstico Diferencial" : "Differential Diagnosis",
                        isExpanded: $showDifferential
                    )
                    if showDifferential {
                        differentialDiagnosisSection
                    }
                }

                // MARK: Study Notes (task 3.3) — collapsed by default
                if !result.studyNotes.isEmpty {
                    collapsibleHeader(
                        icon: "book.closed.fill",
                        color: .teal,
                        title: language == .portuguese ? "Notas de Estudo" : "Study Notes",
                        isExpanded: $showStudyNotes
                    )
                    if showStudyNotes {
                        studyNotesSection
                    }
                }

                // MARK: Difficulty Rating (task 3.4)
                difficultyRatingSection

                // Test Treatment button (shown only when incorrect, for testing purposes)
                if !result.isCorrect, let testTreatmentAction = onTestTreatment {
                    VStack(spacing: 8) {
                        Text(language == .portuguese ? "Modo de Teste" : "Testing Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()

                        Button(action: testTreatmentAction) {
                            HStack {
                                Image(systemName: "testtube.2")
                                Text(language == .portuguese ? "Testar Prescrição Mesmo Assim" : "Test Prescription Anyway")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }

                Button(language == .portuguese ? "Continuar" : "Continue") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if selectedRating > 0 {
                        ratingManager.submitRating(for: diseaseNameEnglish, rating: selectedRating)
                    }
                    onDismiss()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .accessibilityIdentifier("continueButton")
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.1)) {
                verdictScale = 1.0
                verdictOpacity = 1.0
            }
            UINotificationFeedbackGenerator().notificationOccurred(result.isCorrect ? .success : .error)
        }
    }

    // MARK: - Difficulty Rating Section (task 3.4)
    @ViewBuilder
    private var difficultyRatingSection: some View {
        VStack(spacing: 10) {
            Text(language == .portuguese ? "Qual foi a dificuldade deste caso?" : "How difficult was this case?")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        selectedRating = star
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    .accessibilityIdentifier("ratingButton\(star)")
                }
            }

            if selectedRating > 0 {
                Text(ratingLabel(for: selectedRating))
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
        .padding(.horizontal)
    }

    private func ratingLabel(for rating: Int) -> String {
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

    // MARK: - Test Ordering Feedback Section
    @ViewBuilder
    private var testOrderingFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundColor(.blue)
                Text(language == .portuguese ? "Avaliação dos Exames Solicitados" : "Test Ordering Feedback")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Efficiency summary row
            efficiencySummaryRow

            // Relevant tests
            if !result.relevantTests.isEmpty {
                testGroupView(
                    title: language == .portuguese ? "Exames Relevantes" : "Relevant Tests",
                    tests: result.relevantTests,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }

            // Unnecessary tests
            if !result.unnecessaryTests.isEmpty {
                testGroupView(
                    title: language == .portuguese ? "Exames Desnecessários" : "Unnecessary Tests",
                    tests: result.unnecessaryTests,
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
            }

            // Missed key tests (always educational, shown regardless of diagnosis outcome)
            if !result.missedKeyTests.isEmpty {
                testGroupView(
                    title: language == .portuguese ? "Exames Importantes Não Solicitados" : "Key Tests You Missed",
                    tests: result.missedKeyTests,
                    icon: "questionmark.circle.fill",
                    color: .blue
                )
            }

            // Cost awareness row
            costAwarenessRow
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - No Tests Ordered Section (task 9.1)
    @ViewBuilder
    private var noTestsOrderedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundColor(.orange)
                Text(language == .portuguese ? "Nenhum Exame Solicitado" : "No Tests Were Ordered")
                    .font(.headline)
                Spacer()
            }

            Divider()

            Text(language == .portuguese
                 ? "Você não solicitou nenhum exame. Considere solicitar estes exames importantes para este diagnóstico:"
                 : "You ordered no tests. Consider ordering these key tests for this diagnosis:")
                .font(.caption)
                .foregroundColor(.secondary)

            testGroupView(
                title: language == .portuguese ? "Exames Importantes a Considerar" : "Key Tests to Consider",
                tests: result.missedKeyTests,
                icon: "questionmark.circle.fill",
                color: .orange
            )
        }
        .padding()
        .background(Color.orange.opacity(0.06))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var efficiencySummaryRow: some View {
        let total = result.orderedTestNames.count
        let relevant = result.relevantTests.count
        let pct = total > 0 ? Int(Double(relevant) / Double(total) * 100) : 0
        let pctColor: Color = pct >= 60 ? .green : (pct >= 30 ? .orange : .red)
        let badge = pct >= 80 ? "⭐⭐⭐" : (pct >= 50 ? "⭐⭐" : "⭐")
        let relevantLabel = language == .portuguese ? "relevantes" : "relevant"

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(language == .portuguese ? "Eficiência" : "Efficiency")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(relevant)/\(total) \(relevantLabel) (\(pct)%)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(pctColor)
            }
            Spacer()
            Text(badge)
                .font(.title3)
        }
    }

    private var costAwarenessRow: some View {
        let (costLabel, costColor) = costLabelAndColor()
        let costTitle = language == .portuguese ? "Custo estimado: " : "Estimated cost: "
        return HStack {
            Image(systemName: "dollarsign.circle")
                .foregroundColor(costColor)
            Text(costTitle + costLabel)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func costLabelAndColor() -> (String, Color) {
        let costLevel = totalCostLevel(for: result.orderedTestNames)
        if costLevel == 0 {
            return (language == .portuguese ? "Nenhum exame solicitado" : "No tests ordered", .secondary)
        } else if costLevel == 1 {
            return (language == .portuguese ? "Custo baixo (exames básicos)" : "Low cost (basic tests)", .green)
        } else if costLevel == 2 {
            return (language == .portuguese ? "Custo moderado" : "Moderate cost", .orange)
        } else {
            return (language == .portuguese ? "Custo elevado (exames caros incluídos)" : "High cost (expensive tests included)", .red)
        }
    }

    @ViewBuilder
    private func testGroupView(title: String, tests: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)

            ForEach(tests, id: \.self) { test in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color)
                        .padding(.top, 2)
                    Text(test)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - Collapsible Section Header
    @ViewBuilder
    private func collapsibleHeader(icon: String, color: Color, title: String, isExpanded: Binding<Bool>) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() } }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(color.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Differential Diagnosis Section (task 3.3)
    @ViewBuilder
    private var differentialDiagnosisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language == .portuguese ?
                 "Condições similares a considerar:" :
                 "Similar conditions to have considered:")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            ForEach(result.differentialDiagnoses.indices, id: \.self) { index in
                let entry = result.differentialDiagnoses[index]
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text(entry.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if !entry.sharedSymptoms.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language == .portuguese ? "Sintomas em comum:" : "Shared features:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(entry.sharedSymptoms, id: \.self) { symptom in
                                HStack(spacing: 4) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))
                                        .foregroundColor(.purple.opacity(0.6))
                                    Text(symptom)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.leading, 16)
                    }

                    if !entry.distinguishingFeatures.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(language == .portuguese ? "Não nesta condição:" : "Not in this condition:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            ForEach(entry.distinguishingFeatures, id: \.self) { feature in
                                HStack(spacing: 4) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))
                                        .foregroundColor(.green.opacity(0.7))
                                    Text(feature)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.leading, 16)
                    }
                }

                if index < result.differentialDiagnoses.count - 1 {
                    Divider()
                        .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.06))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Study Notes Section (task 3.3)
    @ViewBuilder
    private var studyNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language == .portuguese ?
                 "Dicas diagnósticas para esta condição:" :
                 "Diagnostic clues for this condition:")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            ForEach(result.studyNotes.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.teal)
                        .padding(.top, 2)
                    Text(result.studyNotes[index])
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color.teal.opacity(0.06))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    /// Returns 0 = none, 1 = low, 2 = moderate, 3 = high based on most expensive test ordered.
    private func totalCostLevel(for tests: [String]) -> Int {
        guard !tests.isEmpty else { return 0 }
        let highCostKeywords = [
            // English
            "mri", "ct scan", "ct-scan", "pet scan", "colonoscopy", "biopsy", "endoscopy", "bronchoscopy", "angiography",
            // Portuguese
            "ressonância", "tomografia", "colonoscopia", "biópsia", "biopsia", "endoscopia", "broncoscopia", "angiografia"
        ]
        let moderateCostKeywords = [
            // English
            "x-ray", "xray", "ultrasound", "ecg", "ekg", "echocardiogram", "stress test", "spirometry", "holter",
            // Portuguese
            "raio-x", "raio x", "ultrassom", "ultrassonografia", "ecocardiograma", "espirometria"
        ]
        var maxLevel = 1
        for test in tests {
            let lower = test.lowercased()
            if highCostKeywords.contains(where: { lower.contains($0) }) {
                return 3 // Found a high-cost test — no need to check further
            } else if moderateCostKeywords.contains(where: { lower.contains($0) }) {
                maxLevel = 2
            }
        }
        return maxLevel
    }
}
