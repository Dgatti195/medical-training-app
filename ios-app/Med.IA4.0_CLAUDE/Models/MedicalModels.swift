import Foundation

// MARK: - Medical Database Models

struct Disease: Identifiable {
    let id: Int
    let nameEnglish: String
    let namePortuguese: String
    let category: String
    let severity: String
    let descriptionEnglish: String
    let descriptionPortuguese: String
    let difficultyRating: Int // 1-5 stars (1=easy, 5=very hard)

    // Computed difficulty based on characteristics
    var computedDifficulty: Int {
        // Calculate difficulty based on category and severity
        var difficulty = 2 // Base difficulty

        switch category {
        case "Neurological":
            difficulty += 2 // Neurological cases are typically harder
        case "Cardiovascular":
            difficulty += 1
        case "Gastrointestinal", "Respiratory":
            difficulty += 0 // Standard difficulty
        case "Endocrine":
            difficulty += 1
        default:
            difficulty += 0
        }

        if severity.contains("Severe") || severity.contains("Critical") {
            difficulty += 1
        }

        return min(max(difficulty, 1), 5) // Clamp between 1-5
    }

    // Loaded separately from database
    var symptoms: [Symptom] = []
    var physicalFindings: [PhysicalFinding] = []
    var labResults: [LabResult] = []
    var hints: [DiagnosticHint] = []
    var treatments: [Treatment] = []

    func getDisplayName(_ language: AppLanguage) -> String {
        return language == .portuguese ? namePortuguese : nameEnglish
    }

    func getDescription(_ language: AppLanguage) -> String {
        return language == .portuguese ? descriptionPortuguese : descriptionEnglish
    }
}

struct Symptom: Identifiable {
    let id: Int
    let diseaseId: Int
    let symptomEnglish: String
    let symptomPortuguese: String
    let isChiefComplaint: Bool

    func getText(_ language: AppLanguage) -> String {
        return language == .portuguese ? symptomPortuguese : symptomEnglish
    }
}

struct PhysicalFinding: Identifiable {
    let id: Int
    let diseaseId: Int
    let findingEnglish: String
    let findingPortuguese: String

    func getText(_ language: AppLanguage) -> String {
        return language == .portuguese ? findingPortuguese : findingEnglish
    }
}

struct LabResult: Identifiable {
    let id: Int
    let diseaseId: Int
    let resultEnglish: String
    let resultPortuguese: String

    func getText(_ language: AppLanguage) -> String {
        return language == .portuguese ? resultPortuguese : resultEnglish
    }
}

struct DiagnosticHint: Identifiable {
    let id: Int
    let diseaseId: Int
    let hintEnglish: String
    let hintPortuguese: String

    func getText(_ language: AppLanguage) -> String {
        return language == .portuguese ? hintPortuguese : hintEnglish
    }
}

struct Treatment: Identifiable {
    let id: Int
    let diseaseId: Int
    let treatmentEnglish: String
    let treatmentPortuguese: String
    let isPrimaryTreatment: Bool
    let category: TreatmentCategory

    func getText(_ language: AppLanguage) -> String {
        return language == .portuguese ? treatmentPortuguese : treatmentEnglish
    }
}
