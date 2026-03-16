import SwiftUI
import Foundation
import SQLite3
import Speech
import AVFoundation

// MARK: - Define SQLITE_TRANSIENT constant
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Basic Mode (Anamnese Training)
struct AnamneseQuestion: Identifiable, Codable {
    let id: Int
    let section: AnamneseSection
    let questionEnglish: String
    let questionPortuguese: String
    let orderInSection: Int
    let isRequired: Bool
    let keywords: [String]  // For AI matching

    func getText(_ language: AppLanguage) -> String {
        return language == .portuguese ? questionPortuguese : questionEnglish
    }
}

struct PatientAnamneseData: Codable {
    let patientId: Int
    let answers: [Int: String]  // question_id -> answer

    func getAnswer(for questionId: Int, language: AppLanguage) -> String {
        return answers[questionId] ?? (language == .portuguese ? "Não informado" : "Not provided")
    }
}

struct BasicModeSession: Codable {
    var questionsAsked: Set<Int> = []
    var questionOrder: [Int] = []
    var startTime: Date = Date()
    var currentSection: AnamneseSection = .identification
    // Note: conversationHistory is managed separately in the view as @State
}

struct BasicModeResult: Codable {
    let totalQuestions: Int
    let questionsAsked: Int
    let requiredQuestionsTotal: Int
    let requiredQuestionsAsked: Int
    let questionOrder: [Int]
    let completenessScore: Double    // 0-100
    let sequenceScore: Double        // 0-100
    let requiredScore: Double        // 0-100
    let overallScore: Double         // 0-100
    let missedImportantQuestions: [AnamneseQuestion]
    let questionsOutOfOrder: Int
    let feedback: String
    let strengths: [String]
    let improvements: [String]
    // Task 3.2: section timing and full missed-question list
    let sectionTimings: [Int: Double]          // AnamneseSection.rawValue → seconds spent
    let allMissedQuestions: [AnamneseQuestion] // All questions not asked (not just required)
}

// MARK: - Anamnese Question Database
class AnamneseQuestionDatabase {
    static let shared = AnamneseQuestionDatabase()

    let allQuestions: [AnamneseQuestion] = [
        // SECTION 1: IDENTIFICATION (14 questions)
        AnamneseQuestion(id: 101, section: .identification, questionEnglish: "What is your full name?", questionPortuguese: "Qual é o seu nome completo?", orderInSection: 1, isRequired: true, keywords: ["name", "nome", "called", "chamado"]),
        AnamneseQuestion(id: 102, section: .identification, questionEnglish: "How would you prefer to be called?", questionPortuguese: "Como prefere ser chamado?", orderInSection: 2, isRequired: false, keywords: ["prefer", "prefere", "nickname", "apelido"]),
        AnamneseQuestion(id: 103, section: .identification, questionEnglish: "How old are you?", questionPortuguese: "Quantos anos você tem?", orderInSection: 3, isRequired: true, keywords: ["age", "idade", "old", "anos"]),
        AnamneseQuestion(id: 104, section: .identification, questionEnglish: "What is your date of birth?", questionPortuguese: "Qual é a sua data de nascimento?", orderInSection: 4, isRequired: true, keywords: ["birth", "nascimento", "born", "nasceu"]),
        AnamneseQuestion(id: 105, section: .identification, questionEnglish: "What is your sex/gender?", questionPortuguese: "Qual é o seu sexo/gênero?", orderInSection: 5, isRequired: true, keywords: ["sex", "sexo", "gender", "gênero"]),
        AnamneseQuestion(id: 106, section: .identification, questionEnglish: "What is your ethnicity/race?", questionPortuguese: "Qual é a sua cor/etnia?", orderInSection: 6, isRequired: false, keywords: ["ethnicity", "etnia", "race", "cor"]),
        AnamneseQuestion(id: 107, section: .identification, questionEnglish: "What is your marital status?", questionPortuguese: "Qual é o seu estado civil?", orderInSection: 7, isRequired: false, keywords: ["marital", "civil", "married", "casado"]),
        AnamneseQuestion(id: 108, section: .identification, questionEnglish: "What is your occupation/profession?", questionPortuguese: "Qual é a sua profissão?", orderInSection: 8, isRequired: true, keywords: ["occupation", "profissão", "work", "trabalho"]),
        AnamneseQuestion(id: 109, section: .identification, questionEnglish: "Where do you work?", questionPortuguese: "Onde você trabalha?", orderInSection: 9, isRequired: false, keywords: ["workplace", "local de trabalho", "where work", "onde trabalha"]),
        AnamneseQuestion(id: 110, section: .identification, questionEnglish: "What is your level of education?", questionPortuguese: "Qual é a sua escolaridade?", orderInSection: 10, isRequired: false, keywords: ["education", "escolaridade", "school", "estudo"]),
        AnamneseQuestion(id: 111, section: .identification, questionEnglish: "Where were you born?", questionPortuguese: "Onde você nasceu?", orderInSection: 11, isRequired: false, keywords: ["birthplace", "naturalidade", "born", "nasceu"]),
        AnamneseQuestion(id: 112, section: .identification, questionEnglish: "Where do you currently live?", questionPortuguese: "Onde você mora atualmente?", orderInSection: 12, isRequired: true, keywords: ["live", "mora", "address", "endereço", "residence", "residência"]),
        AnamneseQuestion(id: 113, section: .identification, questionEnglish: "What is your mother's name?", questionPortuguese: "Qual é o nome da sua mãe?", orderInSection: 13, isRequired: false, keywords: ["mother", "mãe", "mother's name", "nome da mãe"]),
        AnamneseQuestion(id: 114, section: .identification, questionEnglish: "What is your religion?", questionPortuguese: "Qual é a sua religião?", orderInSection: 14, isRequired: false, keywords: ["religion", "religião", "faith", "fé"]),

        // SECTION 2: CHIEF COMPLAINT (3 questions)
        AnamneseQuestion(id: 201, section: .chiefComplaint, questionEnglish: "What brings you here today? What is bothering you the most?", questionPortuguese: "O que te traz aqui hoje? O que te incomoda mais?", orderInSection: 1, isRequired: true, keywords: ["complaint", "queixa", "problem", "problema", "bothering", "incomoda"]),
        AnamneseQuestion(id: 202, section: .chiefComplaint, questionEnglish: "Do you have any other concerns or problems?", questionPortuguese: "Você tem alguma outra preocupação ou problema?", orderInSection: 2, isRequired: false, keywords: ["other", "outro", "concern", "preocupação", "more", "mais"]),

        // SECTION 3: PRESENT ILLNESS HISTORY (10 questions)
        AnamneseQuestion(id: 301, section: .presentIllness, questionEnglish: "When did the symptoms start?", questionPortuguese: "Quando os sintomas começaram?", orderInSection: 1, isRequired: true, keywords: ["when", "quando", "start", "começou", "began", "iniciou"]),
        AnamneseQuestion(id: 302, section: .presentIllness, questionEnglish: "Did it start suddenly or gradually?", questionPortuguese: "Começou de repente ou gradualmente?", orderInSection: 2, isRequired: true, keywords: ["sudden", "súbito", "gradual", "gradualmente"]),
        AnamneseQuestion(id: 303, section: .presentIllness, questionEnglish: "Where is the symptom located?", questionPortuguese: "Onde está localizado o sintoma?", orderInSection: 3, isRequired: true, keywords: ["where", "onde", "location", "localização"]),
        AnamneseQuestion(id: 304, section: .presentIllness, questionEnglish: "How long does it last?", questionPortuguese: "Quanto tempo dura?", orderInSection: 4, isRequired: false, keywords: ["duration", "duração", "how long", "quanto tempo"]),
        AnamneseQuestion(id: 305, section: .presentIllness, questionEnglish: "How intense is the symptom?", questionPortuguese: "Qual é a intensidade do sintoma?", orderInSection: 5, isRequired: true, keywords: ["intensity", "intensidade", "severe", "grave", "pain scale", "escala"]),
        AnamneseQuestion(id: 306, section: .presentIllness, questionEnglish: "Does the symptom radiate anywhere?", questionPortuguese: "O sintoma irradia para algum lugar?", orderInSection: 6, isRequired: false, keywords: ["radiate", "irradia", "spread", "espalha"]),
        AnamneseQuestion(id: 307, section: .presentIllness, questionEnglish: "What makes it better?", questionPortuguese: "O que melhora?", orderInSection: 7, isRequired: true, keywords: ["better", "melhora", "relieve", "alivia"]),
        AnamneseQuestion(id: 308, section: .presentIllness, questionEnglish: "What makes it worse?", questionPortuguese: "O que piora?", orderInSection: 8, isRequired: true, keywords: ["worse", "piora", "aggravate", "agrava"]),
        AnamneseQuestion(id: 309, section: .presentIllness, questionEnglish: "Do you have any associated symptoms?", questionPortuguese: "Você tem algum sintoma associado?", orderInSection: 9, isRequired: false, keywords: ["associated", "associado", "other symptoms", "outros sintomas"]),
        AnamneseQuestion(id: 310, section: .presentIllness, questionEnglish: "Are you currently experiencing the symptom?", questionPortuguese: "Você está sentindo o sintoma agora?", orderInSection: 10, isRequired: false, keywords: ["now", "agora", "currently", "atualmente"]),

        // SECTION 4: GUIDING SYMPTOM (3 questions)
        AnamneseQuestion(id: 401, section: .guidingSymptom, questionEnglish: "Which symptom has lasted the longest?", questionPortuguese: "Qual sintoma dura há mais tempo?", orderInSection: 1, isRequired: true, keywords: ["longest", "mais tempo", "first", "primeiro"]),
        AnamneseQuestion(id: 402, section: .guidingSymptom, questionEnglish: "Which symptom bothers you the most?", questionPortuguese: "Qual sintoma te incomoda mais?", orderInSection: 2, isRequired: true, keywords: ["most", "mais", "bother", "incomoda", "worst", "pior"]),
        AnamneseQuestion(id: 403, section: .guidingSymptom, questionEnglish: "Can you describe the timeline of your symptoms?", questionPortuguese: "Você pode descrever a cronologia dos seus sintomas?", orderInSection: 3, isRequired: false, keywords: ["timeline", "cronologia", "sequence", "sequência"]),

        // SECTION 5: PERSONAL HISTORY (15 questions covering physiological and pathological)
        // Physiological
        AnamneseQuestion(id: 501, section: .personalHistory, questionEnglish: "How was your mother's pregnancy with you?", questionPortuguese: "Como foi a gravidez da sua mãe com você?", orderInSection: 1, isRequired: false, keywords: ["pregnancy", "gravidez", "gestation", "gestação"]),
        AnamneseQuestion(id: 502, section: .personalHistory, questionEnglish: "What type of delivery did your mother have?", questionPortuguese: "Qual foi o tipo de parto?", orderInSection: 2, isRequired: false, keywords: ["delivery", "parto", "birth", "nascimento"]),
        AnamneseQuestion(id: 503, section: .personalHistory, questionEnglish: "Did you have normal development as a child?", questionPortuguese: "Você teve desenvolvimento normal quando criança?", orderInSection: 3, isRequired: false, keywords: ["development", "desenvolvimento", "childhood", "infância"]),
        AnamneseQuestion(id: 504, section: .personalHistory, questionEnglish: "At what age did you reach puberty?", questionPortuguese: "Com que idade você entrou na puberdade?", orderInSection: 4, isRequired: false, keywords: ["puberty", "puberdade", "adolescence", "adolescência"]),
        AnamneseQuestion(id: 505, section: .personalHistory, questionEnglish: "For women: When was your first menstrual period?", questionPortuguese: "Para mulheres: Quando foi sua primeira menstruação?", orderInSection: 5, isRequired: false, keywords: ["menarche", "menarca", "menstruation", "menstruação", "period", "período"]),
        // Pathological
        AnamneseQuestion(id: 506, section: .personalHistory, questionEnglish: "What childhood diseases did you have?", questionPortuguese: "Que doenças você teve na infância?", orderInSection: 6, isRequired: true, keywords: ["childhood", "infância", "diseases", "doenças", "measles", "sarampo", "chickenpox", "catapora"]),
        AnamneseQuestion(id: 507, section: .personalHistory, questionEnglish: "Do you have any chronic diseases?", questionPortuguese: "Você tem alguma doença crônica?", orderInSection: 7, isRequired: true, keywords: ["chronic", "crônica", "disease", "doença", "diabetes", "hypertension", "hipertensão"]),
        AnamneseQuestion(id: 508, section: .personalHistory, questionEnglish: "Do you have any allergies?", questionPortuguese: "Você tem alguma alergia?", orderInSection: 8, isRequired: true, keywords: ["allergy", "alergia", "allergic", "alérgico"]),
        AnamneseQuestion(id: 509, section: .personalHistory, questionEnglish: "Have you had any surgeries?", questionPortuguese: "Você já fez alguma cirurgia?", orderInSection: 9, isRequired: true, keywords: ["surgery", "cirurgia", "operation", "operação"]),
        AnamneseQuestion(id: 510, section: .personalHistory, questionEnglish: "Have you had any serious accidents or trauma?", questionPortuguese: "Você já sofreu algum acidente grave ou trauma?", orderInSection: 10, isRequired: false, keywords: ["accident", "acidente", "trauma", "injury", "lesão"]),
        AnamneseQuestion(id: 511, section: .personalHistory, questionEnglish: "Have you ever had a blood transfusion?", questionPortuguese: "Você já recebeu transfusão de sangue?", orderInSection: 11, isRequired: false, keywords: ["transfusion", "transfusão", "blood", "sangue"]),
        AnamneseQuestion(id: 512, section: .personalHistory, questionEnglish: "Are your vaccinations up to date?", questionPortuguese: "Suas vacinas estão em dia?", orderInSection: 12, isRequired: true, keywords: ["vaccine", "vacina", "vaccination", "vacinação", "immunization", "imunização"]),
        AnamneseQuestion(id: 513, section: .personalHistory, questionEnglish: "What medications are you currently taking?", questionPortuguese: "Que medicamentos você está tomando atualmente?", orderInSection: 13, isRequired: true, keywords: ["medication", "medicamento", "medicine", "remédio", "drug", "droga"]),
        AnamneseQuestion(id: 514, section: .personalHistory, questionEnglish: "For women: How many pregnancies have you had?", questionPortuguese: "Para mulheres: Quantas gestações você teve?", orderInSection: 14, isRequired: false, keywords: ["pregnancy", "gestação", "children", "filhos", "births", "partos"]),
        AnamneseQuestion(id: 515, section: .personalHistory, questionEnglish: "For women: How many children do you have?", questionPortuguese: "Para mulheres: Quantos filhos você tem?", orderInSection: 15, isRequired: false, keywords: ["children", "filhos", "kids", "crianças"]),

        // SECTION 6: FAMILY HISTORY (6 questions)
        AnamneseQuestion(id: 601, section: .familyHistory, questionEnglish: "Are your parents alive? How is their health?", questionPortuguese: "Seus pais são vivos? Como está a saúde deles?", orderInSection: 1, isRequired: true, keywords: ["parents", "pais", "father", "pai", "mother", "mãe", "alive", "vivos"]),
        AnamneseQuestion(id: 602, section: .familyHistory, questionEnglish: "Do you have siblings? How is their health?", questionPortuguese: "Você tem irmãos? Como está a saúde deles?", orderInSection: 2, isRequired: false, keywords: ["siblings", "irmãos", "brothers", "sisters", "irmãs"]),
        AnamneseQuestion(id: 603, section: .familyHistory, questionEnglish: "Does anyone in your family have chronic diseases?", questionPortuguese: "Alguém na sua família tem doenças crônicas?", orderInSection: 3, isRequired: true, keywords: ["family", "família", "disease", "doença", "diabetes", "hypertension", "hipertensão", "cancer", "câncer"]),
        AnamneseQuestion(id: 604, section: .familyHistory, questionEnglish: "Who lives in your house?", questionPortuguese: "Quem mora na sua casa?", orderInSection: 4, isRequired: false, keywords: ["house", "casa", "live", "mora", "household", "domicílio"]),
        AnamneseQuestion(id: 605, section: .familyHistory, questionEnglish: "How was the health of your grandparents?", questionPortuguese: "Como era a saúde dos seus avós?", orderInSection: 5, isRequired: false, keywords: ["grandparents", "avós", "grandfather", "avô", "grandmother", "avó"]),
        AnamneseQuestion(id: 606, section: .familyHistory, questionEnglish: "Are there any hereditary diseases in your family?", questionPortuguese: "Existem doenças hereditárias na sua família?", orderInSection: 6, isRequired: false, keywords: ["hereditary", "hereditária", "genetic", "genética", "inherited", "herdada"]),

        // SECTION 7: LIFESTYLE HABITS (12 questions)
        AnamneseQuestion(id: 701, section: .lifestyle, questionEnglish: "How is your diet? What do you typically eat?", questionPortuguese: "Como é a sua alimentação? O que você costuma comer?", orderInSection: 1, isRequired: true, keywords: ["diet", "alimentação", "eat", "comer", "food", "comida"]),
        AnamneseQuestion(id: 702, section: .lifestyle, questionEnglish: "How much water do you drink per day?", questionPortuguese: "Quanto de água você bebe por dia?", orderInSection: 2, isRequired: false, keywords: ["water", "água", "drink", "beber", "hydration", "hidratação"]),
        AnamneseQuestion(id: 703, section: .lifestyle, questionEnglish: "Do you exercise? What type and how often?", questionPortuguese: "Você pratica exercícios físicos? Que tipo e com que frequência?", orderInSection: 3, isRequired: true, keywords: ["exercise", "exercício", "physical", "físico", "sport", "esporte"]),
        AnamneseQuestion(id: 704, section: .lifestyle, questionEnglish: "Do you smoke? If yes, how much?", questionPortuguese: "Você fuma? Se sim, quanto?", orderInSection: 4, isRequired: true, keywords: ["smoke", "fumar", "cigarette", "cigarro", "tobacco", "tabaco"]),
        AnamneseQuestion(id: 705, section: .lifestyle, questionEnglish: "Do you drink alcohol? If yes, how much and how often?", questionPortuguese: "Você bebe álcool? Se sim, quanto e com que frequência?", orderInSection: 5, isRequired: true, keywords: ["alcohol", "álcool", "drink", "beber", "beer", "cerveja"]),
        AnamneseQuestion(id: 706, section: .lifestyle, questionEnglish: "Do you use any recreational drugs?", questionPortuguese: "Você usa drogas recreativas?", orderInSection: 6, isRequired: true, keywords: ["drugs", "drogas", "substance", "substância", "marijuana", "maconha"]),
        AnamneseQuestion(id: 707, section: .lifestyle, questionEnglish: "How is your housing situation?", questionPortuguese: "Como é a sua moradia?", orderInSection: 7, isRequired: false, keywords: ["housing", "moradia", "home", "casa", "live", "mora"]),
        AnamneseQuestion(id: 708, section: .lifestyle, questionEnglish: "Do you have running water and sewage at home?", questionPortuguese: "Você tem água encanada e esgoto em casa?", orderInSection: 8, isRequired: false, keywords: ["water", "água", "sewage", "esgoto", "sanitation", "saneamento"]),
        AnamneseQuestion(id: 709, section: .lifestyle, questionEnglish: "Do you have pets?", questionPortuguese: "Você tem animais de estimação?", orderInSection: 9, isRequired: false, keywords: ["pets", "animais", "dog", "cachorro", "cat", "gato"]),
        AnamneseQuestion(id: 710, section: .lifestyle, questionEnglish: "What is your monthly income?", questionPortuguese: "Qual é a sua renda mensal?", orderInSection: 10, isRequired: false, keywords: ["income", "renda", "salary", "salário", "money", "dinheiro"]),
        AnamneseQuestion(id: 711, section: .lifestyle, questionEnglish: "How do you handle stress?", questionPortuguese: "Como você lida com o estresse?", orderInSection: 11, isRequired: false, keywords: ["stress", "estresse", "anxiety", "ansiedade", "cope", "lidar"]),
        AnamneseQuestion(id: 712, section: .lifestyle, questionEnglish: "How are your family relationships?", questionPortuguese: "Como são seus relacionamentos familiares?", orderInSection: 12, isRequired: false, keywords: ["relationship", "relacionamento", "family", "família", "spouse", "cônjuge"]),
    ]

    func getQuestions(for section: AnamneseSection) -> [AnamneseQuestion] {
        return allQuestions.filter { $0.section == section }.sorted { $0.orderInSection < $1.orderInSection }
    }

    func getRequiredQuestions() -> [AnamneseQuestion] {
        return allQuestions.filter { $0.isRequired }
    }

    func getTotalQuestionCount() -> Int {
        return allQuestions.count
    }

    func getRequiredQuestionCount() -> Int {
        return allQuestions.filter { $0.isRequired }.count
    }

    func getSectionStats() -> [(section: AnamneseSection, total: Int, required: Int)] {
        return AnamneseSection.allCases.map { section in
            let questions = getQuestions(for: section)
            return (section: section, total: questions.count, required: questions.filter { $0.isRequired }.count)
        }
    }
}

// PatientDemographics, PatientPersonality, SocialHistory, FamilyHistory, PatientCase moved to Models/PatientModels.swift

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

// DatabaseManager and MedicalDatabaseManager extracted to Services/MedicalDatabaseManager.swift

// UserProfileManager extracted to Services/UserProfileManager.swift

// MARK: - Response Rating for Teacher Testing
enum ResponseRating: String, Codable {
    case good
    case tooWordy = "too_wordy"
    case wrongInfo = "wrong_info"
    case unnaturalLanguage = "unnatural_language"
    case other

    func displayText(_ language: AppLanguage) -> String {
        switch self {
        case .good:
            return language == .portuguese ? "Boa resposta" : "Good response"
        case .tooWordy:
            return language == .portuguese ? "Muito longa" : "Too wordy"
        case .wrongInfo:
            return language == .portuguese ? "Info errada" : "Wrong info"
        case .unnaturalLanguage:
            return language == .portuguese ? "Linguagem artificial" : "Unnatural language"
        case .other:
            return language == .portuguese ? "Outro" : "Other"
        }
    }
}

// MARK: - Conversation Models
struct ConversationTurn: Identifiable {
    var id = UUID()
    let question: String
    let response: String
    let timestamp: Date
    let isTest: Bool
    var rating: ResponseRating? = nil
}

/// A similar disease that could be confused with the correct diagnosis.
struct DifferentialEntry {
    let name: String                         // Disease name in current language
    let sharedSymptoms: [String]             // Symptoms shared with the correct disease (up to 3)
    var distinguishingFeatures: [String] = [] // Symptoms the correct disease has that this differential does NOT (up to 2)
}

struct DiagnosisResult {
    let userDiagnosis: String
    let isCorrect: Bool
    let conversationTurns: Int
    let patientName: String
    let hintsUsed: Int
    let testsOrdered: Int
    let feedback: String
    // Test ordering evaluation (task 3.1)
    var orderedTestNames: [String] = []
    var relevantTests: [String] = []        // Ordered tests that matched disease lab results
    var unnecessaryTests: [String] = []     // Ordered tests with no match
    var missedKeyTests: [String] = []       // Expected lab results not ordered by student
    // Differential diagnosis and study notes (task 3.3)
    var differentialDiagnoses: [DifferentialEntry] = []   // Top 3 similar conditions
    var studyNotes: [String] = []                         // Diagnostic hints from the database
}

struct TreatmentResult {
    let userTreatment: String
    let correctTreatments: [Treatment]
    let matchedTreatments: [Treatment]
    let missedTreatments: [Treatment]
    let score: Double  // 0.0-1.0
    let feedback: String
    let isAcceptable: Bool  // true if score >= 0.6
}

// MARK: - ClaudeAIService extracted to Services/ClaudeAIService.swift


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

// ContentView and PatientRowView
// extracted to Views/ContentView.swift

// UserProfileView, TrainingModeButton, ProfileStatCard, PerformanceChartView,
// WeekProgressBar, MetricsOverviewView, MetricCard, CategoryPerformanceView, CategorySection,
// LearningInsightsView, InsightCard, AnalyticsDashboardView, TimeRange, PerformanceSummaryCard,
// StatItemView, RecentSessionsView, SessionRowView, DifficultyProgressionView, DifficultyCard,
// ImprovementTrendsView, TrendRow, RecommendationsView, Recommendation, RecommendationCard,
// GoalSettingView, GoalRow
// extracted to Views/UserProfileView.swift

// BasicModePatientSimulationView, BasicModeResultsView, and AnamneseSection.displayName extension
// extracted to Views/BasicModeView.swift


// PatientSimulationView, ConversationBubbleView, TestEntryView, VoiceInputButton
// extracted to Views/PatientInterviewView.swift

// DiagnosisEntryView, DiagnosisResultView
// extracted to Views/DiagnosisView.swift

// TreatmentPrescriptionEntryView, TreatmentEvaluationView
// extracted to Views/TreatmentView.swift

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
        .navigationViewStyle(.stack)
    }
}

// MARK: - Session History View
struct SessionHistoryView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @EnvironmentObject var dataManager: MedicalDatabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: SessionFilter = .all
    @State private var selectedSession: SessionData?
    @State private var showingSessionDetail = false
    let language: AppLanguage

    enum SessionFilter: String, CaseIterable {
        case all, correct, incorrect, thisWeek, thisMonth

        func displayName(language: AppLanguage) -> String {
            switch self {
            case .all:
                return language == .portuguese ? "Todos" : "All"
            case .correct:
                return language == .portuguese ? "Corretos" : "Correct"
            case .incorrect:
                return language == .portuguese ? "Incorretos" : "Incorrect"
            case .thisWeek:
                return language == .portuguese ? "Esta Semana" : "This Week"
            case .thisMonth:
                return language == .portuguese ? "Este Mês" : "This Month"
            }
        }
    }

    private var filteredSessions: [SessionData] {
        let completedSessions = userProfile.profile.sessions
            .filter { $0.completionStatus == .completed }
            .sorted { $0.startTime > $1.startTime }

        switch selectedFilter {
        case .all:
            return completedSessions
        case .correct:
            return completedSessions.filter { $0.isCorrect }
        case .incorrect:
            return completedSessions.filter { !$0.isCorrect }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return completedSessions.filter { $0.startTime >= weekAgo }
        case .thisMonth:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
            return completedSessions.filter { $0.startTime >= monthAgo }
        }
    }

    private var strugglingDiseases: [(name: String, attempts: Int, successRate: Double)] {
        let sessions = userProfile.profile.sessions.filter { $0.completionStatus == .completed }
        var diseaseStats: [String: (total: Int, correct: Int)] = [:]

        for session in sessions {
            if let disease = dataManager.diseases.first(where: { $0.id == Int(session.patientCaseId) ?? 0 }) {
                let name = disease.getDisplayName(language)
                let current = diseaseStats[name] ?? (total: 0, correct: 0)
                diseaseStats[name] = (
                    total: current.total + 1,
                    correct: current.correct + (session.isCorrect ? 1 : 0)
                )
            }
        }

        return diseaseStats
            .filter { $0.value.total >= 2 && Double($0.value.correct) / Double($0.value.total) < 0.6 }
            .map { (name: $0.key, attempts: $0.value.total, successRate: Double($0.value.correct) / Double($0.value.total)) }
            .sorted { $0.successRate < $1.successRate }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Struggling Diseases Section
                    if !strugglingDiseases.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(language == .portuguese ? "Revise Estas Condições" : "Review These Conditions")
                                .font(.headline)
                                .padding(.horizontal)

                            Text(language == .portuguese ? "Condições com as quais você teve dificuldade" : "Conditions you've struggled with")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(strugglingDiseases, id: \.name) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.body)
                                        Text("\(item.attempts) \(language == .portuguese ? "tentativas" : "attempts") • \(Int(item.successRate * 100))% \(language == .portuguese ? "correto" : "correct")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Circle()
                                        .fill(item.successRate < 0.3 ? Color.red : Color.orange)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text("\(Int(item.successRate * 100))%")
                                                .font(.caption2)
                                                .bold()
                                                .foregroundColor(.white)
                                        )
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }

                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SessionFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    selectedFilter = filter
                                }) {
                                    Text(filter.displayName(language: language))
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Sessions List
                    if filteredSessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text(language == .portuguese ? "Nenhuma sessão encontrada" : "No sessions found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSessions) { session in
                                SessionHistoryRow(session: session, language: language, dataManager: dataManager)
                                    .onTapGesture {
                                        selectedSession = session
                                        showingSessionDetail = true
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(language == .portuguese ? "Histórico de Sessões" : "Session History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingSessionDetail) {
            if let session = selectedSession {
                SessionDetailView(session: session, language: language, dataManager: dataManager)
            }
        }
    }
}

struct SessionHistoryRow: View {
    let session: SessionData
    let language: AppLanguage
    let dataManager: MedicalDatabaseManager

    private var diseaseName: String {
        if let diseaseId = Int(session.patientCaseId),
           let disease = dataManager.diseases.first(where: { $0.id == diseaseId }) {
            return disease.getDisplayName(language)
        }
        return language == .portuguese ? "Condição Desconhecida" : "Unknown Condition"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(session.isCorrect ? Color.green : Color.red)
                    .frame(width: 50, height: 50)

                Image(systemName: session.isCorrect ? "checkmark" : "xmark")
                    .foregroundColor(.white)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(diseaseName)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(Int(session.duration / 60))m", systemImage: "clock")
                    Label("\(session.questionsAsked)", systemImage: "message")
                    Text(session.difficulty.displayName(language: language))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(4)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text(session.startTime, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct SessionDetailView: View {
    let session: SessionData
    let language: AppLanguage
    let dataManager: MedicalDatabaseManager
    @Environment(\.dismiss) private var dismiss

    private var diseaseName: String {
        if let diseaseId = Int(session.patientCaseId),
           let disease = dataManager.diseases.first(where: { $0.id == diseaseId }) {
            return disease.getDisplayName(language)
        }
        return language == .portuguese ? "Condição Desconhecida" : "Unknown Condition"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Result Banner
                    HStack {
                        Image(systemName: session.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(session.isCorrect ? .green : .red)

                        VStack(alignment: .leading) {
                            Text(session.isCorrect ?
                                 (language == .portuguese ? "Diagnóstico Correto!" : "Correct Diagnosis!") :
                                 (language == .portuguese ? "Diagnóstico Incorreto" : "Incorrect Diagnosis"))
                                .font(.title2)
                                .bold()

                            Text(diseaseName)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(session.isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(12)

                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SessionStatCard(
                            icon: "clock",
                            value: formatDuration(session.duration),
                            label: language == .portuguese ? "Duração" : "Duration",
                            color: .blue
                        )

                        SessionStatCard(
                            icon: "message",
                            value: "\(session.questionsAsked)",
                            label: language == .portuguese ? "Perguntas" : "Questions",
                            color: .purple
                        )

                        SessionStatCard(
                            icon: "testtube.2",
                            value: "\(session.testsOrdered)",
                            label: language == .portuguese ? "Testes" : "Tests",
                            color: .orange
                        )

                        SessionStatCard(
                            icon: "lightbulb",
                            value: "\(session.hintsUsed)",
                            label: language == .portuguese ? "Dicas" : "Hints",
                            color: .yellow
                        )
                    }

                    // Diagnosis Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(language == .portuguese ? "Seu Diagnóstico" : "Your Diagnosis")
                            .font(.headline)

                        Text(session.finalDiagnosis.isEmpty ? (language == .portuguese ? "Nenhum diagnóstico fornecido" : "No diagnosis provided") : session.finalDiagnosis)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Treatment Section (if available)
                    if !session.treatmentPrescribed.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(language == .portuguese ? "Tratamento Prescrito" : "Treatment Prescribed")
                                    .font(.headline)

                                Spacer()

                                Text("\(Int(session.treatmentScore * 100))%")
                                    .font(.headline)
                                    .foregroundColor(session.treatmentIsAcceptable ? .green : .orange)
                            }

                            Text(session.treatmentPrescribed)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }

                    // Confidence Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(language == .portuguese ? "Nível de Confiança" : "Confidence Level")
                            .font(.headline)

                        HStack {
                            ForEach(1..<6) { index in
                                Image(systemName: index <= Int(session.confidenceScore * 5) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }

                            Text("\(Int(session.confidenceScore * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Date and Difficulty
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(session.startTime.formatted(date: .long, time: .shortened), systemImage: "calendar")
                            Spacer()
                            Text(session.difficulty.displayName(language: language))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle(language == .portuguese ? "Detalhes da Sessão" : "Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Close") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

struct SessionStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .bold()

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Difficulty Picker View
struct DifficultyPickerView: View {
    @Binding var selectedMode: TrainingMode
    @Binding var selectedDifficulty: DifficultyLevel
    let language: AppLanguage
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Only show difficulty selection for Clinical mode
                    // (Basic mode bypasses this view entirely)
                    VStack(spacing: 8) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)

                        Text(language == .portuguese ? "Escolha a Dificuldade" : "Choose Difficulty")
                            .font(.title2)
                            .bold()

                        Text(language == .portuguese ?
                             "Selecione o nível de desafio" :
                             "Select the challenge level")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Difficulty Options (only for Clinical mode)
                    VStack(spacing: 16) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                            DifficultyOptionCard(
                                difficulty: difficulty,
                                language: language,
                                isSelected: selectedDifficulty == difficulty,
                                action: {
                                    selectedDifficulty = difficulty
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Start Button
                    Button(action: {
                        onStart()
                    }) {
                        Text(language == .portuguese ? "Iniciar Sessão" : "Start Session")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(language == .portuguese ? "Escolha a Dificuldade" : "Choose Difficulty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Cancelar" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct DifficultyOptionCard: View {
    let difficulty: DifficultyLevel
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    private func getDescription() -> String {
        switch difficulty {
        case .beginner:
            return language == .portuguese ?
                "Paciente cooperativo, sintomas claros, fornece informações prontamente" :
                "Cooperative patient, clear symptoms, readily provides information"
        case .intermediate:
            return language == .portuguese ?
                "Paciente padrão, sintomas típicos, pode precisar de perguntas direcionadas" :
                "Standard patient, typical symptoms, may need targeted questions"
        case .advanced:
            return language == .portuguese ?
                "Paciente desafiador, apresentação atípica, exige habilidades avançadas" :
                "Challenging patient, atypical presentation, requires advanced skills"
        case .expert:
            return language == .portuguese ?
                "Paciente complexo, sintomas vagos, múltiplas possibilidades diagnósticas" :
                "Complex patient, vague symptoms, multiple diagnostic possibilities"
        }
    }

    private func getIcon() -> String {
        switch difficulty {
        case .beginner: return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        case .expert: return "star.circle.fill"
        }
    }

    private func getColor() -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: getIcon())
                    .font(.system(size: 40))
                    .foregroundColor(getColor())

                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.displayName(language: language))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(getDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
        .navigationViewStyle(.stack)
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

// MARK: - Personality Adjustment View
struct PersonalityAdjustmentView: View {
    @Binding var patientCase: PatientCase
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    @State private var cooperation: Double
    @State private var painTolerance: Double
    @State private var anxiety: Double
    @State private var trust: Double
    @State private var memoryClarity: Double

    init(patientCase: Binding<PatientCase>, language: AppLanguage) {
        self._patientCase = patientCase
        self.language = language

        // Initialize sliders with current values
        self._cooperation = State(initialValue: patientCase.wrappedValue.personality.cooperationLevel)
        self._painTolerance = State(initialValue: patientCase.wrappedValue.personality.painTolerance)
        self._anxiety = State(initialValue: patientCase.wrappedValue.personality.anxietyLevel)
        self._trust = State(initialValue: patientCase.wrappedValue.personality.trustLevel)
        self._memoryClarity = State(initialValue: patientCase.wrappedValue.personality.memoryClarity)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text(language == .portuguese ?
                             "Ajustar Personalidade do Paciente" :
                             "Adjust Patient Personality")
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)

                        Text(language == .portuguese ?
                             "Modifique os traços de personalidade para ver como o paciente responde de forma diferente" :
                             "Modify personality traits to see how the patient responds differently")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    VStack(spacing: 20) {
                        PersonalitySlider(
                            title: language == .portuguese ? "Cooperação" : "Cooperation",
                            description: language == .portuguese ?
                                "Quanto o paciente colabora com o exame" :
                                "How cooperative the patient is during examination",
                            value: $cooperation,
                            color: .blue,
                            lowLabel: language == .portuguese ? "Resistente" : "Resistant",
                            highLabel: language == .portuguese ? "Cooperativo" : "Cooperative"
                        )

                        PersonalitySlider(
                            title: language == .portuguese ? "Tolerância à Dor" : "Pain Tolerance",
                            description: language == .portuguese ?
                                "Como o paciente lida com desconforto físico" :
                                "How the patient handles physical discomfort",
                            value: $painTolerance,
                            color: .orange,
                            lowLabel: language == .portuguese ? "Sensível" : "Sensitive",
                            highLabel: language == .portuguese ? "Resistente" : "Resilient"
                        )

                        PersonalitySlider(
                            title: language == .portuguese ? "Nível de Ansiedade" : "Anxiety Level",
                            description: language == .portuguese ?
                                "Quanto o paciente está nervoso ou preocupado" :
                                "How nervous or worried the patient is",
                            value: $anxiety,
                            color: .red,
                            lowLabel: language == .portuguese ? "Calmo" : "Calm",
                            highLabel: language == .portuguese ? "Ansioso" : "Anxious"
                        )

                        PersonalitySlider(
                            title: language == .portuguese ? "Confiança" : "Trust Level",
                            description: language == .portuguese ?
                                "Quanto o paciente confia no profissional" :
                                "How much the patient trusts the healthcare provider",
                            value: $trust,
                            color: .green,
                            lowLabel: language == .portuguese ? "Desconfiado" : "Suspicious",
                            highLabel: language == .portuguese ? "Confiante" : "Trusting"
                        )

                        PersonalitySlider(
                            title: language == .portuguese ? "Clareza da Memória" : "Memory Clarity",
                            description: language == .portuguese ?
                                "Quão bem o paciente lembra dos detalhes" :
                                "How well the patient remembers details",
                            value: $memoryClarity,
                            color: .purple,
                            lowLabel: language == .portuguese ? "Confuso" : "Confused",
                            highLabel: language == .portuguese ? "Claro" : "Clear"
                        )
                    }

                    // Apply Button
                    Button(action: {
                        applyChanges()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text(language == .portuguese ? "Aplicar Mudanças" : "Apply Changes")
                        }
                        .foregroundColor(.white)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }

                    // Reset Button
                    Button(action: {
                        resetToOriginal()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(language == .portuguese ? "Restaurar Original" : "Reset to Original")
                        }
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle(language == .portuguese ? "Personalidade" : "Personality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language == .portuguese ? "Cancelar" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func applyChanges() {
        var updatedPersonality = patientCase.personality
        updatedPersonality.cooperationLevel = cooperation
        updatedPersonality.painTolerance = painTolerance
        updatedPersonality.anxietyLevel = anxiety
        updatedPersonality.trustLevel = trust
        updatedPersonality.memoryClarity = memoryClarity

        patientCase.personality = updatedPersonality
    }

    private func resetToOriginal() {
        // Reset sliders to original values
        cooperation = patientCase.personality.cooperationLevel
        painTolerance = patientCase.personality.painTolerance
        anxiety = patientCase.personality.anxietyLevel
        trust = patientCase.personality.trustLevel
        memoryClarity = patientCase.personality.memoryClarity
    }
}

struct PersonalitySlider: View {
    let title: String
    let description: String
    @Binding var value: Double
    let color: Color
    let lowLabel: String
    let highLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text(lowLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(value * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)

                    Spacer()

                    Text(highLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Slider(value: $value, in: 0.0...1.0)
                    .accentColor(color)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Patient Summary Card
struct PatientSummaryCard: View {
    let patient: PatientCase
    @Binding var isExpanded: Bool
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            // Header - Always visible
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                        .font(.title3)

                    Text(language == .portuguese ? "Resumo do Paciente" : "Patient Summary")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
            }
            .buttonStyle(PlainButtonStyle())

            // Expandable Content
            if isExpanded {
                VStack(spacing: 16) {
                    // Vital Signs Section
                    SummarySection(
                        title: language == .portuguese ? "Sinais Vitais" : "Vital Signs",
                        icon: "heart.fill",
                        color: .red,
                        content: [
                            "BP: 120/80 mmHg",
                            "HR: 72 bpm",
                            "Temp: 98.6°F (37°C)",
                            "RR: 16/min"
                        ]
                    )

                    // Current Symptoms
                    if !patient.presentingSymptoms.isEmpty {
                        SummarySection(
                            title: language == .portuguese ? "Sintomas Atuais" : "Current Symptoms",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            content: Array(patient.presentingSymptoms.prefix(3).map {
                                $0.getText(language)
                            })
                        )
                    }

                    // Risk Factors
                    SummarySection(
                        title: language == .portuguese ? "Fatores de Risco" : "Risk Factors",
                        icon: "shield.fill",
                        color: .purple,
                        content: generateRiskFactors()
                    )

                    // Allergies
                    SummarySection(
                        title: language == .portuguese ? "Alergias" : "Allergies",
                        icon: "bandage.fill",
                        color: .green,
                        content: generateAllergies()
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func generateRiskFactors() -> [String] {
        let commonRisks = language == .portuguese ? [
            "Histórico familiar",
            "Sedentarismo",
            "Stress ocupacional"
        ] : [
            "Family history",
            "Sedentary lifestyle",
            "Occupational stress"
        ]
        return commonRisks
    }

    private func generateAllergies() -> [String] {
        let commonAllergies = language == .portuguese ? [
            "NKDA (Sem alergias conhecidas)",
            "Penicilina - erupção cutânea"
        ] : [
            "NKDA (No known allergies)",
            "Penicillin - skin rash"
        ]
        return [commonAllergies.randomElement()!]
    }
}

struct SummarySection: View {
    let title: String
    let icon: String
    let color: Color
    let content: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(content, id: \.self) { item in
                    Text("• \(item)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Difficulty Rating View
struct DifficultyRatingView: View {
    let difficulty: Int // 1-5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= difficulty ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundColor(index <= difficulty ? difficultyColor : Color.gray.opacity(0.3))
            }
        }
    }

    private var difficultyColor: Color {
        switch difficulty {
        case 1: return .green
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Case Difficulty Rating Manager (Task 3.4)
/// Stores and retrieves student difficulty ratings for each disease case.
/// Ratings are persisted in UserDefaults as [diseaseName: [Int]] (1–5 scale).
class CaseDifficultyRatingManager: ObservableObject {
    static let shared = CaseDifficultyRatingManager()

    private let storageKey = "CaseDifficultyRatings"

    /// diseaseName (English) → array of ratings submitted by this student
    @Published private(set) var ratings: [String: [Int]] = [:]

    private init() { load() }

    /// Submit a 1–5 difficulty rating for a disease case.
    func submitRating(for diseaseName: String, rating: Int) {
        guard rating >= 1 && rating <= 5 else { return }
        ratings[diseaseName, default: []].append(rating)
        save()
    }

    /// Average rating for a disease, or nil if no ratings exist.
    func averageRating(for diseaseName: String) -> Double? {
        guard let arr = ratings[diseaseName], !arr.isEmpty else { return nil }
        return Double(arr.reduce(0, +)) / Double(arr.count)
    }

    /// Number of ratings submitted for a disease.
    func ratingCount(for diseaseName: String) -> Int {
        return ratings[diseaseName]?.count ?? 0
    }

    /// Returns true if this disease is appropriately challenging for the given accuracy level.
    /// - accuracy: 0.0–1.0 (student's overall accuracy)
    func isRecommended(for diseaseName: String, accuracy: Double) -> Bool {
        guard let avg = averageRating(for: diseaseName) else { return false }
        let target: Double
        if accuracy < 0.4 {
            target = 2.0 // Recommend easy cases (rated ≤ 2)
        } else if accuracy < 0.7 {
            target = 3.0 // Recommend moderate cases (rated ~3)
        } else {
            target = 4.0 // Recommend hard cases (rated ≥ 4)
        }
        return abs(avg - target) <= 1.0
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data) else { return }
        ratings = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - iOS 16/17 compatible onChange helper (task 12.1)
extension View {
    /// Drop-in replacement for the deprecated `.onChange(of:perform:)` form.
    /// Uses the non-deprecated iOS 17 two-argument form when available; falls back to the
    /// original form on iOS 16 (where it is not deprecated and works correctly).
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

// MARK: - Adaptive Layout Helpers (iPad full-screen + larger text)
struct AdaptiveFontModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let phoneFont: Font
    let padFont: Font
    func body(content: Content) -> some View {
        content.font(sizeClass == .regular ? padFont : phoneFont)
    }
}

extension View {
    func adaptiveCaption() -> some View { modifier(AdaptiveFontModifier(phoneFont: .caption, padFont: .footnote)) }
    func adaptiveCaption2() -> some View { modifier(AdaptiveFontModifier(phoneFont: .caption2, padFont: .caption)) }
    func adaptiveHeadline() -> some View { modifier(AdaptiveFontModifier(phoneFont: .headline, padFont: .title3)) }
    func adaptiveSubheadline() -> some View { modifier(AdaptiveFontModifier(phoneFont: .subheadline, padFont: .callout)) }
}

struct AdaptivePaddingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let edges: Edge.Set
    let phoneLength: CGFloat?
    func body(content: Content) -> some View {
        let length = sizeClass == .regular ? (phoneLength ?? 16) * 1.5 : phoneLength
        if let length { content.padding(edges, length) }
        else { content.padding(edges) }
    }
}

extension View {
    func adaptivePadding(_ edges: Edge.Set = .all, _ phoneLength: CGFloat? = nil) -> some View {
        modifier(AdaptivePaddingModifier(edges: edges, phoneLength: phoneLength))
    }

    /// Makes sheet presentations full-page on iPad instead of narrow popovers.
    /// On iPhone (compact): behaves as `.presentationDetents([.large])`.
    func adaptiveSheet() -> some View {
        self.presentationDetents([.large])
    }
}

/// A sheet that becomes a fullScreenCover on iPad (regular size class).
/// On iPhone, behaves as a standard `.sheet` with `.presentationDetents([.large])`.
/// On iPad, uses `.fullScreenCover` for full-width presentation.
/// Sheet content views should include a "Done" / dismiss button for iPad.
struct AdaptiveSheetModifier<SheetContent: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?
    @ViewBuilder let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content.fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) {
                sheetContent()
            }
        } else {
            content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                sheetContent()
                    .presentationDetents([.large])
            }
        }
    }
}

// MARK: - Item-based adaptive sheet (passes data directly — fixes iPad fullScreenCover state bug)
struct AdaptiveSheetItemModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var item: Item?
    var onDismiss: (() -> Void)?
    @ViewBuilder let sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content.fullScreenCover(item: $item, onDismiss: onDismiss) { value in
                sheetContent(value)
            }
        } else {
            content.sheet(item: $item, onDismiss: onDismiss) { value in
                sheetContent(value)
                    .presentationDetents([.large])
            }
        }
    }
}

extension View {
    func adaptiveFullSheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(AdaptiveSheetModifier(isPresented: isPresented, onDismiss: onDismiss, sheetContent: content))
    }

    func adaptiveFullSheetItem<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        modifier(AdaptiveSheetItemModifier(item: item, onDismiss: onDismiss, sheetContent: content))
    }
}
