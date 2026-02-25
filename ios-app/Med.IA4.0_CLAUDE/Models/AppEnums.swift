import Foundation

// MARK: - Treatment Category

enum TreatmentCategory: String, Codable {
    case medication
    case procedure
    case lifestyle
    case supportive
}

// MARK: - Training Mode

enum TrainingMode: String, Codable {
    case clinical  // Full diagnostic simulation
    case basic     // Structured anamnese training

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .clinical:
            return language == .portuguese ? "Clínico - Diagnóstico Completo" : "Clinical - Full Diagnosis"
        case .basic:
            return language == .portuguese ? "Básico - Treinamento de Anamnese" : "Basic - Anamnese Training"
        }
    }

    func description(language: AppLanguage) -> String {
        switch self {
        case .clinical:
            return language == .portuguese ?
                "Modo completo de simulação diagnóstica com avaliação de tratamento" :
                "Complete diagnostic simulation with treatment evaluation"
        case .basic:
            return language == .portuguese ?
                "Aprenda a fazer uma anamnese estruturada na ordem correta" :
                "Learn to perform structured history taking in correct order"
        }
    }
}

// MARK: - Anamnese Section

enum AnamneseSection: Int, CaseIterable, Codable {
    case identification = 1       // IDENTIFICAÇÃO
    case chiefComplaint = 2       // QUEIXA PRINCIPAL
    case presentIllness = 3       // HISTÓRIA DA DOENÇA ATUAL (HDA)
    case guidingSymptom = 4       // SINTOMA GUIA
    case personalHistory = 5      // ANTECEDENTES PESSOAIS
    case familyHistory = 6        // ANTECEDENTES FAMILIARES
    case lifestyle = 7            // HÁBITOS DE VIDA

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .identification:
            return language == .portuguese ? "1. Identificação" : "1. Identification"
        case .chiefComplaint:
            return language == .portuguese ? "2. Queixa Principal" : "2. Chief Complaint"
        case .presentIllness:
            return language == .portuguese ? "3. História da Doença Atual" : "3. Present Illness History"
        case .guidingSymptom:
            return language == .portuguese ? "4. Sintoma Guia" : "4. Guiding Symptom"
        case .personalHistory:
            return language == .portuguese ? "5. Antecedentes Pessoais" : "5. Personal History"
        case .familyHistory:
            return language == .portuguese ? "6. Antecedentes Familiares" : "6. Family History"
        case .lifestyle:
            return language == .portuguese ? "7. Hábitos de Vida" : "7. Lifestyle Habits"
        }
    }
}

// MARK: - Disease Stage

enum DiseaseStage {
    case early
    case moderate
    case advanced
    case acute
    case chronic
    case remission

    func getDescription(language: AppLanguage) -> String {
        if language == .portuguese {
            switch self {
            case .early: return "Inicial"
            case .moderate: return "Moderado"
            case .advanced: return "Avançado"
            case .acute: return "Agudo"
            case .chronic: return "Crônico"
            case .remission: return "Remissão"
            }
        } else {
            switch self {
            case .early: return "Early stage"
            case .moderate: return "Moderate stage"
            case .advanced: return "Advanced stage"
            case .acute: return "Acute"
            case .chronic: return "Chronic"
            case .remission: return "Remission"
            }
        }
    }
}

// MARK: - Session Status

enum SessionStatus: String, CaseIterable, Codable {
    case inProgress = "in_progress"
    case completed = "completed"
    case abandoned = "abandoned"
}

// MARK: - Difficulty Level

enum DifficultyLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .beginner:
            return language == .portuguese ? "Iniciante" : "Beginner"
        case .intermediate:
            return language == .portuguese ? "Intermediário" : "Intermediate"
        case .advanced:
            return language == .portuguese ? "Avançado" : "Advanced"
        case .expert:
            return language == .portuguese ? "Especialista" : "Expert"
        }
    }
}
