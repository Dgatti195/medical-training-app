import Foundation

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
        language: AppLanguage,
        difficulty: DifficultyLevel
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

        let systemPrompt = createPatientSystemPrompt(patientCase: patientCase, language: language, difficulty: difficulty)

        let conversationContext = conversationHistory.filter { !$0.isTest }.map { turn in
            "Doctor: \(turn.question)\nPatient: \(turn.response)"
        }.joined(separator: "\n\n")

        let languageReminder = language == .portuguese ?
            "LEMBRE-SE: Responda em PORTUGUÊS BRASILEIRO apenas! NUNCA diga 'estou apresentando'. Descreva seus sintomas com suas próprias palavras simples." :
            "REMEMBER: Respond in ENGLISH only! NEVER say 'I'm experiencing'. Describe your symptoms in your own simple words."

        let userContent: String
        if conversationContext.isEmpty {
            userContent = "\(languageReminder)\n\nDoctor: \(question)\n\nPatient:"
        } else {
            userContent = "\(languageReminder)\n\nPrevious conversation:\n\(conversationContext)\n\nDoctor: \(question)\n\nPatient:"
        }

        do {
            // Use Sonnet for patient responses — Haiku ignores natural-speech instructions
        let response = try await makeAPIRequest(prompt: userContent, apiKey: apiKey, systemPrompt: systemPrompt, maxTokens: 150, model: "claude-sonnet-4-6")
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
    
    private func createPatientSystemPrompt(patientCase: PatientCase, language: AppLanguage, difficulty: DifficultyLevel) -> String {
        let demographics = patientCase.demographics
        // Pre-translate symptoms into natural patient language so the AI echoes natural speech
        let naturalSymptoms = patientCase.presentingSymptoms
            .map { symptomToNaturalLanguage($0.getText(language), language: language) }
            .joined(separator: ", ")

        if language == .portuguese {
            return """
            Você é \(demographics.name), \(demographics.age) anos, \(demographics.gender). Você está visitando o médico.

            COMO VOCÊ ESTÁ SE SENTINDO:
            \(naturalSymptoms)

            REGRAS:
            1. Fale como uma pessoa comum. Use estas palavras exatas acima para descrever seus sintomas.
            2. Responda em 1-2 frases curtas.
            3. Para "onde dói" → diga uma parte do corpo. Para "há quanto tempo" → dê um período de tempo.
            4. Você NÃO sabe o nome da sua doença.
            5. Responda APENAS em PORTUGUÊS BRASILEIRO.
            \(getDifficultyModifier(difficulty: difficulty, language: .portuguese))
            """
        } else {
            return """
            You are \(demographics.name), \(demographics.age) years old, \(demographics.gender). You are visiting the doctor.

            HOW YOU ARE FEELING:
            \(naturalSymptoms)

            RULES:
            1. Speak like a regular person. Use these exact descriptions above when talking about symptoms.
            2. Answer in 1-2 short sentences.
            3. For "where does it hurt" → name a body part. For "how long" → give a time period.
            4. You do NOT know the name of your disease.
            5. Respond in ENGLISH only.
            \(getDifficultyModifier(difficulty: difficulty, language: .english))
            """
        }
    }

    /// Translates a medical symptom name into natural patient language so the AI
    /// has plain-English/Portuguese text to echo back instead of medical terms.
    private func symptomToNaturalLanguage(_ symptom: String, language: AppLanguage) -> String {
        let s = symptom.lowercased().trimmingCharacters(in: .whitespaces)

        if language == .portuguese {
            let map: [(String, String)] = [
                ("icterícia", "pele e olhos amarelados"),
                ("jaundice", "pele e olhos amarelados"),
                ("náusea", "enjoado(a)"),
                ("nausea", "enjoado(a)"),
                ("fadiga", "muito cansado(a), sem energia"),
                ("fatigue", "muito cansado(a), sem energia"),
                ("febre", "com febre"),
                ("fever", "com febre"),
                ("dor de cabeça", "dor de cabeça"),
                ("headache", "dor de cabeça"),
                ("tosse", "tossindo"),
                ("cough", "tossindo"),
                ("falta de ar", "falta de ar"),
                ("shortness of breath", "falta de ar"),
                ("dor no peito", "dor no peito"),
                ("chest pain", "dor no peito"),
                ("dor abdominal", "dor na barriga"),
                ("abdominal pain", "dor na barriga"),
                ("vômito", "vomitando"),
                ("vomiting", "vomitando"),
                ("diarreia", "diarreia"),
                ("diarrhea", "diarreia"),
                ("perda de apetite", "sem vontade de comer"),
                ("loss of appetite", "sem vontade de comer"),
                ("perda de peso", "perdendo peso"),
                ("weight loss", "perdendo peso"),
                ("inchaço", "inchaço"),
                ("edema", "inchaço"),
                ("tontura", "tontura"),
                ("dizziness", "tontura"),
                ("dor nas costas", "dor nas costas"),
                ("back pain", "dor nas costas"),
                ("dor nas articulações", "dor nas juntas"),
                ("joint pain", "dor nas juntas"),
                ("coceira", "muita coceira"),
                ("itching", "muita coceira"),
                ("pruritus", "muita coceira"),
                ("suor noturno", "suando muito de noite"),
                ("night sweats", "suando muito de noite"),
                ("calafrios", "calafrios"),
                ("chills", "calafrios"),
                ("dor de garganta", "garganta doendo"),
                ("sore throat", "garganta doendo"),
                ("dores musculares", "meu corpo todo doendo"),
                ("muscle aches", "meu corpo todo doendo"),
                ("myalgia", "meu corpo todo doendo"),
                ("constipação", "dificuldade para ir ao banheiro"),
                ("constipation", "dificuldade para ir ao banheiro"),
                ("urina escura", "urina muito escura"),
                ("dark urine", "urina muito escura"),
                ("fezes claras", "fezes muito claras, quase brancas"),
                ("light colored stools", "fezes muito claras, quase brancas"),
                ("palpitações", "coração acelerado"),
                ("palpitations", "coração acelerado"),
                ("visão turva", "visão embaçada"),
                ("blurred vision", "visão embaçada"),
                ("fraqueza", "fraqueza"),
                ("weakness", "fraqueza"),
                ("confusão", "confuso(a)"),
                ("confusion", "confuso(a)"),
                ("sangue nas fezes", "sangue ao ir ao banheiro"),
                ("blood in stool", "sangue ao ir ao banheiro"),
            ]
            for (key, value) in map { if s.contains(key) { return value } }
            return s
        } else {
            let map: [(String, String)] = [
                ("jaundice", "yellow skin and eyes"),
                ("nausea", "feeling sick to my stomach"),
                ("fatigue", "feeling very tired with no energy"),
                ("fever", "running a fever"),
                ("headache", "having headaches"),
                ("cough", "coughing a lot"),
                ("shortness of breath", "having trouble breathing"),
                ("dyspnea", "getting out of breath easily"),
                ("chest pain", "pain in my chest"),
                ("abdominal pain", "pain in my belly"),
                ("vomiting", "throwing up"),
                ("diarrhea", "having diarrhea"),
                ("loss of appetite", "not wanting to eat"),
                ("weight loss", "losing weight without trying"),
                ("edema", "swelling in my legs"),
                ("swelling", "swelling"),
                ("dizziness", "feeling dizzy"),
                ("back pain", "pain in my back"),
                ("joint pain", "achy joints"),
                ("rash", "a rash on my skin"),
                ("itching", "really itchy skin"),
                ("pruritus", "really itchy skin"),
                ("night sweats", "sweating a lot at night"),
                ("chills", "having chills"),
                ("sore throat", "my throat hurts"),
                ("muscle aches", "my muscles ache all over"),
                ("myalgia", "my muscles ache all over"),
                ("constipation", "trouble going to the bathroom"),
                ("blood in stool", "blood when I go to the bathroom"),
                ("dark urine", "very dark urine"),
                ("light colored stools", "very pale, almost white stools"),
                ("frequent urination", "needing to pee a lot"),
                ("painful urination", "pain when I pee"),
                ("palpitations", "my heart racing or pounding"),
                ("blurred vision", "blurry vision"),
                ("difficulty swallowing", "trouble swallowing"),
                ("dysphagia", "trouble swallowing"),
                ("bloating", "feeling bloated"),
                ("heartburn", "heartburn"),
                ("weakness", "feeling weak"),
                ("numbness", "numbness and tingling"),
                ("tingling", "tingling in my limbs"),
                ("confusion", "feeling confused"),
                ("tremors", "shakiness in my hands"),
            ]
            for (key, value) in map { if s.contains(key) { return value } }
            return s
        }
    }

    private func getDifficultyModifier(difficulty: DifficultyLevel, language: AppLanguage) -> String {
        if language == .portuguese {
            switch difficulty {
            case .beginner:
                return """

                MODIFICADOR DE DIFICULDADE - INICIANTE:
                - Seja muito cooperativo e prestativo
                - Forneça informações claramente quando perguntado
                - Lembre-se bem de detalhes
                - Não exagere os sintomas
                """
            case .intermediate:
                return "" // Standard behavior
            case .advanced:
                return """

                MODIFICADOR DE DIFICULDADE - AVANÇADO:
                - Seja um pouco vago em suas respostas iniciais
                - O médico pode precisar perguntar mais de uma vez para obter detalhes
                - Você não se lembra bem de alguns detalhes menores
                - Não forneça informações que não foram perguntadas diretamente
                """
            case .expert:
                return """

                MODIFICADOR DE DIFICULDADE - ESPECIALISTA:
                - Dê respostas vagas e não específicas inicialmente
                - Minimize ou não mencione alguns sintomas até ser perguntado especificamente
                - Tenha dificuldade em lembrar quando exatamente os sintomas começaram
                - O médico precisará fazer perguntas muito específicas para obter detalhes
                - Não forneça informações extras voluntariamente
                """
            }
        } else {
            switch difficulty {
            case .beginner:
                return """

                DIFFICULTY MODIFIER - BEGINNER:
                - Be very cooperative and helpful
                - Provide information clearly when asked
                - Remember details well
                - Don't exaggerate symptoms
                """
            case .intermediate:
                return "" // Standard behavior
            case .advanced:
                return """

                DIFFICULTY MODIFIER - ADVANCED:
                - Be somewhat vague in your initial responses
                - The doctor may need to ask more than once for details
                - You don't remember some minor details clearly
                - Don't volunteer information that hasn't been directly asked about
                """
            case .expert:
                return """

                DIFFICULTY MODIFIER - EXPERT:
                - Give vague, non-specific answers initially
                - Minimize or don't mention some symptoms until specifically asked
                - Have difficulty remembering exactly when symptoms started
                - The doctor will need to ask very specific questions to get details
                - Don't volunteer extra information
                """
            }
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
            
            IMPORTANTE: Forneça APENAS os resultados objetivos do exame em PORTUGUÊS BRASILEIRO.
            NUNCA use inglês, francês ou outro idioma - apenas português brasileiro.
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
            
            IMPORTANT: Provide ONLY objective test results in ENGLISH.
            NEVER use French, Spanish, Portuguese, or other languages - only English.
            DO NOT mention possible diagnoses or interpretations.
            DO NOT say "consistent with" or "suggests" any condition.
            Only report objective clinical findings.
            Keep responses concise and clinical.
            """
        }
    }
    
    private func makeAPIRequest(prompt: String, apiKey: String, systemPrompt: String? = nil, maxTokens: Int = 150, model: String = "claude-haiku-4-5-20251001") async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        if let systemPrompt = systemPrompt {
            requestBody["system"] = systemPrompt
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid response", code: 0, userInfo: nil)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            if httpResponse.statusCode == 401 {
                throw NSError(domain: "Unauthorized", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please check your API key."])
            }
            throw NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorBody)"])
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = jsonResponse["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw NSError(domain: "Failed to parse response", code: 0, userInfo: nil)
        }

        // Remove asterisks and text between them from the response
        let cleanedText = removeAsterisks(from: text)
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeAsterisks(from text: String) -> String {
        // Remove text enclosed in asterisks (e.g., *action* or *description*)
        var result = text

        // Remove paired asterisks and content between them
        result = result.replacingOccurrences(of: "\\*[^*]+\\*", with: "", options: .regularExpression)

        // Remove any remaining single asterisks
        result = result.replacingOccurrences(of: "*", with: "")

        // Remove parenthetical meta-descriptions (e.g., (Respondo de forma emotiva, demonstrando minha ansiedade))
        // Pattern matches common meta-commentary in both Portuguese and English
        let metaPatterns = [
            "\\(Respondo[^)]+\\)",  // Portuguese: (Respondo...)
            "\\(I respond[^)]+\\)", // English: (I respond...)
            "\\(Demonstro[^)]+\\)", // Portuguese: (Demonstro...)
            "\\(I show[^)]+\\)",    // English: (I show...)
            "\\(Falo[^)]+\\)",      // Portuguese: (Falo...)
            "\\(I speak[^)]+\\)",   // English: (I speak...)
            "\\(Digo[^)]+\\)",      // Portuguese: (Digo...)
            "\\(I say[^)]+\\)"      // English: (I say...)
        ]

        for pattern in metaPatterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // Clean up extra whitespace that may be left behind
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)

        // Clean up leading/trailing spaces on each line
        result = result.trimmingCharacters(in: .whitespaces)

        return result
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
        // Use pre-translated natural symptom descriptions for fallback responses too
        let naturalSymptom = patientCase.presentingSymptoms
            .map { symptomToNaturalLanguage($0.getText(language), language: language) }
            .first ?? (language == .portuguese ? "me sentindo mal" : "not feeling well")
        let naturalRandom = patientCase.presentingSymptoms
            .map { symptomToNaturalLanguage($0.getText(language), language: language) }
            .randomElement() ?? (language == .portuguese ? "me sentindo mal" : "not feeling well")

        if language == .portuguese {
            if lowercaseQuestion.contains("sentindo") || lowercaseQuestion.contains("como está") || lowercaseQuestion.contains("traz") || lowercaseQuestion.contains("problema") {
                return "Não estou me sentindo bem. Estou \(naturalSymptom)."
            }
            if lowercaseQuestion.contains("dor") || lowercaseQuestion.contains("onde") {
                return "Tenho sentido dor. É bem desconfortável."
            }
            if lowercaseQuestion.contains("quando") || lowercaseQuestion.contains("tempo") || lowercaseQuestion.contains("quanto") {
                return "Os sintomas começaram há alguns dias e não estão melhorando."
            }
            return "Estou \(naturalRandom)."
        } else {
            if lowercaseQuestion.contains("bring") || lowercaseQuestion.contains("feel") || lowercaseQuestion.contains("how") || lowercaseQuestion.contains("wrong") || lowercaseQuestion.contains("today") {
                return "I've been \(naturalSymptom). It started a few days ago."
            }
            if lowercaseQuestion.contains("pain") || lowercaseQuestion.contains("hurt") || lowercaseQuestion.contains("where") {
                return "It hurts right here in my abdomen area. Pretty uncomfortable."
            }
            if lowercaseQuestion.contains("when") || lowercaseQuestion.contains("long") || lowercaseQuestion.contains("how long") {
                return "A few days now. It started gradually and hasn't gotten better."
            }
            return "I've been \(naturalRandom)."
        }
    }
    
    // MARK: - Basic Mode API Methods

    /// Detects which standard anamnesis question the student asked. Returns the matching question ID or nil.
    func detectQuestion(userQuestion: String, questionDatabase: AnamneseQuestionDatabase, language: AppLanguage) async -> Int? {
        guard let apiKey = APIKeyManager.shared.getAPIKey() else { return nil }

        let prompt = """
        You are a medical education assistant. A medical student asked a question during anamnesis.
        Identify which standard anamnesis question they are asking from the list below.
        Be LENIENT — accept paraphrased, informal, or translated versions of the standard questions.
        Common opening questions like "What brings you in today?", "What is your name?", "How old are you?" should always match.

        STUDENT QUESTION: "\(userQuestion)"

        STANDARD ANAMNESIS QUESTIONS:
        \(questionDatabase.allQuestions.map { "\($0.id): \($0.getText(language))" }.joined(separator: "\n"))

        Return ONLY the question ID number (e.g., "101") that best matches the student's question.
        If truly no match exists, return "0".
        Return nothing else - just the number.
        """

        do {
            let response = try await makeAPIRequest(prompt: prompt, apiKey: apiKey, maxTokens: 50)
            let questionId = Int(response.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            return questionId == 0 ? nil : questionId
        } catch {
            return nil
        }
    }

    /// Generates a brief patient response for Basic Mode anamnesis training.
    func generateBasicModeResponse(question: String, patientCase: PatientCase?, language: AppLanguage) async throws -> String {
        guard let apiKey = APIKeyManager.shared.getAPIKey() else {
            throw NSError(domain: "APIKey", code: 1, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }

        let chiefComplaints = patientCase?.presentingSymptoms.filter { $0.isChiefComplaint } ?? []
        let chiefComplaintText = chiefComplaints.isEmpty ?
            patientCase?.presentingSymptoms.first?.getText(language) ?? "" :
            chiefComplaints.first?.getText(language) ?? ""

        let patientContext = """
        Patient name: \(patientCase?.demographics.name ?? "Patient")
        Age: \(patientCase?.demographics.age ?? 0) years old
        Gender: \(patientCase?.demographics.gender ?? "")
        Main complaint: \(chiefComplaintText)
        """

        let prompt = """
        You are a patient in a medical anamnesis simulation. Answer the student's question naturally and briefly.

        RULES:
        1. Answer in \(language == .portuguese ? "Brazilian Portuguese" : "English") only
        2. Keep answers SHORT — 1-2 sentences at most (a few words for simple facts, one sentence for descriptions)
        3. Speak as a regular non-medical person — use everyday language, not medical jargon
        4. For identification questions (name, age, birthplace) give direct factual answers
        5. For complaint questions describe how you feel in plain words

        PATIENT CONTEXT:
        \(patientContext)

        STUDENT QUESTION: "\(question)"

        Examples of CORRECT responses:
        - "Maria Silva" (for name)
        - "32 years old" (for age)
        - "I've been having chest pain and a fever for the past two days"
        - "It hurts right here, in the middle of my chest"
        - "About three days now"
        - "Yes, I'm allergic to penicillin"
        - "No, I don't smoke"

        Answer naturally and briefly:
        """

        let response = try await makeAPIRequest(prompt: prompt, apiKey: apiKey, maxTokens: 60)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
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
