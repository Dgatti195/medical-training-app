import Foundation

// MARK: - Patient Personality System
struct PatientPersonality: Codable {
    let type: PersonalityType
    let communicationStyle: CommunicationStyle
    var cooperationLevel: Double // 0.0-1.0
    var painTolerance: Double // 0.0-1.0
    var anxietyLevel: Double // 0.0-1.0
    var trustLevel: Double // 0.0-1.0 (affects how much they reveal)
    var memoryClarity: Double // 0.0-1.0 (affects detail accuracy)

    static func generateRandom() -> PatientPersonality {
        let personalityType = PersonalityType.allCases.randomElement()!

        // Adjust probabilities based on personality type
        let (cooperation, pain, anxiety, trust, memory) = generateTraits(for: personalityType)

        return PatientPersonality(
            type: personalityType,
            communicationStyle: CommunicationStyle.allCases.randomElement()!,
            cooperationLevel: cooperation,
            painTolerance: pain,
            anxietyLevel: anxiety,
            trustLevel: trust,
            memoryClarity: memory
        )
    }

    private static func generateTraits(for type: PersonalityType) -> (Double, Double, Double, Double, Double) {
        switch type {
        case .anxious:
            return (0.6, 0.3, 0.8, 0.5, 0.4) // Low pain tolerance, high anxiety
        case .stoic:
            return (0.8, 0.9, 0.2, 0.7, 0.8) // High pain tolerance, low anxiety
        case .talkative:
            return (0.9, 0.5, 0.3, 0.8, 0.6) // Very cooperative, shares everything
        case .defensive:
            return (0.3, 0.7, 0.6, 0.2, 0.7) // Low cooperation, low trust
        case .cooperative:
            return (0.9, 0.6, 0.3, 0.9, 0.9) // High in most positive traits
        case .confused:
            return (0.5, 0.5, 0.7, 0.6, 0.2) // Poor memory, moderate anxiety
        }
    }

    func getPersonalityPromptModifier(language: AppLanguage) -> String {
        let langPrefix = language == .portuguese ?
            "Você é um paciente com personalidade" :
            "You are a patient with a"

        let personalityDesc = type.description(language: language)
        let commStyle = communicationStyle.modifier(language: language)

        let cooperationDesc = language == .portuguese ?
            "Nível de cooperação: \(Int(cooperationLevel * 100))%" :
            "Cooperation level: \(Int(cooperationLevel * 100))%"

        let anxietyDesc = language == .portuguese ?
            "Nível de ansiedade: \(Int(anxietyLevel * 100))%" :
            "Anxiety level: \(Int(anxietyLevel * 100))%"

        return """
        \(langPrefix) \(personalityDesc.lowercased()).
        Você responde às perguntas \(commStyle).
        \(cooperationDesc), \(anxietyDesc).
        """
    }
}

// MARK: - Patient Demographics and History (Runtime Generated)
struct SocialHistory {
    let smokingStatus: String
    let alcoholUse: String
    let occupation: String
    let exerciseLevel: String
    let diet: String
    let substanceUse: String

    func getDescription(language: AppLanguage) -> String {
        if language == .portuguese {
            return "Tabagismo: \(smokingStatus), Álcool: \(alcoholUse), Ocupação: \(occupation), Exercício: \(exerciseLevel), Dieta: \(diet)"
        } else {
            return "Smoking: \(smokingStatus), Alcohol: \(alcoholUse), Occupation: \(occupation), Exercise: \(exerciseLevel), Diet: \(diet)"
        }
    }
}

struct FamilyHistory {
    let cardiovascularDisease: Bool
    let diabetes: Bool
    let cancer: Bool
    let mentalHealth: Bool
    let autoimmune: Bool
    let neurologicalDisorders: Bool
    let relevantConditions: [String]

    func getDescription(language: AppLanguage) -> String {
        var conditions: [String] = []

        if language == .portuguese {
            if cardiovascularDisease { conditions.append("Doença cardiovascular") }
            if diabetes { conditions.append("Diabetes") }
            if cancer { conditions.append("Câncer") }
            if mentalHealth { conditions.append("Transtornos mentais") }
            if autoimmune { conditions.append("Doenças autoimunes") }
            if neurologicalDisorders { conditions.append("Distúrbios neurológicos") }
            conditions.append(contentsOf: relevantConditions)

            return conditions.isEmpty ? "Sem história familiar significativa" : "História familiar: \(conditions.joined(separator: ", "))"
        } else {
            if cardiovascularDisease { conditions.append("Cardiovascular disease") }
            if diabetes { conditions.append("Diabetes") }
            if cancer { conditions.append("Cancer") }
            if mentalHealth { conditions.append("Mental health disorders") }
            if autoimmune { conditions.append("Autoimmune diseases") }
            if neurologicalDisorders { conditions.append("Neurological disorders") }
            conditions.append(contentsOf: relevantConditions)

            return conditions.isEmpty ? "No significant family history" : "Family history: \(conditions.joined(separator: ", "))"
        }
    }
}

struct PatientDemographics {
    let patientID: String
    let age: Int
    let gender: String
    let ethnicity: String
    let name: String
    let height: String
    let weight: String
    let socialHistory: SocialHistory
    let familyHistory: FamilyHistory

    // MARK: - Shared name pools (task 13.3 — extracted to avoid duplication)
    private static let maleNamesPortuguese = [
        "Carlos Santos", "João Pereira", "Ricardo Lima", "Fernando Costa", "André Silva", "Paulo Oliveira",
        "Gabriel Rocha", "Lucas Ferreira", "Pedro Almeida", "Rafael Cardoso", "Mateus Barbosa", "Diego Martins",
        "Bruno Nascimento", "Thiago Carvalho", "Rodrigo Moreira", "Leandro Dias", "Marcelo Ribeiro", "Daniel Cruz"
    ]
    private static let femaleNamesPortuguese = [
        "Ana Silva", "Maria Oliveira", "Fernanda Costa", "Patrícia Souza", "Juliana Lima", "Carla Santos",
        "Gabriela Rocha", "Beatriz Ferreira", "Camila Almeida", "Larissa Cardoso", "Amanda Barbosa", "Isabela Martins",
        "Letícia Nascimento", "Mariana Carvalho", "Natália Moreira", "Priscila Dias", "Viviane Ribeiro", "Carolina Cruz"
    ]
    private static let maleNamesEnglish = [
        "Michael Chen", "David Kim", "James Smith", "Robert Johnson", "Ahmed Hassan", "Carlos Rodriguez",
        "William Garcia", "Benjamin Lee", "Christopher Martinez", "Daniel Thompson", "Matthew Anderson", "Jose Hernandez",
        "Anthony Lewis", "Mark Taylor", "Steven Clark", "Kevin Walker", "Brian Hall", "Edward Young"
    ]
    private static let femaleNamesEnglish = [
        "Sarah Johnson", "Maria Rodriguez", "Jennifer Smith", "Rebecca Martinez", "Lisa Wong", "Amanda Davis",
        "Jessica Garcia", "Emily Wilson", "Ashley Brown", "Michelle Lopez", "Samantha Taylor", "Elizabeth Martinez",
        "Nicole Anderson", "Rachel Thomas", "Stephanie Jackson", "Lauren White", "Kimberly Harris", "Amy Clark"
    ]

    static func generateRandom(language: AppLanguage) -> PatientDemographics {
        let ages = Array(18...85)
        let genders = language == .portuguese ? ["masculino", "feminino"] : ["male", "female"]

        let selectedGender = genders.randomElement()!
        let isFemale = selectedGender == (language == .portuguese ? "feminino" : "female")
        let names = isFemale
            ? (language == .portuguese ? femaleNamesPortuguese : femaleNamesEnglish)
            : (language == .portuguese ? maleNamesPortuguese : maleNamesEnglish)

        let ethnicities = language == .portuguese ?
            ["Branco", "Pardo", "Negro", "Asiático", "Indígena"] :
            ["Caucasian", "Hispanic", "African American", "Asian", "Native American", "Middle Eastern"]

        let selectedAge = ages.randomElement()!
        let socialHistory = generateRandomSocialHistory(age: selectedAge, language: language)
        let familyHistory = generateRandomFamilyHistory()

        return PatientDemographics(
            patientID: "PT-\(Int.random(in: 100000...999999))",
            age: selectedAge,
            gender: selectedGender,
            ethnicity: ethnicities.randomElement()!,
            name: names.randomElement()!,
            height: generateRandomHeight(language: language),
            weight: generateRandomWeight(language: language),
            socialHistory: socialHistory,
            familyHistory: familyHistory
        )
    }

    static func generateRealistic(for disease: Disease, language: AppLanguage) -> PatientDemographics {
        // Age ranges based on common disease patterns
        let ageRange = determineAgeRange(for: disease)
        let ages = Array(ageRange)

        let genders = language == .portuguese ? ["masculino", "feminino"] : ["male", "female"]

        let selectedGender = genders.randomElement()!
        let isFemale = selectedGender == (language == .portuguese ? "feminino" : "female")
        // Use shared static name pools (task 13.3 — no duplication)
        let names = isFemale
            ? (language == .portuguese ? femaleNamesPortuguese : femaleNamesEnglish)
            : (language == .portuguese ? maleNamesPortuguese : maleNamesEnglish)

        let ethnicities = language == .portuguese ?
            ["Branco", "Pardo", "Negro", "Asiático", "Indígena"] :
            ["Caucasian", "Hispanic", "African American", "Asian", "Native American", "Middle Eastern"]

        let selectedAge = ages.randomElement()!

        // Generate disease-aware social and family history
        let socialHistory = generateDiseaseAwareSocialHistory(age: selectedAge, disease: disease, language: language)
        let familyHistory = generateDiseaseAwareFamilyHistory(disease: disease)

        return PatientDemographics(
            patientID: "PT-\(Int.random(in: 100000...999999))",
            age: selectedAge,
            gender: selectedGender,
            ethnicity: ethnicities.randomElement()!,
            name: names.randomElement()!,
            height: generateRandomHeight(language: language),
            weight: generateRandomWeight(language: language),
            socialHistory: socialHistory,
            familyHistory: familyHistory
        )
    }

    private static func determineAgeRange(for disease: Disease) -> ClosedRange<Int> {
        let diseaseName = disease.nameEnglish.lowercased()
        let category = disease.category.lowercased()

        // Pediatric conditions
        if diseaseName.contains("congenital") || diseaseName.contains("pediatric") ||
           category.contains("pediatric") {
            return 1...17
        }

        // Geriatric conditions
        if diseaseName.contains("alzheimer") || diseaseName.contains("parkinson") ||
           diseaseName.contains("osteoporosis") || diseaseName.contains("dementia") ||
           category.contains("geriatric") {
            return 65...85
        }

        // Reproductive health conditions
        if category.contains("gynecologic") || category.contains("obstetric") ||
           diseaseName.contains("pregnancy") || diseaseName.contains("menstrual") {
            return 15...50
        }

        // Cardiovascular conditions (more common in older adults)
        if category.contains("cardiovascular") || diseaseName.contains("heart") ||
           diseaseName.contains("cardiac") || diseaseName.contains("coronary") {
            return 40...80
        }

        // Cancer (can affect any age but more common in adults)
        if category.contains("oncology") || diseaseName.contains("cancer") ||
           diseaseName.contains("tumor") || diseaseName.contains("carcinoma") {
            return 30...75
        }

        // Infectious diseases (more common in younger adults)
        if category.contains("infectious") || diseaseName.contains("infection") ||
           diseaseName.contains("pneumonia") || diseaseName.contains("sepsis") {
            return 18...65
        }

        // Default adult range
        return 18...70
    }

    private static func generateRandomSocialHistory(age: Int, language: AppLanguage) -> SocialHistory {
        // Smoking status based on age and modern trends
        let smokingOptions = language == .portuguese ?
            ["Nunca fumou", "Ex-fumante", "Fumante atual (leve)", "Fumante atual (moderado)", "Fumante atual (pesado)"] :
            ["Never smoked", "Former smoker", "Current light smoker", "Current moderate smoker", "Current heavy smoker"]

        let smokingWeights = age < 30 ? [60, 15, 20, 5, 0] : age < 50 ? [40, 35, 15, 8, 2] : [35, 40, 15, 8, 2]
        let smokingStatus = weightedRandomChoice(options: smokingOptions, weights: smokingWeights)

        // Alcohol use
        let alcoholOptions = language == .portuguese ?
            ["Não bebe", "Ocasional", "Social", "Moderado", "Pesado"] :
            ["Non-drinker", "Occasional", "Social drinker", "Moderate use", "Heavy use"]

        let alcoholWeights = [30, 25, 30, 12, 3]
        let alcoholUse = weightedRandomChoice(options: alcoholOptions, weights: alcoholWeights)

        // Occupation based on age
        let occupations = language == .portuguese ?
            generatePortugueseOccupations(age: age) :
            generateEnglishOccupations(age: age)

        let occupation = occupations.randomElement()!

        // Exercise level
        let exerciseOptions = language == .portuguese ?
            ["Sedentário", "Leve", "Moderado", "Intenso"] :
            ["Sedentary", "Light", "Moderate", "Intense"]

        let exerciseWeights = age < 35 ? [15, 25, 45, 15] : age < 55 ? [25, 30, 35, 10] : [40, 35, 20, 5]
        let exerciseLevel = weightedRandomChoice(options: exerciseOptions, weights: exerciseWeights)

        // Diet
        let dietOptions = language == .portuguese ?
            ["Dieta balanceada", "Fast food frequente", "Vegetariano", "Low-carb", "Mediterrânea"] :
            ["Balanced diet", "Frequent fast food", "Vegetarian", "Low-carb", "Mediterranean"]

        let diet = dietOptions.randomElement()!

        // Substance use
        let substanceOptions = language == .portuguese ?
            ["Nenhum", "Maconha ocasional", "Medicamentos controlados"] :
            ["None", "Occasional marijuana", "Prescription medications"]

        let substanceWeights = [85, 10, 5]
        let substanceUse = weightedRandomChoice(options: substanceOptions, weights: substanceWeights)

        return SocialHistory(
            smokingStatus: smokingStatus,
            alcoholUse: alcoholUse,
            occupation: occupation,
            exerciseLevel: exerciseLevel,
            diet: diet,
            substanceUse: substanceUse
        )
    }

    private static func generateRandomFamilyHistory() -> FamilyHistory {
        // Risk factors for common genetic conditions
        let cardiovascularRisk = Double.random(in: 0...1) < 0.25 // 25% have family history of CV disease
        let diabetesRisk = Double.random(in: 0...1) < 0.18 // 18% have family history of diabetes
        let cancerRisk = Double.random(in: 0...1) < 0.20 // 20% have family history of cancer
        let mentalHealthRisk = Double.random(in: 0...1) < 0.15 // 15% have family history of mental health
        let autoimmuneRisk = Double.random(in: 0...1) < 0.08 // 8% have family history of autoimmune
        let neurologicalRisk = Double.random(in: 0...1) < 0.10 // 10% have family history of neurological

        // Add specific relevant conditions occasionally
        var relevantConditions: [String] = []
        if Double.random(in: 0...1) < 0.05 {
            let conditions = ["Huntington's disease", "Cystic fibrosis", "Sickle cell anemia", "Hemophilia", "Thalassemia"]
            relevantConditions.append(conditions.randomElement()!)
        }

        return FamilyHistory(
            cardiovascularDisease: cardiovascularRisk,
            diabetes: diabetesRisk,
            cancer: cancerRisk,
            mentalHealth: mentalHealthRisk,
            autoimmune: autoimmuneRisk,
            neurologicalDisorders: neurologicalRisk,
            relevantConditions: relevantConditions
        )
    }

    private static func weightedRandomChoice(options: [String], weights: [Int]) -> String {
        let totalWeight = weights.reduce(0, +)
        let randomValue = Int.random(in: 0..<totalWeight)

        var currentWeight = 0
        for (index, weight) in weights.enumerated() {
            currentWeight += weight
            if randomValue < currentWeight {
                return options[index]
            }
        }
        return options.last ?? options[0]
    }

    private static func generatePortugueseOccupations(age: Int) -> [String] {
        if age < 25 {
            return ["Estudante", "Estagiário", "Atendente", "Vendedor", "Entregador", "Recepcionista"]
        } else if age < 45 {
            return ["Enfermeiro", "Professor", "Engenheiro", "Contador", "Advogado", "Desenvolvedor", "Gerente", "Técnico", "Designer"]
        } else if age < 65 {
            return ["Diretor", "Médico", "Consultor", "Proprietário", "Executivo", "Especialista", "Supervisor"]
        } else {
            return ["Aposentado", "Consultor", "Voluntário", "Pensionista"]
        }
    }

    private static func generateEnglishOccupations(age: Int) -> [String] {
        if age < 25 {
            return ["Student", "Intern", "Retail worker", "Server", "Delivery driver", "Receptionist"]
        } else if age < 45 {
            return ["Nurse", "Teacher", "Engineer", "Accountant", "Lawyer", "Developer", "Manager", "Technician", "Designer"]
        } else if age < 65 {
            return ["Director", "Physician", "Consultant", "Business owner", "Executive", "Specialist", "Supervisor"]
        } else {
            return ["Retired", "Consultant", "Volunteer", "Pensioner"]
        }
    }

    private static func generateDiseaseAwareSocialHistory(age: Int, disease: Disease, language: AppLanguage) -> SocialHistory {
        let diseaseName = disease.nameEnglish.lowercased()
        let category = disease.category.lowercased()

        // Base social history
        var socialHistory = generateRandomSocialHistory(age: age, language: language)

        // Adjust based on disease risk factors

        // Smoking-related diseases get higher smoking rates
        if diseaseName.contains("lung") || diseaseName.contains("copd") ||
           diseaseName.contains("emphysema") || category.contains("respiratory") {
            let smokingOptions = language == .portuguese ?
                ["Ex-fumante", "Fumante atual (moderado)", "Fumante atual (pesado)"] :
                ["Former smoker", "Current moderate smoker", "Current heavy smoker"]
            socialHistory = SocialHistory(
                smokingStatus: smokingOptions.randomElement()!,
                alcoholUse: socialHistory.alcoholUse,
                occupation: socialHistory.occupation,
                exerciseLevel: socialHistory.exerciseLevel,
                diet: socialHistory.diet,
                substanceUse: socialHistory.substanceUse
            )
        }

        // Liver diseases get higher alcohol use
        if diseaseName.contains("liver") || diseaseName.contains("hepatic") ||
           diseaseName.contains("cirrhosis") {
            let alcoholOptions = language == .portuguese ?
                ["Moderado", "Pesado", "Ex-usuário pesado"] :
                ["Moderate use", "Heavy use", "Former heavy user"]
            socialHistory = SocialHistory(
                smokingStatus: socialHistory.smokingStatus,
                alcoholUse: alcoholOptions.randomElement()!,
                occupation: socialHistory.occupation,
                exerciseLevel: socialHistory.exerciseLevel,
                diet: socialHistory.diet,
                substanceUse: socialHistory.substanceUse
            )
        }

        // Occupational diseases get specific occupations
        if diseaseName.contains("asbestos") || diseaseName.contains("mesothelioma") {
            let occupations = language == .portuguese ?
                ["Ex-trabalhador da construção", "Ex-mecânico", "Ex-soldador"] :
                ["Former construction worker", "Former mechanic", "Former welder"]
            socialHistory = SocialHistory(
                smokingStatus: socialHistory.smokingStatus,
                alcoholUse: socialHistory.alcoholUse,
                occupation: occupations.randomElement()!,
                exerciseLevel: socialHistory.exerciseLevel,
                diet: socialHistory.diet,
                substanceUse: socialHistory.substanceUse
            )
        }

        // Cardiovascular diseases get poor exercise
        if category.contains("cardiovascular") || diseaseName.contains("heart") {
            let exerciseOptions = language == .portuguese ?
                ["Sedentário", "Leve"] :
                ["Sedentary", "Light"]
            socialHistory = SocialHistory(
                smokingStatus: socialHistory.smokingStatus,
                alcoholUse: socialHistory.alcoholUse,
                occupation: socialHistory.occupation,
                exerciseLevel: exerciseOptions.randomElement()!,
                diet: socialHistory.diet,
                substanceUse: socialHistory.substanceUse
            )
        }

        return socialHistory
    }

    private static func generateDiseaseAwareFamilyHistory(disease: Disease) -> FamilyHistory {
        let diseaseName = disease.nameEnglish.lowercased()
        let category = disease.category.lowercased()

        // Base family history
        var familyHistory = generateRandomFamilyHistory()

        // Increase relevant family history based on disease
        if category.contains("cardiovascular") || diseaseName.contains("heart") ||
           diseaseName.contains("cardiac") {
            familyHistory = FamilyHistory(
                cardiovascularDisease: true, // Much higher chance
                diabetes: familyHistory.diabetes,
                cancer: familyHistory.cancer,
                mentalHealth: familyHistory.mentalHealth,
                autoimmune: familyHistory.autoimmune,
                neurologicalDisorders: familyHistory.neurologicalDisorders,
                relevantConditions: familyHistory.relevantConditions
            )
        }

        if diseaseName.contains("diabetes") || category.contains("endocrine") {
            familyHistory = FamilyHistory(
                cardiovascularDisease: familyHistory.cardiovascularDisease,
                diabetes: true, // Much higher chance
                cancer: familyHistory.cancer,
                mentalHealth: familyHistory.mentalHealth,
                autoimmune: familyHistory.autoimmune,
                neurologicalDisorders: familyHistory.neurologicalDisorders,
                relevantConditions: familyHistory.relevantConditions
            )
        }

        if diseaseName.contains("cancer") || diseaseName.contains("carcinoma") ||
           diseaseName.contains("tumor") || category.contains("oncology") {
            familyHistory = FamilyHistory(
                cardiovascularDisease: familyHistory.cardiovascularDisease,
                diabetes: familyHistory.diabetes,
                cancer: true, // Much higher chance
                mentalHealth: familyHistory.mentalHealth,
                autoimmune: familyHistory.autoimmune,
                neurologicalDisorders: familyHistory.neurologicalDisorders,
                relevantConditions: familyHistory.relevantConditions
            )
        }

        if category.contains("psychiatric") || category.contains("mental") ||
           diseaseName.contains("depression") || diseaseName.contains("anxiety") {
            familyHistory = FamilyHistory(
                cardiovascularDisease: familyHistory.cardiovascularDisease,
                diabetes: familyHistory.diabetes,
                cancer: familyHistory.cancer,
                mentalHealth: true, // Much higher chance
                autoimmune: familyHistory.autoimmune,
                neurologicalDisorders: familyHistory.neurologicalDisorders,
                relevantConditions: familyHistory.relevantConditions
            )
        }

        if category.contains("autoimmune") || diseaseName.contains("rheumatoid") ||
           diseaseName.contains("lupus") || diseaseName.contains("crohn") {
            familyHistory = FamilyHistory(
                cardiovascularDisease: familyHistory.cardiovascularDisease,
                diabetes: familyHistory.diabetes,
                cancer: familyHistory.cancer,
                mentalHealth: familyHistory.mentalHealth,
                autoimmune: true, // Much higher chance
                neurologicalDisorders: familyHistory.neurologicalDisorders,
                relevantConditions: familyHistory.relevantConditions
            )
        }

        if category.contains("neurological") || diseaseName.contains("alzheimer") ||
           diseaseName.contains("parkinson") || diseaseName.contains("dementia") {
            familyHistory = FamilyHistory(
                cardiovascularDisease: familyHistory.cardiovascularDisease,
                diabetes: familyHistory.diabetes,
                cancer: familyHistory.cancer,
                mentalHealth: familyHistory.mentalHealth,
                autoimmune: familyHistory.autoimmune,
                neurologicalDisorders: true, // Much higher chance
                relevantConditions: familyHistory.relevantConditions
            )
        }

        return familyHistory
    }

    private static func generateRandomHeight(language: AppLanguage) -> String {
        let heightCm = Int.random(in: 150...195)
        let heightInCm = Double(heightCm)

        if language == .portuguese {
            // Metric system - just centimeters
            return String(format: "%d cm", heightCm)
        } else {
            // Imperial system - feet and inches with cm
            let totalInches = heightInCm / 2.54
            let feet = Int(totalInches / 12.0)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12.0))

            return String(format: "%d'%d\" (%d cm)", feet, inches, heightCm)
        }
    }

    private static func generateRandomWeight(language: AppLanguage) -> String {
        let weightKg = Int.random(in: 45...120)
        let weightInKg = Double(weightKg)

        if language == .portuguese {
            // Metric system - just kilograms
            return String(format: "%.0f kg", weightInKg)
        } else {
            // Imperial system - pounds with kg
            let weightInLbs = weightInKg * 2.20462
            return String(format: "%.0f lbs (%.0f kg)", weightInLbs, weightInKg)
        }
    }
}

// MARK: - Patient Case
struct PatientCase {
    let disease: Disease
    let demographics: PatientDemographics
    var personality: PatientPersonality
    let diseaseStage: DiseaseStage
    let presentingSymptoms: [Symptom]
    let presentingFindings: [PhysicalFinding]
    let availableLabResults: [LabResult]
    let availableHints: [DiagnosticHint]

    // Computed property for AI prompt integration
    func getPersonalizedPromptContext(language: AppLanguage) -> String {
        let personalityModifier = personality.getPersonalityPromptModifier(language: language)
        let patientInfo = language == .portuguese ?
            "Paciente: \(demographics.name), \(demographics.age) anos, \(demographics.gender)" :
            "Patient: \(demographics.name), \(demographics.age) years old, \(demographics.gender)"

        let socialHistoryInfo = demographics.socialHistory.getDescription(language: language)
        let familyHistoryInfo = demographics.familyHistory.getDescription(language: language)
        let stageInfo = language == .portuguese ?
            "Estágio da doença: \(diseaseStage.getDescription(language: language))" :
            "Disease stage: \(diseaseStage.getDescription(language: language))"

        if language == .portuguese {
            return """
            \(personalityModifier)
            \(patientInfo)
            \(stageInfo)

            História Social: \(socialHistoryInfo)
            \(familyHistoryInfo)

            Responda às perguntas do médico de acordo com sua personalidade, história e os sintomas que você tem.
            Lembre-se do estágio da sua doença ao descrever os sintomas.
            """
        } else {
            return """
            \(personalityModifier)
            \(patientInfo)
            \(stageInfo)

            Social History: \(socialHistoryInfo)
            \(familyHistoryInfo)

            Answer the doctor's questions according to your personality, history, and symptoms.
            Remember your disease stage when describing symptoms.
            """
        }
    }
}
