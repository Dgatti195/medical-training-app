import SwiftUI
import Foundation
import SQLite3
import Speech
import AVFoundation

// MARK: - Define SQLITE_TRANSIENT constant
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Patient Personality System
enum PersonalityType: String, CaseIterable, Codable {
    case anxious = "anxious"
    case stoic = "stoic" 
    case talkative = "talkative"
    case defensive = "defensive"
    case cooperative = "cooperative"
    case confused = "confused"
    
    func displayName(language: AppLanguage) -> String {
        switch self {
        case .anxious:
            return language == .portuguese ? "Ansioso" : "Anxious"
        case .stoic:
            return language == .portuguese ? "Estoico" : "Stoic"
        case .talkative:
            return language == .portuguese ? "Falante" : "Talkative"
        case .defensive:
            return language == .portuguese ? "Defensivo" : "Defensive"
        case .cooperative:
            return language == .portuguese ? "Cooperativo" : "Cooperative"
        case .confused:
            return language == .portuguese ? "Confuso" : "Confused"
        }
    }
    
    func description(language: AppLanguage) -> String {
        switch self {
        case .anxious:
            return language == .portuguese ? 
                "Preocupado com os sintomas, faz muitas perguntas" :
                "Worried about symptoms, asks many questions"
        case .stoic:
            return language == .portuguese ? 
                "Relata sintomas de forma objetiva, minimiza dor" :
                "Reports symptoms matter-of-factly, downplays pain"
        case .talkative:
            return language == .portuguese ? 
                "Compartilha detalhes extras, histórias pessoais" :
                "Shares extra details, personal stories"
        case .defensive:
            return language == .portuguese ? 
                "Resistente a certas perguntas, pode ser evasivo" :
                "Resistant to certain questions, may be evasive"
        case .cooperative:
            return language == .portuguese ? 
                "Responde claramente, segue instruções bem" :
                "Answers clearly, follows instructions well"
        case .confused:
            return language == .portuguese ? 
                "Tem dificuldade em lembrar detalhes, pode estar desorientado" :
                "Has trouble remembering details, may be disoriented"
        }
    }
}

enum CommunicationStyle: String, CaseIterable, Codable {
    case direct = "direct"
    case rambling = "rambling"
    case minimal = "minimal"
    case emotional = "emotional"
    
    func modifier(language: AppLanguage) -> String {
        switch self {
        case .direct:
            return language == .portuguese ? "de forma direta" : "directly"
        case .rambling:
            return language == .portuguese ? "com muitos detalhes" : "with many details"
        case .minimal:
            return language == .portuguese ? "com poucas palavras" : "with few words"
        case .emotional:
            return language == .portuguese ? "de forma emotiva" : "emotionally"
        }
    }
}

struct PatientPersonality: Codable {
    let type: PersonalityType
    let communicationStyle: CommunicationStyle
    let cooperationLevel: Double // 0.0-1.0
    let painTolerance: Double // 0.0-1.0
    let anxietyLevel: Double // 0.0-1.0
    let trustLevel: Double // 0.0-1.0 (affects how much they reveal)
    let memoryClarity: Double // 0.0-1.0 (affects detail accuracy)
    
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

// MARK: - Database Models
struct Disease: Identifiable {
    let id: Int
    let nameEnglish: String
    let namePortuguese: String
    let category: String
    let severity: String
    let descriptionEnglish: String
    let descriptionPortuguese: String
    
    // Loaded separately from database
    var symptoms: [Symptom] = []
    var physicalFindings: [PhysicalFinding] = []
    var labResults: [LabResult] = []
    var hints: [DiagnosticHint] = []
    
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

struct PatientDemographics {
    let age: Int
    let gender: String
    let ethnicity: String
    let name: String
    let height: String
    let weight: String
    let socialHistory: SocialHistory
    let familyHistory: FamilyHistory
    
    static func generateRandom(language: AppLanguage) -> PatientDemographics {
        let ages = Array(18...85)
        let genders = language == .portuguese ? ["masculino", "feminino"] : ["male", "female"]
        
        let maleNames = language == .portuguese ?
            ["Carlos Santos", "João Pereira", "Ricardo Lima", "Fernando Costa", "André Silva", "Paulo Oliveira", 
             "Gabriel Rocha", "Lucas Ferreira", "Pedro Almeida", "Rafael Cardoso", "Mateus Barbosa", "Diego Martins",
             "Bruno Nascimento", "Thiago Carvalho", "Rodrigo Moreira", "Leandro Dias", "Marcelo Ribeiro", "Daniel Cruz"] :
            ["Michael Chen", "David Kim", "James Smith", "Robert Johnson", "Ahmed Hassan", "Carlos Rodriguez",
             "William Garcia", "Benjamin Lee", "Christopher Martinez", "Daniel Thompson", "Matthew Anderson", "Jose Hernandez",
             "Anthony Lewis", "Mark Taylor", "Steven Clark", "Kevin Walker", "Brian Hall", "Edward Young"]
        
        let femaleNames = language == .portuguese ?
            ["Ana Silva", "Maria Oliveira", "Fernanda Costa", "Patrícia Souza", "Juliana Lima", "Carla Santos",
             "Gabriela Rocha", "Beatriz Ferreira", "Camila Almeida", "Larissa Cardoso", "Amanda Barbosa", "Isabela Martins",
             "Letícia Nascimento", "Mariana Carvalho", "Natália Moreira", "Priscila Dias", "Viviane Ribeiro", "Carolina Cruz"] :
            ["Sarah Johnson", "Maria Rodriguez", "Jennifer Smith", "Rebecca Martinez", "Lisa Wong", "Amanda Davis",
             "Jessica Garcia", "Emily Wilson", "Ashley Brown", "Michelle Lopez", "Samantha Taylor", "Elizabeth Martinez",
             "Nicole Anderson", "Rachel Thomas", "Stephanie Jackson", "Lauren White", "Kimberly Harris", "Amy Clark"]
        
        let selectedGender = genders.randomElement()!
        let isFemale = selectedGender == (language == .portuguese ? "feminino" : "female")
        let names = isFemale ? femaleNames : maleNames
        
        let ethnicities = language == .portuguese ?
            ["Branco", "Pardo", "Negro", "Asiático", "Indígena"] :
            ["Caucasian", "Hispanic", "African American", "Asian", "Native American", "Middle Eastern"]
        
        let selectedAge = ages.randomElement()!
        let socialHistory = generateRandomSocialHistory(age: selectedAge, language: language)
        let familyHistory = generateRandomFamilyHistory()
        
        return PatientDemographics(
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
        
        let maleNames = language == .portuguese ?
            ["Carlos Santos", "João Pereira", "Ricardo Lima", "Fernando Costa", "André Silva", "Paulo Oliveira", 
             "Gabriel Rocha", "Lucas Ferreira", "Pedro Almeida", "Rafael Cardoso", "Mateus Barbosa", "Diego Martins",
             "Bruno Nascimento", "Thiago Carvalho", "Rodrigo Moreira", "Leandro Dias", "Marcelo Ribeiro", "Daniel Cruz"] :
            ["Michael Chen", "David Kim", "James Smith", "Robert Johnson", "Ahmed Hassan", "Carlos Rodriguez",
             "William Garcia", "Benjamin Lee", "Christopher Martinez", "Daniel Thompson", "Matthew Anderson", "Jose Hernandez",
             "Anthony Lewis", "Mark Taylor", "Steven Clark", "Kevin Walker", "Brian Hall", "Edward Young"]
        
        let femaleNames = language == .portuguese ?
            ["Ana Silva", "Maria Oliveira", "Fernanda Costa", "Patrícia Souza", "Juliana Lima", "Carla Santos",
             "Gabriela Rocha", "Beatriz Ferreira", "Camila Almeida", "Larissa Cardoso", "Amanda Barbosa", "Isabela Martins",
             "Letícia Nascimento", "Mariana Carvalho", "Natália Moreira", "Priscila Dias", "Viviane Ribeiro", "Carolina Cruz"] :
            ["Sarah Johnson", "Maria Rodriguez", "Jennifer Smith", "Rebecca Martinez", "Lisa Wong", "Amanda Davis",
             "Jessica Garcia", "Emily Wilson", "Ashley Brown", "Michelle Lopez", "Samantha Taylor", "Elizabeth Martinez",
             "Nicole Anderson", "Rachel Thomas", "Stephanie Jackson", "Lauren White", "Kimberly Harris", "Amy Clark"]
        
        let selectedGender = genders.randomElement()!
        let isFemale = selectedGender == (language == .portuguese ? "feminino" : "female")
        let names = isFemale ? femaleNames : maleNames
        
        let ethnicities = language == .portuguese ?
            ["Branco", "Pardo", "Negro", "Asiático", "Indígena"] :
            ["Caucasian", "Hispanic", "African American", "Asian", "Native American", "Middle Eastern"]
        
        let selectedAge = ages.randomElement()!
        
        // Generate disease-aware social and family history
        let socialHistory = generateDiseaseAwareSocialHistory(age: selectedAge, disease: disease, language: language)
        let familyHistory = generateDiseaseAwareFamilyHistory(disease: disease)
        
        return PatientDemographics(
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
        return options.last!
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

// MARK: - Helper Functions
func translateGender(_ gender: String, to language: AppLanguage) -> String {
    let lowercaseGender = gender.lowercased()
    
    if language == .portuguese {
        // If it's already in Portuguese, return as is
        if lowercaseGender.contains("masculino") || lowercaseGender.contains("feminino") {
            return gender
        }
        // Translate from English to Portuguese
        if lowercaseGender.contains("male") && !lowercaseGender.contains("female") {
            return "masculino"
        } else if lowercaseGender.contains("female") {
            return "feminino"
        }
    } else {
        // If it's already in English, return as is
        if lowercaseGender.contains("male") || lowercaseGender.contains("female") {
            return gender
        }
        // Translate from Portuguese to English
        if lowercaseGender.contains("masculino") {
            return "male"
        } else if lowercaseGender.contains("feminino") {
            return "female"
        }
    }
    
    return gender // Fallback to original if no match
}

// MARK: - Medical Category Translation
func translateMedicalCategory(_ category: String, to language: AppLanguage) -> String {
    guard language == .portuguese else { return category }
    
    let translations: [String: String] = [
        // Main categories from your database
        "All": "Todos",
        "Cardiovascular": "Cardiovascular",
        "Musculoskeletal": "Musculoesquelético",
        "Neurological": "Neurológico",
        "Gastrointestinal": "Gastrointestinal", 
        "Infectious": "Infeccioso",
        "Dermatological": "Dermatológico",
        "Endocrine": "Endócrino",
        "Hematological": "Hematológico",
        "Respiratory": "Respiratório",
        "Other": "Outros",
        "Oncological": "Oncológico",
        "Psychiatric": "Psiquiátrico",
        "Gynecological": "Ginecológico",
        "Urological": "Urológico",
        "Ophthalmological": "Oftalmológico",
        "Renal": "Renal",
        "Vascular": "Vascular",
        "Autoimmune": "Autoimune",
        "Otological": "Otológico",
        "Lymphatic": "Linfático",
        "Metabolic/Toxic": "Metabólico/Tóxico",
        "Multisystem": "Multissistêmico",
        "Nutritional": "Nutricional",
        "Otorhinolaryngological": "Otorrinolaringológico",
        "Vasculitic": "Vasculítico",
        "Vasculitis": "Vasculite",
        
        // Additional common categories
        "Emergency": "Emergência",
        "Chronic": "Crônico",
        "Acute": "Agudo",
        "General": "Geral",
        "Pediatric": "Pediátrico",
        "Geriatric": "Geriátrico"
    ]
    
    return translations[category] ?? category
}

// MARK: - Database Manager
class DatabaseManager: ObservableObject {
    private var db: OpaquePointer?
    
    init() {
        openDatabase()
        // Don't create tables or insert sample data - use existing database
    }
    
    deinit {
        if sqlite3_close(db) != SQLITE_OK {
            print("Error closing database")
        }
    }
    
    private func openDatabase() {
        // First try to copy database from bundle to documents directory
        copyDatabaseIfNeeded()
        
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("medical_conditions.sqlite")
        
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            print("Successfully opened connection to database at \(fileURL.path)")
        } else {
            print("Unable to open database - creating fallback")
            createFallbackDatabase()
        }
    }
    
    private func copyDatabaseIfNeeded() {
        let fileManager = FileManager.default
        let documentsURL = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let destinationURL = documentsURL.appendingPathComponent("medical_conditions.sqlite")
        
        // Check if we have the populated database in the bundle
        if let bundlePath = Bundle.main.path(forResource: "medical_conditions", ofType: "sqlite") {
            let bundleURL = URL(fileURLWithPath: bundlePath)
            
            // Always copy the database from bundle to ensure we have the latest version with 447 conditions
            do {
                // Remove existing database if it exists to force fresh copy
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                    print("🔄 Removed old database to update with latest data")
                }
                
                try fileManager.copyItem(at: bundleURL, to: destinationURL)
                print("✅ Database with 447 conditions copied from bundle to documents directory")
            } catch {
                print("❌ Error copying database: \(error)")
                print("Will create fallback database with sample data")
            }
        } else {
            print("❌ Database file not found in bundle - will create fallback")
        }
    }
    
    func forceCopyDatabase() {
        // Close current database connection
        if sqlite3_close(db) != SQLITE_OK {
            print("Error closing database for update")
        }
        
        // Force copy the database
        copyDatabaseIfNeeded()
        
        // Reopen the database
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("medical_conditions.sqlite")
        
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            print("Successfully reopened updated database")
        } else {
            print("Error reopening database after update")
        }
    }
    
    private func createFallbackDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("medical_conditions.sqlite")
        
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            print("Creating fallback database with sample data")
            createTables()
            insertSampleData()
        }
    }
    
    private func createTables() {
        // Create diseases table
        let createDiseasesSQL = """
        CREATE TABLE IF NOT EXISTS diseases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name_english TEXT NOT NULL,
            name_portuguese TEXT NOT NULL,
            category TEXT NOT NULL,
            severity TEXT NOT NULL,
            description_english TEXT,
            description_portuguese TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        // Create symptoms table
        let createSymptomsSQL = """
        CREATE TABLE IF NOT EXISTS symptoms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER,
            symptom_english TEXT NOT NULL,
            symptom_portuguese TEXT NOT NULL,
            is_chief_complaint BOOLEAN DEFAULT FALSE,
            FOREIGN KEY (disease_id) REFERENCES diseases(id)
        );
        """
        
        // Create other tables
        let createPhysicalFindingsSQL = """
        CREATE TABLE IF NOT EXISTS physical_findings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER,
            finding_english TEXT NOT NULL,
            finding_portuguese TEXT NOT NULL,
            FOREIGN KEY (disease_id) REFERENCES diseases(id)
        );
        """
        
        let createLabResultsSQL = """
        CREATE TABLE IF NOT EXISTS lab_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER,
            result_english TEXT NOT NULL,
            result_portuguese TEXT NOT NULL,
            FOREIGN KEY (disease_id) REFERENCES diseases(id)
        );
        """
        
        let createHintsSQL = """
        CREATE TABLE IF NOT EXISTS diagnostic_hints (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER,
            hint_english TEXT NOT NULL,
            hint_portuguese TEXT NOT NULL,
            FOREIGN KEY (disease_id) REFERENCES diseases(id)
        );
        """
        
        // Execute table creation
        if sqlite3_exec(db, createDiseasesSQL, nil, nil, nil) != SQLITE_OK {
            print("Error creating diseases table")
        }
        if sqlite3_exec(db, createSymptomsSQL, nil, nil, nil) != SQLITE_OK {
            print("Error creating symptoms table")
        }
        if sqlite3_exec(db, createPhysicalFindingsSQL, nil, nil, nil) != SQLITE_OK {
            print("Error creating physical_findings table")
        }
        if sqlite3_exec(db, createLabResultsSQL, nil, nil, nil) != SQLITE_OK {
            print("Error creating lab_results table")
        }
        if sqlite3_exec(db, createHintsSQL, nil, nil, nil) != SQLITE_OK {
            print("Error creating diagnostic_hints table")
        }
    }
    
    private func insertSampleData() {
        print("Inserting sample medical data...")
        
        // Insert sample diseases with proper data
        let sampleDiseases = [
            ("Acute Appendicitis", "Apendicite Aguda", "Gastrointestinal", "Urgent"),
            ("Migraine Headache", "Enxaqueca", "Neurological", "Moderate"),
            ("Community-Acquired Pneumonia", "Pneumonia Adquirida na Comunidade", "Respiratory", "Moderate to Severe")
        ]
        
        for (index, disease) in sampleDiseases.enumerated() {
            let diseaseId = insertSampleDisease(
                nameEnglish: disease.0,
                namePortuguese: disease.1,
                category: disease.2,
                severity: disease.3
            )
            
            if diseaseId > 0 {
                insertSampleDataForDisease(diseaseId: diseaseId, diseaseIndex: index)
            }
        }
    }
    
    private func insertSampleDisease(nameEnglish: String, namePortuguese: String, category: String, severity: String) -> Int {
        let insertSQL = """
        INSERT INTO diseases (name_english, name_portuguese, category, severity, description_english, description_portuguese)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, nameEnglish, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, namePortuguese, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, category, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, severity, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, "Clinical description for \(nameEnglish)", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 6, "Descrição clínica para \(namePortuguese)", -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let diseaseId = Int(sqlite3_last_insert_rowid(db))
                sqlite3_finalize(statement)
                return diseaseId
            }
        }
        sqlite3_finalize(statement)
        return -1
    }
    
    private func insertSampleDataForDisease(diseaseId: Int, diseaseIndex: Int) {
        switch diseaseIndex {
        case 0: // Appendicitis
            insertSymptom(diseaseId: diseaseId, english: "Right lower quadrant pain", portuguese: "Dor no quadrante inferior direito", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Nausea", portuguese: "Náusea", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Vomiting", portuguese: "Vômito", isChief: false)
            insertSymptom(diseaseId: diseaseId, english: "Low-grade fever", portuguese: "Febre baixa", isChief: false)
            
        case 1: // Migraine
            insertSymptom(diseaseId: diseaseId, english: "Severe unilateral headache", portuguese: "Dor de cabeça unilateral severa", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Nausea", portuguese: "Náusea", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Photophobia", portuguese: "Fotofobia", isChief: false)
            insertSymptom(diseaseId: diseaseId, english: "Visual aura", portuguese: "Aura visual", isChief: false)
            
        case 2: // Pneumonia
            insertSymptom(diseaseId: diseaseId, english: "Productive cough", portuguese: "Tosse produtiva", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Fever", portuguese: "Febre", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Shortness of breath", portuguese: "Falta de ar", isChief: false)
            insertSymptom(diseaseId: diseaseId, english: "Chest pain", portuguese: "Dor no peito", isChief: false)
            
        default:
            break
        }
    }
    
    private func insertSymptom(diseaseId: Int, english: String, portuguese: String, isChief: Bool) {
        let insertSQL = "INSERT INTO symptoms (disease_id, symptom_english, symptom_portuguese, is_chief_complaint) VALUES (?, ?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(diseaseId))
            sqlite3_bind_text(statement, 2, english, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, portuguese, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 4, isChief ? 1 : 0)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error inserting symptom: \(english)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Helper method for safe string extraction
    private func extractString(from statement: OpaquePointer?, column: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else {
            return nil
        }
        
        let length = sqlite3_column_bytes(statement, column)
        guard length > 0 else {
            return nil
        }
        
        return String(cString: cString)
    }
    
    // MARK: - Data Fetching
    func fetchAllDiseases() -> [Disease] {
        let querySQL = "SELECT id, name_english, name_portuguese, category, severity, description_english, description_portuguese FROM diseases ORDER BY id;"
        var statement: OpaquePointer?
        var diseases: [Disease] = []
        
        print("🔍 Starting disease fetch with query: \(querySQL)")
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                
                let nameEnglish = extractString(from: statement, column: 1) ?? "Unknown Disease"
                let namePortuguese = extractString(from: statement, column: 2) ?? "Doença Desconhecida"
                let category = extractString(from: statement, column: 3) ?? "General"
                let severity = extractString(from: statement, column: 4) ?? "Unknown"
                let descriptionEnglish = extractString(from: statement, column: 5) ?? "No description available"
                let descriptionPortuguese = extractString(from: statement, column: 6) ?? "Nenhuma descrição disponível"
                
                print("✅ Loaded disease: \(nameEnglish) (ID: \(id))")
                
                var disease = Disease(
                    id: id,
                    nameEnglish: nameEnglish,
                    namePortuguese: namePortuguese,
                    category: category,
                    severity: severity,
                    descriptionEnglish: descriptionEnglish,
                    descriptionPortuguese: descriptionPortuguese
                )
                
                disease.symptoms = fetchSymptoms(for: id)
                disease.physicalFindings = fetchPhysicalFindings(for: id)
                disease.labResults = fetchLabResults(for: id)
                disease.hints = fetchHints(for: id)
                
                diseases.append(disease)
            }
        } else {
            print("❌ Error preparing diseases query: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        print("✅ Loaded \(diseases.count) diseases from database")
        return diseases
    }
    
    func fetchSymptoms(for diseaseId: Int) -> [Symptom] {
        let querySQL = "SELECT id, disease_id, symptom_english, symptom_portuguese, is_chief_complaint FROM symptoms WHERE disease_id = ?;"
        var statement: OpaquePointer?
        var symptoms: [Symptom] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(diseaseId))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let diseaseId = Int(sqlite3_column_int(statement, 1))
                
                let english = extractString(from: statement, column: 2) ?? "Unknown symptom"
                let portuguese = extractString(from: statement, column: 3) ?? "Sintoma desconhecido"
                let isChief = sqlite3_column_int(statement, 4) == 1
                
                symptoms.append(Symptom(
                    id: id,
                    diseaseId: diseaseId,
                    symptomEnglish: english,
                    symptomPortuguese: portuguese,
                    isChiefComplaint: isChief
                ))
            }
        }
        sqlite3_finalize(statement)
        return symptoms
    }
    
    func fetchPhysicalFindings(for diseaseId: Int) -> [PhysicalFinding] {
        let querySQL = "SELECT id, disease_id, finding_english, finding_portuguese FROM physical_findings WHERE disease_id = ?;"
        var statement: OpaquePointer?
        var findings: [PhysicalFinding] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(diseaseId))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let diseaseId = Int(sqlite3_column_int(statement, 1))
                
                let english = extractString(from: statement, column: 2) ?? "Unknown finding"
                let portuguese = extractString(from: statement, column: 3) ?? "Achado desconhecido"
                
                findings.append(PhysicalFinding(
                    id: id,
                    diseaseId: diseaseId,
                    findingEnglish: english,
                    findingPortuguese: portuguese
                ))
            }
        }
        sqlite3_finalize(statement)
        return findings
    }
    
    func fetchLabResults(for diseaseId: Int) -> [LabResult] {
        let querySQL = "SELECT id, disease_id, result_english, result_portuguese FROM lab_results WHERE disease_id = ?;"
        var statement: OpaquePointer?
        var results: [LabResult] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(diseaseId))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let diseaseId = Int(sqlite3_column_int(statement, 1))
                
                let english = extractString(from: statement, column: 2) ?? "Unknown result"
                let portuguese = extractString(from: statement, column: 3) ?? "Resultado desconhecido"
                
                results.append(LabResult(
                    id: id,
                    diseaseId: diseaseId,
                    resultEnglish: english,
                    resultPortuguese: portuguese
                ))
            }
        }
        sqlite3_finalize(statement)
        return results
    }
    
    func fetchHints(for diseaseId: Int) -> [DiagnosticHint] {
        let querySQL = "SELECT id, disease_id, hint_english, hint_portuguese FROM diagnostic_hints WHERE disease_id = ?;"
        var statement: OpaquePointer?
        var hints: [DiagnosticHint] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(diseaseId))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let diseaseId = Int(sqlite3_column_int(statement, 1))
                
                let english = extractString(from: statement, column: 2) ?? "Ask more questions"
                let portuguese = extractString(from: statement, column: 3) ?? "Faça mais perguntas"
                
                hints.append(DiagnosticHint(
                    id: id,
                    diseaseId: diseaseId,
                    hintEnglish: english,
                    hintPortuguese: portuguese
                ))
            }
        }
        sqlite3_finalize(statement)
        return hints
    }
}

// MARK: - Patient Case Generator
struct PatientCase {
    let disease: Disease
    let demographics: PatientDemographics
    let personality: PatientPersonality
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

class MedicalDatabaseManager: ObservableObject {
    @Published var diseases: [Disease] = []
    @Published var isLoading = false
    @Published var patientCases: [PatientCase] = []
    @Published var loadingError: String?
    
    private let dbManager = DatabaseManager()
    private var hasLoadedOnce = false
    
    init() {
        loadDiseases()
    }
    
    func loadDiseases() {
        guard !hasLoadedOnce && !isLoading else {
            print("Skipping database load - already loaded or in progress")
            return
        }
        
        print("Starting database load...")
        isLoading = true
        hasLoadedOnce = true
        loadingError = nil
        
        // Load diseases from database
        diseases = dbManager.fetchAllDiseases()
        
        if diseases.isEmpty {
            loadingError = "No diseases found in database"
            print("❌ No diseases loaded from database")
        } else {
            print("✅ Database load completed with \(diseases.count) diseases")
            print("🔍 First few diseases loaded:")
            for (index, disease) in diseases.prefix(5).enumerated() {
                print("  \(index + 1). \(disease.nameEnglish) (Category: \(disease.category))")
            }
            generateConsistentPatientCases()
        }
        
        isLoading = false
        printLoadedDataSummary()
    }
    
    private func printLoadedDataSummary() {
        print("\n=== LOADED DATA SUMMARY ===")
        print("Total diseases: \(diseases.count)")
        
        if !diseases.isEmpty {
            let categoryCounts = Dictionary(grouping: diseases, by: { $0.category })
                .mapValues { $0.count }
            
            print("By category:")
            for (category, count) in categoryCounts.sorted(by: { $0.key < $1.key }) {
                print("  \(category): \(count)")
            }
            
            let totalSymptoms = diseases.reduce(0) { $0 + $1.symptoms.count }
            let totalChiefComplaints = diseases.reduce(0) { $0 + $1.symptoms.filter { $0.isChiefComplaint }.count }
            let totalPhysicalFindings = diseases.reduce(0) { $0 + $1.physicalFindings.count }
            let totalLabResults = diseases.reduce(0) { $0 + $1.labResults.count }
            let totalHints = diseases.reduce(0) { $0 + $1.hints.count }
            
            print("Total symptoms: \(totalSymptoms) (\(totalChiefComplaints) chief complaints)")
            print("Total physical findings: \(totalPhysicalFindings)")
            print("Total lab results: \(totalLabResults)")
            print("Total diagnostic hints: \(totalHints)")
            
            // Sample disease info
            if let firstDisease = diseases.first {
                print("\nSample disease: \(firstDisease.nameEnglish)")
                print("  Category: \(firstDisease.category)")
                print("  Symptoms: \(firstDisease.symptoms.count)")
                print("  Chief complaints: \(firstDisease.symptoms.filter { $0.isChiefComplaint }.count)")
            }
        }
        print("========================\n")
    }
    
    private func generateConsistentPatientCases() {
        patientCases = diseases.map { disease in
            generatePatientCase(from: disease, language: .english)
        }
        print("Generated \(patientCases.count) consistent patient cases from extracted PDF data")
        
        // Verify patient cases have data
        let casesWithSymptoms = patientCases.filter { !$0.presentingSymptoms.isEmpty }
        print("Patient cases with symptoms: \(casesWithSymptoms.count)/\(patientCases.count)")
        
        // Print some demographic distribution statistics
        printPatientDemographics()
    }
    
    private func printPatientDemographics() {
        let ageGroups = Dictionary(grouping: patientCases) { patient in
            switch patient.demographics.age {
            case 1...17: return "Pediatric (1-17)"
            case 18...39: return "Young Adult (18-39)" 
            case 40...64: return "Middle Age (40-64)"
            case 65...85: return "Elderly (65+)"
            default: return "Other"
            }
        }
        
        print("\n=== PATIENT DEMOGRAPHICS ===")
        for (group, patients) in ageGroups.sorted(by: { $0.key < $1.key }) {
            print("\(group): \(patients.count) patients")
        }
        
        let categoryDistribution = Dictionary(grouping: patientCases) { $0.disease.category }
        print("\n=== DISEASE CATEGORIES ===")
        for (category, patients) in categoryDistribution.sorted(by: { $0.value.count > $1.value.count }) {
            print("\(category): \(patients.count) cases")
        }
        print("============================\n")
    }
    
    func regeneratePatientCases() {
        print("Regenerating patient cases with enhanced demographics...")
        generateConsistentPatientCases()
    }
    
    func getPatientCase(for disease: Disease) -> PatientCase? {
        return patientCases.first { $0.disease.id == disease.id }
    }
    
    func generatePatientCase(from disease: Disease, language: AppLanguage) -> PatientCase {
        // Generate demographics that are appropriate for the disease
        let demographics = PatientDemographics.generateRealistic(for: disease, language: language)
        
        // Get chief complaints (prioritize these)
        let chiefComplaints = disease.symptoms
            .filter { $0.isChiefComplaint }
            .shuffled()
        
        // Get additional symptoms
        let additionalSymptoms = disease.symptoms
            .filter { !$0.isChiefComplaint }
            .shuffled()
        
        // Create more realistic symptom presentation based on disease severity
        var presentingSymptoms: [Symptom] = []
        
        // Adjust symptom count based on disease category and severity
        let isEmergency = disease.category.lowercased().contains("emergency") || 
                         disease.severity.lowercased().contains("critical") ||
                         disease.severity.lowercased().contains("severe")
        
        let isChronic = disease.category.lowercased().contains("chronic") ||
                       disease.severity.lowercased().contains("chronic")
        
        // Always include chief complaints
        if !chiefComplaints.isEmpty {
            let chiefCount = isEmergency ? min(chiefComplaints.count, 3) : 
                           isChronic ? min(chiefComplaints.count, 2) :
                           min(chiefComplaints.count, Int.random(in: 1...2))
            presentingSymptoms.append(contentsOf: Array(chiefComplaints.prefix(chiefCount)))
        }
        
        // Add additional symptoms based on complexity
        if !additionalSymptoms.isEmpty {
            let additionalCount = isEmergency ? Int.random(in: 2...4) :
                                 isChronic ? Int.random(in: 1...3) :
                                 Int.random(in: 0...2)
            let actualCount = min(additionalSymptoms.count, additionalCount)
            presentingSymptoms.append(contentsOf: Array(additionalSymptoms.prefix(actualCount)))
        }
        
        // If no symptoms at all, this indicates a data issue
        if presentingSymptoms.isEmpty {
            print("⚠️ Warning: No symptoms found for disease: \(disease.nameEnglish)")
        }
        
        // Determine disease stage based on disease type and patient age
        let diseaseStage = determineDiseaseStage(for: disease, patientAge: demographics.age)
        
        // Adjust symptoms and findings based on disease stage
        let (stagingSymptoms, stagingFindings) = adjustForDiseaseStage(
            symptoms: presentingSymptoms,
            findings: disease.physicalFindings,
            stage: diseaseStage
        )
        
        return PatientCase(
            disease: disease,
            demographics: demographics,
            personality: PatientPersonality.generateRandom(),
            diseaseStage: diseaseStage,
            presentingSymptoms: stagingSymptoms,
            presentingFindings: stagingFindings,
            availableLabResults: disease.labResults,
            availableHints: disease.hints
        )
    }
    
    private func determineDiseaseStage(for disease: Disease, patientAge: Int) -> DiseaseStage {
        let diseaseName = disease.nameEnglish.lowercased()
        let category = disease.category.lowercased()
        let severity = disease.severity.lowercased()
        
        // Acute conditions
        if severity.contains("acute") || diseaseName.contains("acute") ||
           category.contains("emergency") || severity.contains("critical") {
            return .acute
        }
        
        // Chronic conditions
        if severity.contains("chronic") || diseaseName.contains("chronic") ||
           category.contains("chronic") {
            return .chronic
        }
        
        // Cancer staging
        if diseaseName.contains("cancer") || diseaseName.contains("carcinoma") ||
           diseaseName.contains("tumor") || category.contains("oncology") {
            let stages: [DiseaseStage] = [.early, .moderate, .advanced]
            let weights = patientAge < 50 ? [40, 40, 20] : patientAge < 70 ? [30, 40, 30] : [20, 30, 50]
            return weightedRandomStageChoice(stages: stages, weights: weights)
        }
        
        // Neurological conditions with progression
        if diseaseName.contains("alzheimer") || diseaseName.contains("parkinson") ||
           diseaseName.contains("dementia") || diseaseName.contains("multiple sclerosis") {
            let stages: [DiseaseStage] = [.early, .moderate, .advanced]
            let weights = patientAge < 60 ? [50, 35, 15] : patientAge < 75 ? [30, 45, 25] : [20, 40, 40]
            return weightedRandomStageChoice(stages: stages, weights: weights)
        }
        
        // Cardiovascular conditions
        if category.contains("cardiovascular") || diseaseName.contains("heart") {
            let stages: [DiseaseStage] = [.early, .moderate, .advanced]
            let weights = patientAge < 45 ? [60, 30, 10] : patientAge < 65 ? [40, 40, 20] : [25, 45, 30]
            return weightedRandomStageChoice(stages: stages, weights: weights)
        }
        
        // Infectious diseases - usually acute
        if category.contains("infectious") || diseaseName.contains("infection") ||
           diseaseName.contains("pneumonia") || diseaseName.contains("sepsis") {
            return .acute
        }
        
        // Default to moderate stage
        return .moderate
    }
    
    private func weightedRandomStageChoice(stages: [DiseaseStage], weights: [Int]) -> DiseaseStage {
        let totalWeight = weights.reduce(0, +)
        let randomValue = Int.random(in: 0..<totalWeight)
        
        var currentWeight = 0
        for (index, weight) in weights.enumerated() {
            currentWeight += weight
            if randomValue < currentWeight {
                return stages[index]
            }
        }
        return stages.last!
    }
    
    private func adjustForDiseaseStage(symptoms: [Symptom], findings: [PhysicalFinding], stage: DiseaseStage) -> ([Symptom], [PhysicalFinding]) {
        var adjustedSymptoms = symptoms
        var adjustedFindings = findings
        
        switch stage {
        case .early:
            // Early stage: fewer symptoms, milder presentation
            adjustedSymptoms = Array(symptoms.prefix(max(1, symptoms.count / 2)))
            adjustedFindings = Array(findings.prefix(max(1, findings.count / 2)))
            
        case .moderate:
            // Moderate stage: typical presentation
            // Keep as is
            break
            
        case .advanced:
            // Advanced stage: more symptoms and findings
            adjustedSymptoms = symptoms // Show all symptoms
            adjustedFindings = findings // Show all findings
            
        case .acute:
            // Acute: intense presentation
            adjustedSymptoms = symptoms // Show all symptoms
            adjustedFindings = findings // Show all findings
            
        case .chronic:
            // Chronic: variable presentation, some symptoms may be adapted to
            let adaptedCount = max(1, symptoms.count - Int.random(in: 1...2))
            adjustedSymptoms = Array(symptoms.prefix(adaptedCount))
            
        case .remission:
            // Remission: minimal symptoms
            adjustedSymptoms = Array(symptoms.prefix(max(1, symptoms.count / 3)))
            adjustedFindings = Array(findings.prefix(max(0, findings.count / 3)))
        }
        
        return (adjustedSymptoms, adjustedFindings)
    }
    
    // MARK: - Data Management Methods
    
    func refreshData() {
        print("Refreshing database data...")
        hasLoadedOnce = false
        diseases = []
        patientCases = []
        loadingError = nil
        loadDiseases()
    }
    
    func forceUpdateDatabase() {
        print("Forcing database update with latest extracted data...")
        
        // Force the database manager to re-copy from bundle
        dbManager.forceCopyDatabase()
        
        // Clear and reload everything
        hasLoadedOnce = false
        diseases = []
        patientCases = []
        loadingError = nil
        loadDiseases()
    }
    
    func getDiseasesByCategory(_ category: String) -> [Disease] {
        return diseases.filter { $0.category == category }
    }
    
    func getAllCategories() -> [String] {
        let categories = Set(diseases.map { $0.category })
        return Array(categories).sorted()
    }
    
    func searchDiseases(query: String) -> [Disease] {
        if query.isEmpty {
            return diseases
        }
        
        return diseases.filter { disease in
            disease.nameEnglish.localizedCaseInsensitiveContains(query) ||
            disease.namePortuguese.localizedCaseInsensitiveContains(query) ||
            disease.category.localizedCaseInsensitiveContains(query) ||
            disease.symptoms.contains { symptom in
                symptom.symptomEnglish.localizedCaseInsensitiveContains(query) ||
                symptom.symptomPortuguese.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    // MARK: - Debug Methods
    
    func debugDatabaseConnection() {
        print("=== DATABASE DEBUG INFO ===")
        print("Diseases count: \(diseases.count)")
        print("Patient cases count: \(patientCases.count)")
        print("Has loaded once: \(hasLoadedOnce)")
        print("Is loading: \(isLoading)")
        print("Loading error: \(loadingError ?? "None")")
        
        if let firstDisease = diseases.first {
            print("\nFirst disease details:")
            print("  ID: \(firstDisease.id)")
            print("  English: \(firstDisease.nameEnglish)")
            print("  Portuguese: \(firstDisease.namePortuguese)")
            print("  Category: \(firstDisease.category)")
            print("  Symptoms: \(firstDisease.symptoms.count)")
            print("  Chief complaints: \(firstDisease.symptoms.filter { $0.isChiefComplaint }.count)")
            
            if let patientCase = getPatientCase(for: firstDisease) {
                print("  Patient case symptoms: \(patientCase.presentingSymptoms.count)")
                print("  Patient name: \(patientCase.demographics.name)")
            }
        }
        print("===========================")
    }
    
    // MARK: - Validation Methods
    
    func validateData() -> [String] {
        var issues: [String] = []
        
        if diseases.isEmpty {
            issues.append("No diseases loaded from database")
            return issues
        }
        
        for disease in diseases {
            // Check for empty names
            if disease.nameEnglish.isEmpty {
                issues.append("Disease ID \(disease.id) has empty English name")
            }
            if disease.namePortuguese.isEmpty {
                issues.append("Disease ID \(disease.id) has empty Portuguese name")
            }
            
            // Check for symptoms
            if disease.symptoms.isEmpty {
                issues.append("Disease '\(disease.nameEnglish)' has no symptoms")
            }
            
            // Check for chief complaints
            let chiefComplaints = disease.symptoms.filter { $0.isChiefComplaint }
            if chiefComplaints.isEmpty {
                issues.append("Disease '\(disease.nameEnglish)' has no chief complaints")
            }
            
            // Check for empty symptom text
            for symptom in disease.symptoms {
                if symptom.symptomEnglish.isEmpty || symptom.symptomPortuguese.isEmpty {
                    issues.append("Disease '\(disease.nameEnglish)' has symptoms with empty text")
                    break
                }
            }
        }
        
        // Check patient cases
        let casesWithoutSymptoms = patientCases.filter { $0.presentingSymptoms.isEmpty }
        if !casesWithoutSymptoms.isEmpty {
            issues.append("\(casesWithoutSymptoms.count) patient cases have no presenting symptoms")
        }
        
        return issues
    }
}

// MARK: - User Profile and Settings Models
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case portuguese = "pt-BR"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .portuguese: return "Português (Brasil)"
        }
    }
}

enum UserGender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female" 
    case preferNotToSay = "prefer_not_to_say"
    
    func displayName(language: AppLanguage) -> String {
        switch self {
        case .male:
            return language == .portuguese ? "Masculino" : "Male"
        case .female:
            return language == .portuguese ? "Feminino" : "Female"
        case .preferNotToSay:
            return language == .portuguese ? "Prefiro não dizer" : "Prefer not to say"
        }
    }
    
    var profileImageName: String {
        switch self {
        case .male:
            return "person.fill"
        case .female:
            return "person.dress"
        case .preferNotToSay:
            return "person.circle.fill"
        }
    }
}

struct UserProfile: Codable {
    var totalPatientsInterviewed: Int = 0
    var totalDiagnosesAttempted: Int = 0
    var totalCorrectDiagnoses: Int = 0
    var categoryPerformance: [String: CategoryStats] = [:]
    var dailyStats: [String: DayStats] = [:]
    var selectedLanguage: String = AppLanguage.english.rawValue
    var createdDate: Date = Date()
    var studyTime: TimeInterval = 0
    var hintsUsed: Int = 0
    var testsOrdered: Int = 0
    
    // New profile fields
    var userName: String = ""
    var userGender: UserGender = .preferNotToSay
    var isProfileSetupComplete: Bool = false
    var voiceInputEnabled: Bool = false
    
    // Enhanced Performance Analytics Fields
    var sessions: [SessionData] = []
    var weeklyProgress: [WeeklyProgress] = []
    var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    var learningInsights: [LearningInsight] = []
    var performanceTrends: [PerformanceTrend] = []
    var currentSessionData: SessionData?
    var overallDifficultLevel: DifficultLevel = .beginner
    
    var accuracyPercentage: Double {
        guard totalDiagnosesAttempted > 0 else { return 0 }
        return (Double(totalCorrectDiagnoses) / Double(totalDiagnosesAttempted)) * 100
    }
}

struct CategoryStats: Codable {
    var correct: Int = 0
    var incorrect: Int = 0
    var total: Int { correct + incorrect }
    var accuracy: Double {
        guard total > 0 else { return 0 }
        return (Double(correct) / Double(total)) * 100
    }
}

struct DayStats: Codable {
    var date: Date
    var patientsInterviewed: Int = 0
    var diagnosesAttempted: Int = 0
    var correctDiagnoses: Int = 0
    var studyTime: TimeInterval = 0
}

// MARK: - Enhanced Performance Analytics Structures

struct SessionData: Codable, Identifiable {
    var id = UUID()
    let startTime: Date
    var endTime: Date?
    var patientCaseId: String
    var diseaseCategory: String
    var difficulty: DifficultLevel
    var responseTimeSeconds: TimeInterval = 0
    var questionsAsked: Int = 0
    var hintsUsed: Int = 0
    var testsOrdered: Int = 0
    var finalDiagnosis: String = ""
    var isCorrect: Bool = false
    var confidenceScore: Double = 0.0 // 0.0-1.0
    var completionStatus: SessionStatus = .inProgress
    
    var duration: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime)
    }
}

enum SessionStatus: String, CaseIterable, Codable {
    case inProgress = "in_progress"
    case completed = "completed"
    case abandoned = "abandoned"
}

enum DifficultLevel: String, CaseIterable, Codable {
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

struct PerformanceMetrics: Codable {
    var averageResponseTime: TimeInterval = 0
    var averageQuestionsPerCase: Double = 0
    var averageConfidenceScore: Double = 0
    var diagnosticEfficiency: Double = 0 // Correct diagnoses per minute
    var improvementRate: Double = 0 // Week-over-week improvement
    var consistencyScore: Double = 0 // How consistent performance is
    var strongCategories: [String] = [] // Top performing categories
    var weakCategories: [String] = [] // Categories needing improvement
    var learningVelocity: Double = 0 // Rate of skill acquisition
    var retentionRate: Double = 0 // Knowledge retention over time
}

struct WeeklyProgress: Codable, Identifiable {
    var id = UUID()
    let weekStartDate: Date
    var totalSessions: Int = 0
    var averageAccuracy: Double = 0
    var averageResponseTime: TimeInterval = 0
    var studyTimeHours: Double = 0
    var difficultyCasesCompleted: [DifficultLevel: Int] = [:]
    var categoryBreakdown: [String: CategoryStats] = [:]
    var improvementFromLastWeek: Double = 0
    
    var weekEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
    }
}

struct LearningInsight: Codable, Identifiable {
    var id = UUID()
    let generatedDate: Date
    let insightType: InsightType
    let title: String
    let description: String
    let recommendation: String
    let priority: InsightPriority
    let relatedCategories: [String]
    var isViewed: Bool = false
    var isActionTaken: Bool = false
}

enum InsightType: String, CaseIterable, Codable {
    case performance = "performance"
    case learning = "learning"
    case efficiency = "efficiency"
    case knowledge = "knowledge"
    case behavior = "behavior"
    case performanceDecline = "performanceDecline"
    case questioningStrategy = "questioningStrategy"
    case learningVelocity = "learningVelocity"
}

enum InsightPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct PerformanceTrend: Codable {
    let metric: String
    let dataPoints: [TrendDataPoint]
    let trendDirection: TrendDirection
    let changePercentage: Double
}

struct TrendDataPoint: Codable {
    let date: Date
    let value: Double
}

enum TrendDirection: String, CaseIterable, Codable {
    case improving = "improving"
    case declining = "declining"
    case stable = "stable"
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        }
    }
}

// MARK: - User Profile Manager
class UserProfileManager: ObservableObject {
    @Published var profile = UserProfile()
    @Published var currentLanguage: AppLanguage = .english
    
    private let userDefaults = UserDefaults.standard
    private let profileKey = "UserProfile"
    
    init() {
        loadProfile()
        currentLanguage = AppLanguage(rawValue: self.profile.selectedLanguage) ?? .english
    }
    
    func saveProfile() {
        if let encoded = try? JSONEncoder().encode(self.profile) {
            userDefaults.set(encoded, forKey: profileKey)
        }
    }
    
    func loadProfile() {
        if let data = userDefaults.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded
        }
    }
    
    func recordDiagnosis(disease: Disease, isCorrect: Bool, questionCount: Int, hintsUsed: Int, testsOrdered: Int) {
        self.profile.totalPatientsInterviewed += 1
        self.profile.totalDiagnosesAttempted += 1
        self.profile.hintsUsed += hintsUsed
        self.profile.testsOrdered += testsOrdered
        
        if isCorrect {
            self.profile.totalCorrectDiagnoses += 1
        }
        
        var categoryStats = self.profile.categoryPerformance[disease.category] ?? CategoryStats()
        if isCorrect {
            categoryStats.correct += 1
        } else {
            categoryStats.incorrect += 1
        }
        self.profile.categoryPerformance[disease.category] = categoryStats
        
        saveProfile()
    }
    
    func changeLanguage(_ language: AppLanguage) {
        currentLanguage = language
        self.profile.selectedLanguage = language.rawValue
        saveProfile()
    }
    
    func addStudyTime(_ time: TimeInterval) {
        self.profile.studyTime += time
        saveProfile()
    }
    
    // MARK: - Session Management Methods
    func startNewSession(patientCase: PatientCase) {
        let sessionData = SessionData(
            startTime: Date(),
            patientCaseId: patientCase.disease.id.description,
            diseaseCategory: patientCase.disease.category,
            difficulty: determineDifficultyLevel(for: patientCase)
        )
        
        self.profile.currentSessionData = sessionData
    }
    
    private func determineDifficultyLevel(for patientCase: PatientCase) -> DifficultLevel {
        // Logic to determine difficulty based on case complexity
        let complexityFactors = [
            patientCase.presentingSymptoms.count,
            patientCase.availableLabResults.count,
            patientCase.availableHints.count
        ]
        
        let totalComplexity = complexityFactors.reduce(0, +)
        
        switch totalComplexity {
        case 0...3: return .beginner
        case 4...7: return .intermediate
        case 8...12: return .advanced
        default: return .expert
        }
    }
    
    func updateSessionProgress(questionsAsked: Int, hintsUsed: Int, testsOrdered: Int, responseTime: TimeInterval) {
        guard var currentSession = self.profile.currentSessionData else { return }
        
        currentSession.questionsAsked = questionsAsked
        currentSession.hintsUsed = hintsUsed
        currentSession.testsOrdered = testsOrdered
        currentSession.responseTimeSeconds = responseTime
        
        self.profile.currentSessionData = currentSession
    }
    
    func completeSession(finalDiagnosis: String, isCorrect: Bool, confidenceScore: Double) {
        guard var currentSession = self.profile.currentSessionData else { return }
        
        currentSession.endTime = Date()
        currentSession.finalDiagnosis = finalDiagnosis
        currentSession.isCorrect = isCorrect
        currentSession.confidenceScore = confidenceScore
        currentSession.completionStatus = .completed
        
        // Add to sessions history
        self.profile.sessions.append(currentSession)
        
        // Update overall metrics
        updatePerformanceMetrics()
        updateWeeklyProgress()
        generateLearningInsights()
        
        self.profile.currentSessionData = nil
        saveProfile()
    }
    
    func abandonSession() {
        guard var currentSession = self.profile.currentSessionData else { return }
        
        currentSession.endTime = Date()
        currentSession.completionStatus = .abandoned
        self.profile.sessions.append(currentSession)
        
        self.profile.currentSessionData = nil
        saveProfile()
    }
    
    private func updatePerformanceMetrics() {
        let completedSessions = self.profile.sessions.filter { $0.completionStatus == .completed }
        guard !completedSessions.isEmpty else { return }
        
        // Calculate average response time
        let totalResponseTime = completedSessions.reduce(0) { $0 + $1.responseTimeSeconds }
        self.profile.performanceMetrics.averageResponseTime = totalResponseTime / Double(completedSessions.count)
        
        // Calculate average questions per case
        let totalQuestions = completedSessions.reduce(0) { $0 + $1.questionsAsked }
        self.profile.performanceMetrics.averageQuestionsPerCase = Double(totalQuestions) / Double(completedSessions.count)
        
        // Calculate average confidence
        let totalConfidence = completedSessions.reduce(0) { $0 + $1.confidenceScore }
        self.profile.performanceMetrics.averageConfidenceScore = totalConfidence / Double(completedSessions.count)
        
        // Calculate diagnostic efficiency (correct diagnoses per minute)
        let correctSessions = completedSessions.filter { $0.isCorrect }
        let totalStudyTimeMinutes = completedSessions.reduce(0) { $0 + $1.duration } / 60.0
        self.profile.performanceMetrics.diagnosticEfficiency = totalStudyTimeMinutes > 0 ? Double(correctSessions.count) / totalStudyTimeMinutes : 0
        
        // Identify strong and weak categories
        updateCategoryStrengths()
        
        // Calculate learning velocity and consistency
        calculateAdvancedMetrics()
    }
    
    private func updateWeeklyProgress() {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current week's start date
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return }
        
        // Find or create current week's progress
        var currentWeek = self.profile.weeklyProgress.first { calendar.isDate($0.weekStartDate, inSameDayAs: weekStart) }
        
        if currentWeek == nil {
            currentWeek = WeeklyProgress(weekStartDate: weekStart)
        }
        
        // Update current week's data
        let weekSessions = self.profile.sessions.filter { session in
            calendar.isDate(session.startTime, equalTo: weekStart, toGranularity: .weekOfYear)
        }
        
        let completedWeekSessions = weekSessions.filter { $0.completionStatus == .completed }
        
        if var week = currentWeek {
            week.totalSessions = weekSessions.count
            // Break down complex calculations to avoid type-checking timeout
            if completedWeekSessions.isEmpty {
                week.averageAccuracy = 0
                week.averageResponseTime = 0
            } else {
                let correctCount = completedWeekSessions.filter { $0.isCorrect }.count
                week.averageAccuracy = Double(correctCount) / Double(completedWeekSessions.count)
                
                let totalResponseTime = completedWeekSessions.reduce(0) { $0 + $1.responseTimeSeconds }
                week.averageResponseTime = totalResponseTime / Double(completedWeekSessions.count)
            }
            
            let totalDuration = weekSessions.reduce(0) { $0 + $1.duration }
            week.studyTimeHours = totalDuration / 3600.0
            
            for session in completedWeekSessions {
                week.difficultyCasesCompleted[session.difficulty, default: 0] += 1
            }
            
            // Update or add to weekly progress
            if let index = self.profile.weeklyProgress.firstIndex(where: { calendar.isDate($0.weekStartDate, inSameDayAs: weekStart) }) {
                self.profile.weeklyProgress[index] = week
            } else {
                self.profile.weeklyProgress.append(week)
            }
        }
        
        // Keep only last 12 weeks
        self.profile.weeklyProgress = self.profile.weeklyProgress.suffix(12)
    }
    
    private func generateLearningInsights() {
        var newInsights: [LearningInsight] = []
        
        // Insight 1: Performance decline detection
        if self.profile.performanceMetrics.improvementRate < -0.1 {
            newInsights.append(
                LearningInsight(
                    generatedDate: Date(),
                    insightType: .performanceDecline,
                    title: "Performance Decline Detected",
                    description: "Your diagnostic accuracy has decreased recently. Consider reviewing fundamental concepts.",
                    recommendation: "Focus on your weak categories and take more time with each case.",
                    priority: .high,
                    relatedCategories: self.profile.performanceMetrics.weakCategories
                )
            )
        }
        
        // Insight 2: Question efficiency
        if self.profile.performanceMetrics.averageQuestionsPerCase > 15 {
            newInsights.append(
                LearningInsight(
                    generatedDate: Date(),
                    insightType: .questioningStrategy,
                    title: "Consider More Focused Questioning",
                    description: "You're asking many questions per case. Try to focus on key diagnostic indicators.",
                    recommendation: "Practice systematic approaches: chief complaint → associated symptoms → physical exam → targeted tests.",
                    priority: .medium,
                    relatedCategories: []
                )
            )
        }
        
        // Insight 3: Learning velocity (positive feedback)
        if self.profile.sessions.count >= 10 && self.profile.performanceMetrics.learningVelocity > 0.8 {
            newInsights.append(
                LearningInsight(
                    generatedDate: Date(),
                    insightType: .learningVelocity,
                    title: "Excellent Learning Progress!",
                    description: "You're showing strong improvement across multiple categories.",
                    recommendation: "Consider challenging yourself with more complex cases in your strong areas.",
                    priority: .medium,
                    relatedCategories: self.profile.performanceMetrics.strongCategories
                )
            )
        }
        
        // Add new insights and maintain reasonable list size
        self.profile.learningInsights.append(contentsOf: newInsights)
        self.profile.learningInsights = self.profile.learningInsights.suffix(10) // Keep only last 10 insights
    }
    
    private func updateCategoryStrengths() {
        var categoryPerformance: [String: (correct: Int, total: Int)] = [:]
        
        let completedSessions = self.profile.sessions.filter { $0.completionStatus == .completed }
        for session in completedSessions {
            let category = session.diseaseCategory
            let current = categoryPerformance[category] ?? (correct: 0, total: 0)
            categoryPerformance[category] = (
                correct: current.correct + (session.isCorrect ? 1 : 0),
                total: current.total + 1
            )
        }
        
        // Sort categories by accuracy
        let sortedCategories = categoryPerformance.sorted { first, second in
            let firstAccuracy = Double(first.value.correct) / Double(first.value.total)
            let secondAccuracy = Double(second.value.correct) / Double(second.value.total)
            return firstAccuracy > secondAccuracy
        }
        
        // Update strong/weak categories
        let topCategories = Array(sortedCategories.prefix(3))
        let bottomCategories = Array(sortedCategories.suffix(3))
        
        self.profile.performanceMetrics.strongCategories = topCategories.map { $0.key }
        self.profile.performanceMetrics.weakCategories = bottomCategories.map { $0.key }
    }
    
    private func calculateAdvancedMetrics() {
        let recentSessions = self.profile.sessions.suffix(20) // Last 20 sessions
        guard recentSessions.count >= 5 else { return }
        
        // Calculate consistency score (how consistent performance is)
        let accuracyScores = recentSessions.map { $0.isCorrect ? 1.0 : 0.0 }
        let meanAccuracy = accuracyScores.reduce(0, +) / Double(accuracyScores.count)
        
        // Calculate variance in smaller steps to avoid type-checking timeout
        let squaredDeviations = accuracyScores.map { pow($0 - meanAccuracy, 2) }
        let variance = squaredDeviations.reduce(0, +) / Double(accuracyScores.count)
        self.profile.performanceMetrics.consistencyScore = max(0, 1 - variance) // Higher score = more consistent
        
        // Calculate improvement rate (comparing first half vs second half of recent sessions)
        let firstHalf = Array(recentSessions.prefix(recentSessions.count / 2))
        let secondHalf = Array(recentSessions.suffix(recentSessions.count / 2))
        
        let firstHalfAccuracy = firstHalf.filter { $0.isCorrect }.count
        let secondHalfAccuracy = secondHalf.filter { $0.isCorrect }.count
        
        let firstHalfRate = Double(firstHalfAccuracy) / Double(firstHalf.count)
        let secondHalfRate = Double(secondHalfAccuracy) / Double(secondHalf.count)
        
        self.profile.performanceMetrics.improvementRate = secondHalfRate - firstHalfRate
    }
}

// MARK: - Conversation Models
struct ConversationTurn: Identifiable {
    var id = UUID()
    let question: String
    let response: String
    let timestamp: Date
    let isTest: Bool
}

struct DiagnosisResult {
    let userDiagnosis: String
    let isCorrect: Bool
    let conversationTurns: Int
    let patientName: String
    let hintsUsed: Int
    let testsOrdered: Int
    let feedback: String
}

// MARK: - Updated Claude AI Service (uses APIKeyManager)
class ClaudeAIService: ObservableObject {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    @Published var isGeneratingResponse = false
    @Published var lastError: String?
    
    // UPDATED: Remove hardcoded API key
    init() {
        // No longer need hardcoded API key
    }
    
    func generatePatientResponse(
        question: String,
        patientCase: PatientCase,
        conversationHistory: [ConversationTurn],
        language: AppLanguage
    ) async -> String {
        
        // Get API key dynamically from APIKeyManager
        guard let apiKey = APIKeyManager.shared.getAPIKey() else {
            await MainActor.run {
                lastError = "No API key configured. Please set up your Claude API key."
            }
            return getFallbackResponse(question: question, patientCase: patientCase, language: language)
        }
        
        await MainActor.run {
            isGeneratingResponse = true
        }
        
        defer {
            Task { @MainActor in
                isGeneratingResponse = false
            }
        }
        
        let systemPrompt = createPatientSystemPrompt(patientCase: patientCase, language: language)
        
        let conversationContext = conversationHistory.filter { !$0.isTest }.map { turn in
            "Doctor: \(turn.question)\nPatient: \(turn.response)"
        }.joined(separator: "\n\n")
        
        let fullPrompt = """
        \(systemPrompt)
        
        Previous conversation:
        \(conversationContext)
        
        Doctor: \(question)
        
        Patient:
        """
        
        do {
            let response = try await makeAPIRequest(prompt: fullPrompt, apiKey: apiKey)
            return response
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            return getFallbackResponse(question: question, patientCase: patientCase, language: language)
        }
    }
    
    func generateTestResult(
        testRequest: String,
        patientCase: PatientCase,
        language: AppLanguage
    ) async -> String {
        
        guard let apiKey = APIKeyManager.shared.getAPIKey() else {
            return getTestFallbackResponse(testRequest: testRequest, patientCase: patientCase, language: language)
        }
        
        await MainActor.run {
            isGeneratingResponse = true
        }
        
        defer {
            Task { @MainActor in
                isGeneratingResponse = false
            }
        }
        
        let systemPrompt = createTestSystemPrompt(patientCase: patientCase, language: language)
        
        let fullPrompt = """
        \(systemPrompt)
        
        Test requested: \(testRequest)
        
        Test result:
        """
        
        do {
            let response = try await makeAPIRequest(prompt: fullPrompt, apiKey: apiKey)
            return response
        } catch {
            return getTestFallbackResponse(testRequest: testRequest, patientCase: patientCase, language: language)
        }
    }
    
    private func createPatientSystemPrompt(patientCase: PatientCase, language: AppLanguage) -> String {
        let demographics = patientCase.demographics
        let disease = patientCase.disease
        let personality = patientCase.personality
        let symptoms = patientCase.presentingSymptoms.map { $0.getText(language) }.joined(separator: ", ")
        
        // Get personality-specific behavior modifiers
        let personalityContext = personality.getPersonalityPromptModifier(language: language)
        
        // Pre-calculate complex expressions to avoid type-checking timeout
        let personalityTypeDisplay = personality.type.displayName(language: language)
        let communicationStyleModifier = personality.communicationStyle.modifier(language: language)
        let cooperationPercent = Int(personality.cooperationLevel * 100)
        let painTolerancePercent = Int(personality.painTolerance * 100)
        let anxietyPercent = Int(personality.anxietyLevel * 100)
        let trustPercent = Int(personality.trustLevel * 100)
        let memoryPercent = Int(personality.memoryClarity * 100)
        
        if language == .portuguese {
            return """
            \(personalityContext)
            
            INFORMAÇÕES DO PACIENTE:
            Nome: \(demographics.name)
            Idade: \(demographics.age) anos
            Gênero: \(demographics.gender)
            
            INFORMAÇÕES MÉDICAS:
            CONDIÇÃO MÉDICA: \(disease.namePortuguese)
            SINTOMAS ATUAIS: \(symptoms)
            CATEGORIA: \(disease.category)
            SEVERIDADE: \(disease.severity)
            
            MODIFICADORES DE PERSONALIDADE:
            - Tipo de personalidade: \(personalityTypeDisplay)
            - Estilo de comunicação: \(communicationStyleModifier)
            - Nível de cooperação: \(cooperationPercent)%
            - Tolerância à dor: \(painTolerancePercent)%
            - Nível de ansiedade: \(anxietyPercent)%
            - Nível de confiança: \(trustPercent)%
            - Clareza da memória: \(memoryPercent)%
            
            INSTRUÇÕES IMPORTANTES:
            - Responda APENAS como o paciente em português brasileiro
            - Você NÃO sabe o nome da sua condição médica - você só sabe os sintomas
            - Seja realista sobre seus sintomas e como se sente
            - Responda de acordo com sua PERSONALIDADE específica
            - Se sua cooperação é baixa, seja mais relutante em responder certas perguntas
            - Se sua ansiedade é alta, demonstre preocupação e faça perguntas sobre os sintomas
            - Se sua tolerância à dor é baixa, dramatize mais o desconforto
            - Se sua memória é ruim, tenha dificuldade em lembrar detalhes específicos
            - Use linguagem simples, não termos médicos técnicos
            - Se perguntado sobre diagnóstico, diga que não sabe, só sabe como se sente
            - Seja consistente com sintomas já mencionados
            - Responda como uma pessoa real que está sofrendo com estes sintomas
            - Mantenha as respostas concisas (1-3 frases)
            """
        } else {
            return """
            \(personalityContext)
            
            PATIENT INFORMATION:
            Name: \(demographics.name)
            Age: \(demographics.age) years old
            Gender: \(demographics.gender)
            
            MEDICAL INFORMATION:
            MEDICAL CONDITION: \(disease.nameEnglish)
            CURRENT SYMPTOMS: \(symptoms)
            CATEGORY: \(disease.category)
            SEVERITY: \(disease.severity)
            
            PERSONALITY MODIFIERS:
            - Personality type: \(personalityTypeDisplay)
            - Communication style: \(communicationStyleModifier)
            - Cooperation level: \(cooperationPercent)%
            - Pain tolerance: \(painTolerancePercent)%
            - Anxiety level: \(anxietyPercent)%
            - Trust level: \(trustPercent)%
            - Memory clarity: \(memoryPercent)%
            
            IMPORTANT INSTRUCTIONS:
            - Respond ONLY as the patient in English
            - You do NOT know the name of your medical condition - you only know your symptoms
            - Be realistic about your symptoms and how you feel
            - Respond according to your specific PERSONALITY traits
            - If your cooperation is low, be more reluctant to answer certain questions
            - If your anxiety is high, show worry and ask questions about your symptoms
            - If your pain tolerance is low, dramatize discomfort more
            - If your memory is poor, have difficulty remembering specific details
            - Use simple language, not technical medical terms
            - If asked about diagnosis, say you don't know, you just know how you feel
            - Be consistent with symptoms already mentioned
            - Respond as a real person who is suffering from these symptoms
            - Keep responses concise (1-3 sentences)
            """
        }
    }
    
    private func createTestSystemPrompt(patientCase: PatientCase, language: AppLanguage) -> String {
        let demographics = patientCase.demographics
        let findings = patientCase.presentingFindings.map { $0.getText(language) }.joined(separator: ", ")
        let labResults = patientCase.availableLabResults.map { $0.getText(language) }.joined(separator: ", ")
        
        if language == .portuguese {
            return """
            Você é um sistema médico fornecendo resultados de exames para um paciente de \(demographics.age) anos.
            
            ACHADOS FÍSICOS DISPONÍVEIS: \(findings)
            RESULTADOS LABORATORIAIS: \(labResults)
            
            Forneça APENAS os resultados objetivos do exame em português brasileiro.
            NÃO mencione possíveis diagnósticos ou interpretações.
            NÃO diga "consistente com" ou "sugere" qualquer condição.
            Apenas relate os achados clínicos objetivos.
            Mantenha as respostas concisas e clínicas.
            """
        } else {
            return """
            You are a medical system providing test results for a \(demographics.age)-year-old patient.
            
            PHYSICAL EXAM FINDINGS: \(findings)
            LAB RESULTS: \(labResults)
            
            Provide ONLY objective test results in English.
            DO NOT mention possible diagnoses or interpretations.
            DO NOT say "consistent with" or "suggests" any condition.
            Only report objective clinical findings.
            Keep responses concise and clinical.
            """
        }
    }
    
    private func makeAPIRequest(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 150,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid response", code: 0, userInfo: nil)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                throw NSError(domain: "Unauthorized", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please check your API key."])
            }
            throw NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: nil)
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = jsonResponse["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw NSError(domain: "Failed to parse response", code: 0, userInfo: nil)
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func generateHint(
        patientCase: PatientCase,
        conversationHistory: [ConversationTurn],
        language: AppLanguage
    ) async -> String {
        
        let hints = patientCase.availableHints.map { $0.getText(language) }
        let randomHint = hints.randomElement() ?? (language == .portuguese ? "Considere fazer mais perguntas sobre os sintomas." : "Consider asking more questions about the symptoms.")
        
        return randomHint
    }
    
    private func getFallbackResponse(question: String, patientCase: PatientCase, language: AppLanguage) -> String {
        let lowercaseQuestion = question.lowercased()
        let symptoms = patientCase.presentingSymptoms.map { $0.getText(language) }
        
        if language == .portuguese {
            if lowercaseQuestion.contains("sentindo") || lowercaseQuestion.contains("como está") {
                return "Não estou me sentindo bem. Tenho \(symptoms.first ?? "sintomas desconfortáveis")."
            }
            if lowercaseQuestion.contains("dor") {
                return "Sim, estou sentindo dor. É bem desconfortável."
            }
            if lowercaseQuestion.contains("quando") {
                return "Os sintomas começaram há alguns dias e estão piorando."
            }
            return "Estou sentindo \(symptoms.randomElement() ?? "sintomas estranhos")."
        } else {
            if lowercaseQuestion.contains("feel") || lowercaseQuestion.contains("how") {
                return "I'm not feeling well at all. I have \(symptoms.first ?? "uncomfortable symptoms")."
            }
            if lowercaseQuestion.contains("pain") {
                return "Yes, I'm experiencing pain. It's quite uncomfortable."
            }
            if lowercaseQuestion.contains("when") {
                return "The symptoms started a few days ago and they're getting worse."
            }
            return "I'm experiencing \(symptoms.randomElement() ?? "strange symptoms")."
        }
    }
    
    private func getTestFallbackResponse(testRequest: String, patientCase: PatientCase, language: AppLanguage) -> String {
        let lowercaseTest = testRequest.lowercased()
        let labResults = patientCase.availableLabResults.map { $0.getText(language) }
        
        if language == .portuguese {
            if lowercaseTest.contains("pressão") {
                return "Pressão arterial: 120/80 mmHg"
            }
            if lowercaseTest.contains("temperatura") {
                let hasFevor = patientCase.presentingSymptoms.contains { $0.getText(.portuguese).contains("Febre") }
                return hasFevor ? "Temperatura: 38.2°C" : "Temperatura: 36.8°C"
            }
            if lowercaseTest.contains("reflexo") {
                return "Reflexos normais e simétricos"
            }
            return labResults.randomElement() ?? "Resultado do exame dentro dos parâmetros esperados para esta condição."
        } else {
            if lowercaseTest.contains("blood pressure") {
                return "Blood pressure: 120/80 mmHg"
            }
            if lowercaseTest.contains("temperature") {
                let hasFevor = patientCase.presentingSymptoms.contains { $0.getText(.english).contains("Fever") }
                return hasFevor ? "Temperature: 101.0°F" : "Temperature: 98.6°F"
            }
            if lowercaseTest.contains("reflex") {
                return "Reflexes normal and symmetric"
            }
            return labResults.randomElement() ?? "Test results within expected parameters for this condition."
        }
    }
}

// MARK: - Updated Main App to integrate with API Key system
@main
struct MedicalDiagnosisApp: App {
    @StateObject private var userProfile = UserProfileManager()
    
    var body: some Scene {
        WindowGroup {
            if !UserDefaults.standard.bool(forKey: "hasSelectedLanguage") {
                LanguageSelectionView()
                    .environmentObject(userProfile)
            } else {
                // CHANGE: Use MainAppWrapper instead of ContentView directly
                MainAppWrapper()
                    .environmentObject(userProfile)
            }
        }
    }
}

// MARK: - Language Selection View
struct LanguageSelectionView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Medical Training App")
                    .font(.largeTitle)
                    .bold()
                
                Text("App de Treinamento Médico")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 20) {
                Text("Choose your language / Escolha seu idioma")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    Button(action: {
                        userProfile.changeLanguage(.english)
                        UserDefaults.standard.set(true, forKey: "hasSelectedLanguage")
                    }) {
                        HStack {
                            Text("🇺🇸")
                                .font(.title)
                            Text("English")
                                .font(.title2)
                                .bold()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                    }
                    
                    Button(action: {
                        userProfile.changeLanguage(.portuguese)
                        UserDefaults.standard.set(true, forKey: "hasSelectedLanguage")
                    }) {
                        HStack {
                            Text("🇧🇷")
                                .font(.title)
                            Text("Português (Brasil)")
                                .font(.title2)
                                .bold()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(15)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var dataManager = MedicalDatabaseManager()
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var progressTracker = ProgressTracker.shared
    @StateObject private var uxManager = UXEnhancementManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingProfile = false
    @State private var showingAnalytics = false
    @State private var showingProgress = false
    @State private var showingNotificationSettings = false
    @State private var showingSocialHub = false
    @State private var showingThemeSettings = false
    @State private var showingStudyTools = false

    // Smart Search Features
    @State private var recentSearches: [String] = []
    @State private var showingSuggestions = false
    @State private var favoriteConditions: [String] = []
    @State private var showingFavorites = false
    @State private var searchHistory: [String] = []

    // Session Tracking
    @State private var sessionStartTime = Date()
    @State private var questionsAsked = 0
    @State private var sessionTime: TimeInterval = 0
    
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
        var baseDiseases = showingFavorites ? favoriteFilteredDiseases : dataManager.diseases

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
                    // Progress Summary Bar
                    HStack {
                        // Daily streak indicator
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(progressTracker.currentStreak)")
                                .font(.caption)
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
                                .font(.caption)
                            Text("\(progressTracker.todayProgress.sessionsCompleted)")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)

                        Spacer()

                        // Progress button with haptic feedback
                        HapticButton(
                            action: {
                                showingProgress = true
                            },
                            hapticStyle: .light
                        ) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text(userProfile.currentLanguage == .portuguese ? "Progresso" : "Progress")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)

                    // Quick Actions Row
                    HStack {
                        HapticButton(
                            action: {
                                showingFavorites.toggle()
                            },
                            hapticStyle: .selection
                        ) {
                            HStack {
                                Image(systemName: showingFavorites ? "heart.fill" : "heart")
                                    .foregroundColor(showingFavorites ? .red : .secondary)
                                Text(userProfile.currentLanguage == .portuguese ? "Favoritos" : "Favorites")
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                        }

                        Spacer()

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
                            HStack {
                                Image(systemName: "dice")
                                Text(userProfile.currentLanguage == .portuguese ? "Aleatório" : "Random")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)

                    // Search Bar
                    VStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)

                            TextField(userProfile.currentLanguage == .portuguese ? "Buscar condições..." : "Search conditions...", text: $searchText)
                                .textFieldStyle(.plain)
                                .onChange(of: searchText) { _ in
                                    showingSuggestions = !searchText.isEmpty && searchText.count >= 2
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
                                                .font(.caption)
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
                                        .font(.caption)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
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
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Debug Info (remove in production)
                if dataManager.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading medical database...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let error = dataManager.loadingError {
                    VStack {
                        Text("Database Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            dataManager.refreshData()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else {
                    // Debug info showing database status
                    VStack {
                        Text("Database: \(dataManager.diseases.count) conditions loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if dataManager.diseases.count < 400 {
                            Button("Update Database (Load 447 conditions)") {
                                dataManager.forceUpdateDatabase()
                            }
                            .font(.caption)
                            .padding(8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Diseases List
                List(filteredDiseases) { disease in
                    NavigationLink(destination: PatientSimulationView(disease: disease)
                        .environmentObject(dataManager)) {
                        HStack {
                            PatientRowView(disease: disease, language: userProfile.currentLanguage)
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
                        }
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
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        ConnectionStatusIndicator(language: userProfile.currentLanguage)

                        Button(action: {
                            showingSocialHub = true
                        }) {
                            Image(systemName: "person.3.fill")
                                .font(.title2)
                        }

                        Button(action: {
                            showingNotificationSettings = true
                        }) {
                            Image(systemName: "bell")
                                .font(.title2)
                        }

                        Button(action: {
                            showingAnalytics = true
                        }) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.title2)
                        }
                        Button(action: {
                            showingThemeSettings = true
                        }) {
                            Image(systemName: "paintbrush.fill")
                                .font(.title2)
                        }
                        Button(action: {
                            showingStudyTools = true
                        }) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.title2)
                        }

                        FeedbackButton(language: userProfile.currentLanguage)

                        NavigationLink(destination: APIKeySettingsView(language: userProfile.currentLanguage)) {
                            Image(systemName: "gearshape")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                UserProfileView()
                    .environmentObject(userProfile)
            }
            .sheet(isPresented: $showingAnalytics) {
                CleanAnalyticsView()
                    .environmentObject(userProfile)
            }
            .sheet(isPresented: $showingProgress) {
                ProgressDashboardView()
                    .environmentObject(userProfile)
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
                    .environmentObject(userProfile)
            }
            .sheet(isPresented: $showingSocialHub) {
                SocialHubView()
                    .environmentObject(userProfile)
            }
            .sheet(isPresented: $showingThemeSettings) {
                ThemeSettingsView()
                    .environmentObject(userProfile)
            }
            .sheet(isPresented: $showingStudyTools) {
                StudyToolsView()
                    .environmentObject(userProfile)
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
    @EnvironmentObject var dataManager: MedicalDatabaseManager
    @StateObject private var studyToolsManager = StudyToolsManager.shared
    
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
        VStack(alignment: .leading, spacing: 8) {
            if let patientCase = dataManager.getPatientCase(for: disease) {
                Text("\(patientCase.demographics.name)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(language == .portuguese ? "Queixa Principal:" : "Chief Complaint:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let chiefComplaints = patientCase.presentingSymptoms.filter { $0.isChiefComplaint }
                    
                    if chiefComplaints.isEmpty {
                        // Debug: Show that we have no chief complaints
                        Text("No chief complaints found")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        // Fallback: Show any symptoms
                        ForEach(patientCase.presentingSymptoms.prefix(2), id: \.id) { symptom in
                            Text("• \(symptom.getText(language)) (Not Chief)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else {
                        ForEach(chiefComplaints, id: \.id) { symptom in
                            Text("• \(symptom.getText(language))")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Debug info
                    Text("Debug: \(patientCase.presentingSymptoms.count) symptoms, \(chiefComplaints.count) chief")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(translateMedicalCategory(disease.category, to: language))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.2))
                        .foregroundColor(categoryColor)
                        .cornerRadius(8)
                    
                    Spacer()

                    Button(action: {
                        studyToolsManager.toggleBookmark(for: disease.nameEnglish)
                    }) {
                        Image(systemName: studyToolsManager.isBookmarked(disease.nameEnglish) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(studyToolsManager.isBookmarked(disease.nameEnglish) ? .blue : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text(language == .portuguese ? "Desafio Diagnóstico" : "Diagnostic Challenge")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
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
        .padding(.vertical, 4)
    }
}

// MARK: - User Profile View
struct UserProfileView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        Image(systemName: userProfile.profile.userGender == .preferNotToSay ? 
                              "person.circle.fill" : "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(userProfile.profile.userGender == .female ? .pink : .blue)
                        
                        Text(userProfile.profile.userName.isEmpty ? 
                             (userProfile.currentLanguage == .portuguese ? "Perfil" : "Profile") :
                             userProfile.profile.userName)
                            .font(.largeTitle)
                            .bold()
                        
                        if !userProfile.profile.userName.isEmpty {
                            Text(userProfile.profile.userGender.displayName(language: userProfile.currentLanguage))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Profile Information
                    if !userProfile.profile.userName.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(userProfile.currentLanguage == .portuguese ? "Informações do Perfil" : "Profile Information")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text(userProfile.currentLanguage == .portuguese ? "Nome:" : "Name:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(userProfile.profile.userName)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text(userProfile.currentLanguage == .portuguese ? "Gênero:" : "Gender:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(userProfile.profile.userGender.displayName(language: userProfile.currentLanguage))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text(userProfile.currentLanguage == .portuguese ? "Entrada de Voz:" : "Voice Input:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(userProfile.profile.voiceInputEnabled ? 
                                         (userProfile.currentLanguage == .portuguese ? "Ativado" : "Enabled") :
                                         (userProfile.currentLanguage == .portuguese ? "Desativado" : "Disabled"))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Language Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text(userProfile.currentLanguage == .portuguese ? "Configurações" : "Settings")
                            .font(.headline)
                        
                        HStack {
                            Text(userProfile.currentLanguage == .portuguese ? "Idioma:" : "Language:")
                            Spacer()
                            Picker("Language", selection: Binding(
                                get: { userProfile.currentLanguage },
                                set: { userProfile.changeLanguage($0) }
                            )) {
                                ForEach(AppLanguage.allCases, id: \.self) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        Text(userProfile.currentLanguage == .portuguese ? "Estatísticas" : "Statistics")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Pacientes Entrevistados" : "Patients Interviewed",
                                value: "\(userProfile.profile.totalPatientsInterviewed)",
                                color: .blue
                            )
                            
                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Diagnósticos Tentados" : "Diagnoses Attempted",
                                value: "\(userProfile.profile.totalDiagnosesAttempted)",
                                color: .orange
                            )
                            
                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Precisão Total" : "Total Accuracy",
                                value: String(format: "%.1f%%", userProfile.profile.accuracyPercentage),
                                color: userProfile.profile.accuracyPercentage >= 70 ? .green : .orange
                            )
                            
                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Dicas Usadas" : "Hints Used",
                                value: "\(userProfile.profile.hintsUsed)",
                                color: .yellow
                            )
                            
                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Exames Solicitados" : "Tests Ordered",
                                value: "\(userProfile.profile.testsOrdered)",
                                color: .purple
                            )
                            
                            ProfileStatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Tempo de Estudo" : "Study Time",
                                value: formatStudyTime(userProfile.profile.studyTime),
                                color: .green
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(userProfile.currentLanguage == .portuguese ? "Perfil" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    FeedbackButton(language: userProfile.currentLanguage)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !userProfile.profile.userName.isEmpty {
                            Button(userProfile.currentLanguage == .portuguese ? "Editar" : "Edit") {
                                // Reset profile setup to allow editing
                                userProfile.profile.isProfileSetupComplete = false
                                userProfile.saveProfile()
                                dismiss()
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Button(userProfile.currentLanguage == .portuguese ? "Concluído" : "Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func formatStudyTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Helper Views
struct ProfileStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .bold()
                    .foregroundColor(color)
            }
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Performance Analytics Visualization Components

struct PerformanceChartView: View {
    let weeklyProgress: [WeeklyProgress]
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Progresso Semanal" : "Weekly Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            if weeklyProgress.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text(language == .portuguese ? 
                         "Complete mais sessões para ver seu progresso" :
                         "Complete more sessions to see your progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(weeklyProgress) { week in
                            WeekProgressBar(
                                week: week,
                                language: language
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeekProgressBar: View {
    let week: WeeklyProgress
    let language: AppLanguage
    
    private var weekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(weekFormatter.string(from: week.weekStartDate))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accuracyColor)
                    .frame(width: 20, height: max(4, week.averageAccuracy * 1.5))
                
                Text("\(Int(week.averageAccuracy))%")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(height: 150, alignment: .bottom)
            
            Text("\(week.totalSessions)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var accuracyColor: Color {
        switch week.averageAccuracy {
        case 80...100: return .green
        case 60...79: return .blue
        case 40...59: return .orange
        default: return .red
        }
    }
}

struct MetricsOverviewView: View {
    let metrics: PerformanceMetrics
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Métricas Detalhadas" : "Detailed Metrics")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: language == .portuguese ? "Tempo Médio" : "Avg Response",
                    value: formatTime(metrics.averageResponseTime),
                    icon: "clock",
                    color: .blue
                )
                
                MetricCard(
                    title: language == .portuguese ? "Perguntas/Caso" : "Questions/Case",
                    value: String(format: "%.1f", metrics.averageQuestionsPerCase),
                    icon: "questionmark.circle",
                    color: .orange
                )
                
                MetricCard(
                    title: language == .portuguese ? "Confiança" : "Confidence",
                    value: String(format: "%.0f%%", metrics.averageConfidenceScore * 100),
                    icon: "gauge",
                    color: .green
                )
                
                MetricCard(
                    title: language == .portuguese ? "Consistência" : "Consistency",
                    value: String(format: "%.0f%%", metrics.consistencyScore * 100),
                    icon: "chart.line.flattrend.xyaxis",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        if timeInterval < 60 {
            return String(format: "%.0fs", timeInterval)
        } else {
            let minutes = Int(timeInterval / 60)
            let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct CategoryPerformanceView: View {
    let categoryStats: [String: CategoryStats]
    let strongCategories: [String]
    let weakCategories: [String]
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Performance por Categoria" : "Performance by Category")
                .font(.headline)
            
            if categoryStats.isEmpty {
                Text(language == .portuguese ? 
                     "Complete mais casos para ver a análise por categoria" :
                     "Complete more cases to see category analysis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    if !strongCategories.isEmpty {
                        CategorySection(
                            title: language == .portuguese ? "Pontos Fortes" : "Strong Areas",
                            categories: strongCategories,
                            categoryStats: categoryStats,
                            color: .green,
                            icon: "checkmark.circle.fill"
                        )
                    }
                    
                    if !weakCategories.isEmpty {
                        CategorySection(
                            title: language == .portuguese ? "Áreas a Melhorar" : "Areas to Improve",
                            categories: weakCategories,
                            categoryStats: categoryStats,
                            color: .orange,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CategorySection: View {
    let title: String
    let categories: [String]
    let categoryStats: [String: CategoryStats]
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .bold()
            }
            
            VStack(spacing: 4) {
                ForEach(categories, id: \.self) { category in
                    if let stats = categoryStats[category] {
                        HStack {
                            Text(category)
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f%%", stats.accuracy))
                                .font(.caption)
                                .bold()
                                .foregroundColor(color)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct LearningInsightsView: View {
    let insights: [LearningInsight]
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Insights de Aprendizado" : "Learning Insights")
                .font(.headline)
            
            if insights.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    
                    Text(language == .portuguese ? 
                         "Complete mais sessões para receber insights personalizados" :
                         "Complete more sessions to receive personalized insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(insights.prefix(3)) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InsightCard: View {
    let insight: LearningInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(insight.priority.color)
                    .frame(width: 8, height: 8)
                
                Text(insight.title)
                    .font(.subheadline)
                    .bold()
                
                Spacer()
                
                Text(insightTypeIcon)
                    .font(.caption)
            }
            
            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(insight.recommendation)
                .font(.caption)
                .italic()
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private var insightTypeIcon: String {
        switch insight.insightType {
        case .performance: return "📊"
        case .learning: return "🧠"
        case .efficiency: return "⚡"
        case .knowledge: return "📚"
        case .behavior: return "🎯"
        case .performanceDecline: return "📉"
        case .questioningStrategy: return "❓"
        case .learningVelocity: return "🚀"
        }
    }
}

// MARK: - Enhanced Analytics Dashboard

struct AnalyticsDashboardView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @State private var selectedTab = 0
    @State private var timeRange: TimeRange = .month
    
    private let tabsData: [(titleEN: String, titlePT: String, icon: String)] = [
        (titleEN: "Overview", titlePT: "Visão Geral", icon: "chart.bar"),
        (titleEN: "Progress", titlePT: "Progresso", icon: "chart.line.uptrend.xyaxis"),
        (titleEN: "Insights", titlePT: "Insights", icon: "lightbulb")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time Range Selector
                timeRangeSelector
                
                // Tab Selection
                tabSelector
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedTab {
                        case 0:
                            overviewContent
                        case 1:
                            progressContent
                        case 2:
                            insightsContent
                        default:
                            overviewContent
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(userProfile.currentLanguage == .portuguese ? "Análise Detalhada" : "Detailed Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var timeRangeSelector: some View {
        HStack {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    timeRange = range
                }) {
                    Text(range.displayName(language: userProfile.currentLanguage))
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(timeRange == range ? Color.blue : Color.clear)
                        .foregroundColor(timeRange == range ? .white : .blue)
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var tabSelector: some View {
        HStack {
            ForEach(0..<3) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabsData[index].icon)
                            .font(.title2)
                        Text(userProfile.currentLanguage == .portuguese ? 
                             getPortugueseTabTitle(index) : 
                             getEnglishTabTitle(index))
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == index ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    private func getEnglishTabTitle(_ index: Int) -> String {
        guard index < tabsData.count else { return "Overview" }
        return tabsData[index].titleEN
    }
    
    private func getPortugueseTabTitle(_ index: Int) -> String {
        guard index < tabsData.count else { return "Visão Geral" }
        return tabsData[index].titlePT
    }
    
    @ViewBuilder
    private var overviewContent: some View {
        // Current Performance Summary
        PerformanceSummaryCard(
            profile: userProfile.profile,
            language: userProfile.currentLanguage
        )
        
        // Quick Metrics
        MetricsOverviewView(
            metrics: userProfile.profile.performanceMetrics,
            language: userProfile.currentLanguage
        )
        
        // Category Performance
        CategoryPerformanceView(
            categoryStats: userProfile.profile.categoryPerformance,
            strongCategories: userProfile.profile.performanceMetrics.strongCategories,
            weakCategories: userProfile.profile.performanceMetrics.weakCategories,
            language: userProfile.currentLanguage
        )
        
        // Recent Session History
        RecentSessionsView(
            sessions: Array(userProfile.profile.sessions.suffix(5)),
            language: userProfile.currentLanguage
        )
    }
    
    @ViewBuilder
    private var progressContent: some View {
        // Weekly Progress Chart
        PerformanceChartView(
            weeklyProgress: userProfile.profile.weeklyProgress,
            language: userProfile.currentLanguage
        )
        
        // Difficulty Progression
        DifficultyProgressionView(
            sessions: userProfile.profile.sessions,
            language: userProfile.currentLanguage
        )
        
        // Improvement Trends
        ImprovementTrendsView(
            metrics: userProfile.profile.performanceMetrics,
            weeklyProgress: userProfile.profile.weeklyProgress,
            language: userProfile.currentLanguage
        )
    }
    
    @ViewBuilder
    private var insightsContent: some View {
        // Learning Insights
        LearningInsightsView(
            insights: userProfile.profile.learningInsights,
            language: userProfile.currentLanguage
        )
        
        // Performance Recommendations
        RecommendationsView(
            metrics: userProfile.profile.performanceMetrics,
            categoryStats: userProfile.profile.categoryPerformance,
            language: userProfile.currentLanguage
        )
        
        // Goal Setting
        GoalSettingView(
            currentLevel: userProfile.profile.overallDifficultLevel,
            language: userProfile.currentLanguage
        )
    }
}

enum TimeRange: String, CaseIterable {
    case week = "week"
    case month = "month"
    case threeMonths = "three_months"
    case year = "year"
    
    func displayName(language: AppLanguage) -> String {
        switch self {
        case .week:
            return language == .portuguese ? "Semana" : "Week"
        case .month:
            return language == .portuguese ? "Mês" : "Month"
        case .threeMonths:
            return language == .portuguese ? "3 Meses" : "3 Months"
        case .year:
            return language == .portuguese ? "Ano" : "Year"
        }
    }
}

struct PerformanceSummaryCard: View {
    let profile: UserProfile
    let language: AppLanguage
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(language == .portuguese ? "Desempenho Atual" : "Current Performance")
                        .font(.headline)
                    Text(performanceLevel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                performanceIndicator
            }
            
            HStack(spacing: 20) {
                StatItemView(
                    title: language == .portuguese ? "Precisão" : "Accuracy",
                    value: String(format: "%.0f%%", profile.accuracyPercentage),
                    trend: accuracyTrend
                )
                
                Divider()
                
                StatItemView(
                    title: language == .portuguese ? "Sessões" : "Sessions",
                    value: "\(profile.sessions.count)",
                    trend: .stable
                )
                
                Divider()
                
                StatItemView(
                    title: language == .portuguese ? "Nível" : "Level",
                    value: profile.overallDifficultLevel.displayName(language: language),
                    trend: .improving
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    private var performanceLevel: String {
        let accuracy = profile.accuracyPercentage
        
        switch accuracy {
        case 90...100:
            return language == .portuguese ? "Excelente" : "Excellent"
        case 80..<90:
            return language == .portuguese ? "Muito Bom" : "Very Good"
        case 70..<80:
            return language == .portuguese ? "Bom" : "Good"
        case 60..<70:
            return language == .portuguese ? "Regular" : "Average"
        default:
            return language == .portuguese ? "Precisa Melhorar" : "Needs Improvement"
        }
    }
    
    private var performanceIndicator: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: profile.accuracyPercentage / 100)
                .stroke(performanceColor, lineWidth: 8)
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(profile.accuracyPercentage))")
                .font(.title2)
                .bold()
                .foregroundColor(performanceColor)
        }
        .frame(width: 60, height: 60)
    }
    
    private var performanceColor: Color {
        let accuracy = profile.accuracyPercentage
        switch accuracy {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private var accuracyTrend: TrendDirection {
        guard profile.weeklyProgress.count >= 2 else { return .stable }
        
        let recent = profile.weeklyProgress.suffix(2)
        let current = recent.last?.averageAccuracy ?? 0
        let previous = recent.first?.averageAccuracy ?? 0
        
        if current > previous + 5 { return .improving }
        else if current < previous - 5 { return .declining }
        else { return .stable }
    }
}

struct StatItemView: View {
    let title: String
    let value: String
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .bold()
            
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentSessionsView: View {
    let sessions: [SessionData]
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Sessões Recentes" : "Recent Sessions")
                .font(.headline)
            
            if sessions.isEmpty {
                Text(language == .portuguese ? 
                     "Nenhuma sessão completada ainda" :
                     "No completed sessions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sessions) { session in
                        SessionRowView(session: session, language: language)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SessionRowView: View {
    let session: SessionData
    let language: AppLanguage
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.diseaseCategory)
                    .font(.caption)
                    .bold()
                
                Text(dateFormatter.string(from: session.startTime))
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: session.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(session.isCorrect ? .green : .red)
                
                Text(formatDuration(session.duration))
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%dm %ds", minutes, seconds)
    }
}

// MARK: - Additional Analytics Components

struct DifficultyProgressionView: View {
    let sessions: [SessionData]
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Progressão de Dificuldade" : "Difficulty Progression")
                .font(.headline)
            
            if sessions.isEmpty {
                Text(language == .portuguese ? 
                     "Complete mais sessões para ver a progressão" :
                     "Complete more sessions to see progression")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let difficultyBreakdown = calculateDifficultyBreakdown()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(DifficultLevel.allCases, id: \.self) { level in
                        let count = difficultyBreakdown[level] ?? 0
                        let accuracy = calculateAccuracyForLevel(level)
                        
                        DifficultyCard(
                            level: level,
                            count: count,
                            accuracy: accuracy,
                            language: language
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func calculateDifficultyBreakdown() -> [DifficultLevel: Int] {
        var breakdown: [DifficultLevel: Int] = [:]
        
        for session in sessions where session.completionStatus == .completed {
            breakdown[session.difficulty, default: 0] += 1
        }
        
        return breakdown
    }
    
    private func calculateAccuracyForLevel(_ level: DifficultLevel) -> Double {
        let levelSessions = sessions.filter { $0.difficulty == level && $0.completionStatus == .completed }
        guard !levelSessions.isEmpty else { return 0 }
        
        let correctCount = levelSessions.filter { $0.isCorrect }.count
        return Double(correctCount) / Double(levelSessions.count) * 100
    }
}

struct DifficultyCard: View {
    let level: DifficultLevel
    let count: Int
    let accuracy: Double
    let language: AppLanguage
    
    var body: some View {
        VStack(spacing: 8) {
            Text(level.displayName(language: language))
                .font(.caption)
                .bold()
            
            Text("\(count)")
                .font(.title2)
                .bold()
                .foregroundColor(levelColor)
            
            Text(language == .portuguese ? "casos" : "cases")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if count > 0 {
                Text(String(format: "%.0f%% precisão", accuracy))
                    .font(.caption2)
                    .foregroundColor(accuracyColor)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private var levelColor: Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }
    
    private var accuracyColor: Color {
        switch accuracy {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct ImprovementTrendsView: View {
    let metrics: PerformanceMetrics
    let weeklyProgress: [WeeklyProgress]
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Tendências de Melhoria" : "Improvement Trends")
                .font(.headline)
            
            VStack(spacing: 12) {
                TrendRow(
                    title: language == .portuguese ? "Taxa de Melhoria" : "Improvement Rate",
                    value: String(format: "%.1f%%", metrics.improvementRate * 100),
                    trend: getTrendForImprovementRate(metrics.improvementRate),
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                TrendRow(
                    title: language == .portuguese ? "Consistência" : "Consistency",
                    value: String(format: "%.1f%%", metrics.consistencyScore * 100),
                    trend: getTrendForConsistencyScore(metrics.consistencyScore),
                    icon: "chart.line.flattrend.xyaxis"
                )
                
                TrendRow(
                    title: language == .portuguese ? "Eficiência Diagnóstica" : "Diagnostic Efficiency",
                    value: String(format: "%.2f", metrics.diagnosticEfficiency),
                    trend: metrics.diagnosticEfficiency > 1.0 ? .improving : .stable,
                    icon: "gauge"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getTrendForImprovementRate(_ rate: Double) -> TrendDirection {
        if rate > 0 {
            return .improving
        } else if rate < 0 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func getTrendForConsistencyScore(_ score: Double) -> TrendDirection {
        if score > 0.7 {
            return .improving
        } else if score < 0.5 {
            return .declining
        } else {
            return .stable
        }
    }
}

struct TrendRow: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .bold()
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
                
                Text(trendText)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private var trendText: String {
        switch trend {
        case .improving: return "↗"
        case .declining: return "↘"
        case .stable: return "→"
        }
    }
}

struct RecommendationsView: View {
    let metrics: PerformanceMetrics
    let categoryStats: [String: CategoryStats]
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Recomendações" : "Recommendations")
                .font(.headline)
            
            LazyVStack(spacing: 12) {
                ForEach(generateRecommendations(), id: \.title) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func generateRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Response time recommendation
        if metrics.averageResponseTime > 300 { // More than 5 minutes
            recommendations.append(Recommendation(
                title: language == .portuguese ? "Melhore o Tempo de Resposta" : "Improve Response Time",
                description: language == .portuguese ? 
                    "Você está levando muito tempo para fazer diagnósticos. Tente ser mais decisivo." :
                    "You're taking too long to make diagnoses. Try to be more decisive.",
                actionText: language == .portuguese ? "Pratique casos rápidos" : "Practice quick cases",
                priority: .medium,
                icon: "clock"
            ))
        }
        
        // Questions per case recommendation
        if metrics.averageQuestionsPerCase > 12 {
            recommendations.append(Recommendation(
                title: language == .portuguese ? "Faça Perguntas Mais Focadas" : "Ask More Focused Questions",
                description: language == .portuguese ? 
                    "Você está fazendo muitas perguntas. Concentre-se nos sintomas principais." :
                    "You're asking too many questions. Focus on key symptoms.",
                actionText: language == .portuguese ? "Revise técnicas de entrevista" : "Review interview techniques",
                priority: .high,
                icon: "questionmark.circle"
            ))
        }
        
        // Weak categories recommendation
        if !metrics.weakCategories.isEmpty {
            recommendations.append(Recommendation(
                title: language == .portuguese ? "Foque nas Áreas Fracas" : "Focus on Weak Areas",
                description: language == .portuguese ? 
                    "Você precisa melhorar em: \(metrics.weakCategories.joined(separator: ", "))" :
                    "You need improvement in: \(metrics.weakCategories.joined(separator: ", "))",
                actionText: language == .portuguese ? "Estudar essas categorias" : "Study these categories",
                priority: .high,
                icon: "target"
            ))
        }
        
        // Consistency recommendation
        if metrics.consistencyScore < 0.6 {
            recommendations.append(Recommendation(
                title: language == .portuguese ? "Melhore a Consistência" : "Improve Consistency",
                description: language == .portuguese ? 
                    "Seu desempenho varia muito. Tente manter um padrão mais consistente." :
                    "Your performance varies too much. Try to maintain a more consistent pattern.",
                actionText: language == .portuguese ? "Desenvolva rotina de estudo" : "Develop study routine",
                priority: .medium,
                icon: "chart.line.flattrend.xyaxis"
            ))
        }
        
        return recommendations
    }
}

struct Recommendation {
    let title: String
    let description: String
    let actionText: String
    let priority: InsightPriority
    let icon: String
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: recommendation.icon)
                    .font(.title3)
                    .foregroundColor(recommendation.priority.color)
                
                Text(recommendation.title)
                    .font(.subheadline)
                    .bold()
                
                Spacer()
                
                Circle()
                    .fill(recommendation.priority.color)
                    .frame(width: 8, height: 8)
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                // Handle recommendation action
            }) {
                Text(recommendation.actionText)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(recommendation.priority.color.opacity(0.2))
                    .foregroundColor(recommendation.priority.color)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct GoalSettingView: View {
    let currentLevel: DifficultLevel
    let language: AppLanguage
    @State private var selectedGoals: Set<String> = []
    
    private let availableGoals = [
        "improve_accuracy", "reduce_time", "increase_consistency", 
        "master_category", "advance_level", "reduce_hints"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language == .portuguese ? "Definir Metas" : "Set Goals")
                .font(.headline)
            
            Text(language == .portuguese ? 
                 "Selecione suas metas de aprendizado:" :
                 "Select your learning goals:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVStack(spacing: 8) {
                ForEach(availableGoals, id: \.self) { goalId in
                    GoalRow(
                        goalId: goalId,
                        language: language,
                        isSelected: selectedGoals.contains(goalId)
                    ) {
                        if selectedGoals.contains(goalId) {
                            selectedGoals.remove(goalId)
                        } else {
                            selectedGoals.insert(goalId)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GoalRow: View {
    let goalId: String
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goalTitle)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.primary)
                    
                    Text(goalDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var goalTitle: String {
        switch goalId {
        case "improve_accuracy":
            return language == .portuguese ? "Melhorar Precisão" : "Improve Accuracy"
        case "reduce_time":
            return language == .portuguese ? "Reduzir Tempo" : "Reduce Time"
        case "increase_consistency":
            return language == .portuguese ? "Aumentar Consistência" : "Increase Consistency"
        case "master_category":
            return language == .portuguese ? "Dominar Categoria" : "Master Category"
        case "advance_level":
            return language == .portuguese ? "Avançar Nível" : "Advance Level"
        case "reduce_hints":
            return language == .portuguese ? "Usar Menos Dicas" : "Use Fewer Hints"
        default:
            return goalId
        }
    }
    
    private var goalDescription: String {
        switch goalId {
        case "improve_accuracy":
            return language == .portuguese ? "Alcançar 85%+ de precisão" : "Achieve 85%+ accuracy"
        case "reduce_time":
            return language == .portuguese ? "Diagnóstico em < 3 min" : "Diagnose in < 3 min"
        case "increase_consistency":
            return language == .portuguese ? "Manter desempenho estável" : "Maintain stable performance"
        case "master_category":
            return language == .portuguese ? "100% em uma categoria" : "100% in one category"
        case "advance_level":
            return language == .portuguese ? "Próximo nível de dificuldade" : "Next difficulty level"
        case "reduce_hints":
            return language == .portuguese ? "< 2 dicas por caso" : "< 2 hints per case"
        default:
            return ""
        }
    }
}

// MARK: - Updated Patient Simulation View (Complete with all features)
struct PatientSimulationView: View {
    let disease: Disease
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
    @State private var sessionStartTime = Date()
    @State private var showingAPIKeySetup = false
    
    private var patientCase: PatientCase? {
        dataManager.getPatientCase(for: disease)
    }
    
    var body: some View {
        VStack {
            // Patient Header
            if let patient = patientCase {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(patient.demographics.name)")
                        .font(.headline)
                    
                    Text(getPatientAgeGenderText(patient: patient))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingPersonalityDetails = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark")
                                .foregroundColor(.purple)
                            Text(getPersonalityDisplayName(for: patient))
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundColor(.purple.opacity(0.7))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
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
                }
                .padding()
                .background(Color.gray.opacity(0.1))
            }
            
            // Conversation History
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversationHistory) { turn in
                        ConversationBubbleView(turn: turn, language: userProfile.currentLanguage)
                    }
                    
                    if aiService.isGeneratingResponse {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(getProcessingText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(15)
                    }
                }
                .padding()
            }
            
            // Quick Questions
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
            }
            
            // Input Section
            VStack(spacing: 8) {
                HStack {
                    TextField(getTextFieldPlaceholder(), text: $currentQuestion)
                        .textFieldStyle(.roundedBorder)
                        .disabled(aiService.isGeneratingResponse)
                    
                    Button(action: askQuestion) {
                        if aiService.isGeneratingResponse {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .disabled(currentQuestion.isEmpty || aiService.isGeneratingResponse)
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
                    onDismiss: {
                        showingResults = false
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
        .onAppear {
            if let patientCase = patientCase {
                userProfile.startNewSession(patientCase: patientCase)
            }
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
    
    private func askQuestion() {
        guard !self.currentQuestion.isEmpty && !self.aiService.isGeneratingResponse,
              let patient = self.patientCase else { return }
        
        let question = self.currentQuestion
        self.currentQuestion = ""
        
        Task {
            let response = await self.aiService.generatePatientResponse(
                question: question,
                patientCase: patient,
                conversationHistory: self.conversationHistory,
                language: self.userProfile.currentLanguage
            )
            
            await MainActor.run {
                self.conversationHistory.append(ConversationTurn(
                    question: question,
                    response: response,
                    timestamp: Date(),
                    isTest: false
                ))
                
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
        
        self.testsOrdered += 1
        
        Task {
            let response = await self.aiService.generateTestResult(
                testRequest: test,
                patientCase: patient,
                language: self.userProfile.currentLanguage
            )
            
            await MainActor.run {
                self.conversationHistory.append(ConversationTurn(
                    question: self.userProfile.currentLanguage == .portuguese ? "Teste solicitado: \(test)" : "Test ordered: \(test)",
                    response: response,
                    timestamp: Date(),
                    isTest: true
                ))
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
            
        self.diagnosisResult = DiagnosisResult(
            userDiagnosis: diagnosis,
            isCorrect: isCorrect,
            conversationTurns: self.conversationHistory.filter { !$0.isTest }.count,
            patientName: patient.demographics.name,
            hintsUsed: self.hintsUsed,
            testsOrdered: self.testsOrdered,
            feedback: feedbackMessage
        )
        
        self.userProfile.recordDiagnosis(
            disease: self.disease,
            isCorrect: isCorrect,
            questionCount: self.conversationHistory.filter { !$0.isTest }.count,
            hintsUsed: self.hintsUsed,
            testsOrdered: self.testsOrdered
        )
        
        // Enhanced session tracking: Complete session with detailed analytics
        let sessionTime = Date().timeIntervalSince(self.sessionStartTime)
        let questionsAsked = self.conversationHistory.filter { !$0.isTest }.count
        let confidenceScore = isCorrect ? 0.9 : 0.3 // Simple confidence scoring
        
        self.userProfile.completeSession(
            finalDiagnosis: diagnosis,
            isCorrect: isCorrect,
            confidenceScore: confidenceScore
        )
        
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
    
    private func getPatientAgeGenderText(patient: PatientCase) -> String {
        let ageText = self.userProfile.currentLanguage == .portuguese ? "anos" : "years old"
        let genderText = translateGender(patient.demographics.gender, to: self.userProfile.currentLanguage)
        return "\(patient.demographics.age) \(ageText), \(genderText)"
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
            
            HStack(spacing: 20) {
                Button(language == .portuguese ? "Cancelar" : "Cancel") {
                    dismiss()
                }
                .foregroundColor(.red)
                
                Button(language == .portuguese ? "Submeter" : "Submit") {
                    userDiagnosis = localDiagnosis
                    onSubmit(localDiagnosis)
                    dismiss()
                }
                .foregroundColor(.blue)
                .disabled(localDiagnosis.isEmpty)
            }
            .padding(.bottom)
        }
        .presentationDetents([.medium])
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

// MARK: - Diagnosis Result View
struct DiagnosisResultView: View {
    let result: DiagnosisResult
    let language: AppLanguage
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(result.isCorrect ? 
                 (language == .portuguese ? "Correto!" : "Correct!") :
                 (language == .portuguese ? "Incorreto" : "Incorrect"))
                .font(.title)
                .foregroundColor(result.isCorrect ? .green : .red)
            
            Text(result.feedback)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(language == .portuguese ? "Continuar" : "Continue") {
                onDismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

// MARK: - Study Materials View
struct StudyMaterialsView: View {
    let disease: Disease
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(disease.getDisplayName(language))
                        .font(.title)
                        .bold()
                    
                    Text(disease.getDescription(language))
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    // Add more study material content here
                    Text(language == .portuguese ? "Material de estudo para esta condição..." : "Study material for this condition...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle(language == .portuguese ? "Material de Estudo" : "Study Materials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Personality Details View
struct PersonalityDetailsView: View {
    let personality: PatientPersonality
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(language == .portuguese ? "Tipo de Personalidade" : "Personality Type")
                            .font(.headline)
                        Text(personality.type.displayName(language: language))
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        PersonalityTraitRow(
                            title: language == .portuguese ? "Cooperação" : "Cooperation",
                            value: personality.cooperationLevel,
                            color: .blue
                        )
                        
                        PersonalityTraitRow(
                            title: language == .portuguese ? "Tolerância à Dor" : "Pain Tolerance", 
                            value: personality.painTolerance,
                            color: .orange
                        )
                        
                        PersonalityTraitRow(
                            title: language == .portuguese ? "Nível de Ansiedade" : "Anxiety Level",
                            value: personality.anxietyLevel,
                            color: .red
                        )
                        
                        PersonalityTraitRow(
                            title: language == .portuguese ? "Confiança" : "Trust Level",
                            value: personality.trustLevel,
                            color: .green
                        )
                        
                        PersonalityTraitRow(
                            title: language == .portuguese ? "Clareza da Memória" : "Memory Clarity",
                            value: personality.memoryClarity,
                            color: .purple
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(language == .portuguese ? "Detalhes da Personalidade" : "Personality Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views for Personality Details
struct PersonalityTraitRow: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.subheadline)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * value, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}
