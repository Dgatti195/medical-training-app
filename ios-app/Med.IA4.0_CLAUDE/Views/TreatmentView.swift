import SwiftUI

struct TreatmentPrescriptionEntryView: View {
    @Binding var userTreatment: String
    let language: AppLanguage
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @State private var localTreatment = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(language == .portuguese ? "Prescreva o tratamento" : "Prescribe Treatment")
                    .font(.title2)
                    .bold()
                    .padding(.top)

            Text(language == .portuguese ?
                "Digite o plano de tratamento para este paciente:" :
                "Enter the treatment plan for this patient:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $localTreatment)
                    .frame(height: 150)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                    )

                if localTreatment.isEmpty {
                    Text(language == .portuguese ?
                         "Ex: Antibióticos de amplo espectro, hidratação, repouso..." :
                         "e.g., Broad-spectrum antibiotics, hydration, rest...")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 20) {
                Button(language == .portuguese ? "Pular" : "Skip") {
                    onCancel()
                }
                .foregroundColor(.secondary)

                Button(language == .portuguese ? "Submeter" : "Submit") {
                    userTreatment = localTreatment
                    onSubmit()
                }
                .foregroundColor(.blue)
                .disabled(localTreatment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.bottom)
            }
            .navigationTitle(language == .portuguese ? "Tratamento" : "Treatment")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

struct TreatmentEvaluationView: View {
    let result: TreatmentResult
    let language: AppLanguage
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Your Treatment
                    VStack(alignment: .leading, spacing: 8) {
                        Text(language == .portuguese ? "Sua Prescrição:" : "Your Prescription:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(result.userTreatment)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Score display
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                                .frame(width: 120, height: 120)

                            Circle()
                                .trim(from: 0, to: CGFloat(result.score))
                                .stroke(
                                    result.isAcceptable ? Color.green : Color.orange,
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut, value: result.score)

                            VStack(spacing: 4) {
                                Text("\(Int(result.score * 100))%")
                                    .font(.title)
                                    .bold()
                                Text(language == .portuguese ? "Pontuação" : "Score")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text(result.isAcceptable ?
                             (language == .portuguese ? "Tratamento Apropriado" : "Appropriate Treatment") :
                             (language == .portuguese ? "Precisa Melhorar" : "Needs Improvement"))
                            .font(.headline)
                            .foregroundColor(result.isAcceptable ? .green : .orange)
                    }
                    .padding(.top)

                    // Feedback message
                    Text(result.feedback)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                    // Matched treatments
                    if !result.matchedTreatments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(language == .portuguese ? "Tratamentos Identificados:" : "Identified Treatments:")
                                .font(.headline)
                                .foregroundColor(.green)

                            ForEach(result.matchedTreatments) { treatment in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(treatment.getText(language))
                                        .font(.body)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // Missed primary treatments
                    if !result.missedTreatments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(language == .portuguese ? "Tratamentos Primários Ausentes:" : "Missed Primary Treatments:")
                                .font(.headline)
                                .foregroundColor(.orange)

                            ForEach(result.missedTreatments) { treatment in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(treatment.getText(language))
                                        .font(.body)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // Show all correct treatments when score is very low (no matches)
                    if result.matchedTreatments.isEmpty && !result.correctTreatments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(language == .portuguese ? "Tratamentos Corretos:" : "Correct Treatments:")
                                .font(.headline)
                                .foregroundColor(.blue)

                            ForEach(result.correctTreatments.filter { $0.isPrimaryTreatment }) { treatment in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(treatment.getText(language))
                                            .font(.body)
                                        Text(treatment.category.rawValue.capitalized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }

                    Button(language == .portuguese ? "Ver Material de Estudo" : "View Study Materials") {
                        onDismiss()
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(language == .portuguese ? "Avaliação do Tratamento" : "Treatment Evaluation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
