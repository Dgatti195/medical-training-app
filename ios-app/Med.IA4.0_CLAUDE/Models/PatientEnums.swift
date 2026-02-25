import Foundation

// MARK: - App Language

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

// MARK: - User Gender

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

// MARK: - Communication Style

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
