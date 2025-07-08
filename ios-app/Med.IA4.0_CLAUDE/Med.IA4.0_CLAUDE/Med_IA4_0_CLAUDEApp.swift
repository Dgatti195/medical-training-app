import SwiftUI
import Foundation
import SQLite3

// MARK: - Define SQLITE_TRANSIENT constant
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

// MARK: - Patient Demographics (Runtime Generated)
struct PatientDemographics {
    let age: Int
    let gender: String
    let ethnicity: String
    let name: String
    let height: String
    let weight: String
    
    static func generateRandom(language: AppLanguage) -> PatientDemographics {
        let ages = Array(18...85)
        let genders = language == .portuguese ? ["masculino", "feminino"] : ["male", "female"]
        
        let maleNames = language == .portuguese ?
            ["Carlos Santos", "João Pereira", "Ricardo Lima", "Fernando Costa", "André Silva", "Paulo Oliveira"] :
            ["Michael Chen", "David Kim", "James Smith", "Robert Johnson", "Ahmed Hassan", "Carlos Rodriguez"]
        
        let femaleNames = language == .portuguese ?
            ["Ana Silva", "Maria Oliveira", "Fernanda Costa", "Patrícia Souza", "Juliana Lima", "Carla Santos"] :
            ["Sarah Johnson", "Maria Rodriguez", "Jennifer Smith", "Rebecca Martinez", "Lisa Wong", "Amanda Davis"]
        
        let selectedGender = genders.randomElement()!
        let isFemale = selectedGender == (language == .portuguese ? "feminino" : "female")
        let names = isFemale ? femaleNames : maleNames
        
        let ethnicities = language == .portuguese ?
            ["Branco", "Pardo", "Negro", "Asiático", "Indígena"] :
            ["Caucasian", "Hispanic", "African American", "Asian", "Native American", "Middle Eastern"]
        
        return PatientDemographics(
            age: ages.randomElement()!,
            gender: selectedGender,
            ethnicity: ethnicities.randomElement()!,
            name: names.randomElement()!,
            height: generateRandomHeight(),
            weight: generateRandomWeight()
        )
    }
    
    private static func generateRandomHeight() -> String {
        let heightCm = Int.random(in: 150...195)
        let heightInCm = Double(heightCm)
        
        // Convert to feet and inches
        let totalInches = heightInCm / 2.54
        let feet = Int(totalInches / 12.0)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12.0))
        
        return String(format: "%d'%d\" (%d cm)", feet, inches, heightCm)
    }
    
    private static func generateRandomWeight() -> String {
        let weightKg = Int.random(in: 45...120)
        let weightInKg = Double(weightKg)
        let weightInLbs = weightInKg * 2.20462
        
        return String(format: "%.0f lbs (%.0f kg)", weightInLbs, weightInKg)
    }
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
        
        // Check if database already exists
        if !fileManager.fileExists(atPath: destinationURL.path) {
            // Try to copy from bundle
            if let bundlePath = Bundle.main.path(forResource: "medical_conditions", ofType: "sqlite") {
                let bundleURL = URL(fileURLWithPath: bundlePath)
                
                do {
                    try fileManager.copyItem(at: bundleURL, to: destinationURL)
                    print("✅ Database copied from bundle to documents directory")
                } catch {
                    print("❌ Error copying database: \(error)")
                    print("Will create fallback database with sample data")
                }
            } else {
                print("❌ Database file not found in bundle - will create fallback")
            }
        } else {
            print("✅ Database already exists in documents directory")
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
    let presentingSymptoms: [Symptom]
    let presentingFindings: [PhysicalFinding]
    let availableLabResults: [LabResult]
    let availableHints: [DiagnosticHint]
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
        print("Generated \(patientCases.count) consistent patient cases")
        
        // Verify patient cases have data
        let casesWithSymptoms = patientCases.filter { !$0.presentingSymptoms.isEmpty }
        print("Patient cases with symptoms: \(casesWithSymptoms.count)/\(patientCases.count)")
    }
    
    func getPatientCase(for disease: Disease) -> PatientCase? {
        return patientCases.first { $0.disease.id == disease.id }
    }
    
    func generatePatientCase(from disease: Disease, language: AppLanguage) -> PatientCase {
        let demographics = PatientDemographics.generateRandom(language: language)
        
        // Get chief complaints (prioritize these)
        let chiefComplaints = disease.symptoms
            .filter { $0.isChiefComplaint }
            .shuffled()
        
        // Get additional symptoms
        let additionalSymptoms = disease.symptoms
            .filter { !$0.isChiefComplaint }
            .shuffled()
        
        // Combine symptoms for presentation
        var presentingSymptoms: [Symptom] = []
        
        // Always include at least 1-2 chief complaints if available
        if !chiefComplaints.isEmpty {
            let numberOfChiefComplaints = min(chiefComplaints.count, Int.random(in: 1...2))
            presentingSymptoms.append(contentsOf: Array(chiefComplaints.prefix(numberOfChiefComplaints)))
        }
        
        // Add some additional symptoms
        if !additionalSymptoms.isEmpty {
            let numberOfAdditionalSymptoms = min(additionalSymptoms.count, Int.random(in: 1...3))
            presentingSymptoms.append(contentsOf: Array(additionalSymptoms.prefix(numberOfAdditionalSymptoms)))
        }
        
        // If no symptoms at all, this indicates a data issue
        if presentingSymptoms.isEmpty {
            print("⚠️ Warning: No symptoms found for disease: \(disease.nameEnglish)")
        }
        
        return PatientCase(
            disease: disease,
            demographics: demographics,
            presentingSymptoms: presentingSymptoms,
            presentingFindings: disease.physicalFindings,
            availableLabResults: disease.labResults,
            availableHints: disease.hints
        )
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

// MARK: - User Profile Manager
class UserProfileManager: ObservableObject {
    @Published var profile = UserProfile()
    @Published var currentLanguage: AppLanguage = .english
    
    private let userDefaults = UserDefaults.standard
    private let profileKey = "UserProfile"
    
    init() {
        loadProfile()
        currentLanguage = AppLanguage(rawValue: profile.selectedLanguage) ?? .english
    }
    
    func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            userDefaults.set(encoded, forKey: profileKey)
        }
    }
    
    func loadProfile() {
        if let data = userDefaults.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        }
    }
    
    func recordDiagnosis(disease: Disease, isCorrect: Bool, questionCount: Int, hintsUsed: Int, testsOrdered: Int) {
        profile.totalPatientsInterviewed += 1
        profile.totalDiagnosesAttempted += 1
        profile.hintsUsed += hintsUsed
        profile.testsOrdered += testsOrdered
        
        if isCorrect {
            profile.totalCorrectDiagnoses += 1
        }
        
        var categoryStats = profile.categoryPerformance[disease.category] ?? CategoryStats()
        if isCorrect {
            categoryStats.correct += 1
        } else {
            categoryStats.incorrect += 1
        }
        profile.categoryPerformance[disease.category] = categoryStats
        
        saveProfile()
    }
    
    func changeLanguage(_ language: AppLanguage) {
        currentLanguage = language
        profile.selectedLanguage = language.rawValue
        saveProfile()
    }
    
    func addStudyTime(_ time: TimeInterval) {
        profile.studyTime += time
        saveProfile()
    }
}

// MARK: - Conversation Models
struct ConversationTurn: Identifiable {
    let id = UUID()
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
}

// MARK: - Claude AI Service
class ClaudeAIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    @Published var isGeneratingResponse = false
    @Published var lastError: String?
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generatePatientResponse(
        question: String,
        patientCase: PatientCase,
        conversationHistory: [ConversationTurn],
        language: AppLanguage
    ) async -> String {
        
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
            let response = try await makeAPIRequest(prompt: fullPrompt)
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
            let response = try await makeAPIRequest(prompt: fullPrompt)
            return response
        } catch {
            return getTestFallbackResponse(testRequest: testRequest, patientCase: patientCase, language: language)
        }
    }
    
    private func createPatientSystemPrompt(patientCase: PatientCase, language: AppLanguage) -> String {
        let demographics = patientCase.demographics
        let disease = patientCase.disease
        let symptoms = patientCase.presentingSymptoms.map { $0.getText(language) }.joined(separator: ", ")
        
        if language == .portuguese {
            return """
            Você é um paciente de \(demographics.age) anos, \(demographics.gender), chamado \(demographics.name). Você está no hospital sendo entrevistado por um médico.
            
            CONDIÇÃO MÉDICA: \(disease.namePortuguese)
            SINTOMAS ATUAIS: \(symptoms)
            CATEGORIA: \(disease.category)
            SEVERIDADE: \(disease.severity)
            
            INSTRUÇÕES IMPORTANTES:
            - Responda APENAS como o paciente em português brasileiro
            - Você NÃO sabe o nome da sua condição médica - você só sabe os sintomas
            - Seja realista sobre seus sintomas e como se sente
            - Responda com preocupação apropriada para a severidade
            - Seja cooperativo mas não dê informações médicas que um paciente normal não saberia
            - Use linguagem simples, não termos médicos técnicos
            - Se perguntado sobre diagnóstico, diga que não sabe, só sabe como se sente
            - Seja consistente com sintomas já mencionados
            - Responda como uma pessoa real que está sofrendo com estes sintomas
            - Mantenha as respostas concisas (1-3 frases)
            """
        } else {
            return """
            You are a \(demographics.age)-year-old \(demographics.gender) patient named \(demographics.name). You are in the hospital being interviewed by a doctor.
            
            MEDICAL CONDITION: \(disease.nameEnglish)
            CURRENT SYMPTOMS: \(symptoms)
            CATEGORY: \(disease.category)
            SEVERITY: \(disease.severity)
            
            IMPORTANT INSTRUCTIONS:
            - Respond ONLY as the patient in English
            - You do NOT know the name of your medical condition - you only know your symptoms
            - Be realistic about your symptoms and how you feel
            - Respond with appropriate concern for the severity
            - Be cooperative but don't give medical information a normal patient wouldn't know
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
    
    private func makeAPIRequest(prompt: String) async throws -> String {
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

// MARK: - Main App
@main
struct MedicalDiagnosisApp: App {
    @StateObject private var userProfile = UserProfileManager()
    
    var body: some Scene {
        WindowGroup {
            if !UserDefaults.standard.bool(forKey: "hasSelectedLanguage") {
                LanguageSelectionView()
                    .environmentObject(userProfile)
            } else {
                ContentView()
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
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingProfile = false
    
    private let categories = ["All", "Gastrointestinal", "Neurological", "Respiratory", "Cardiovascular", "Endocrine"]
    
    var filteredDiseases: [Disease] {
        let categoryFiltered = selectedCategory == "All" ?
            dataManager.diseases :
            dataManager.diseases.filter { $0.category == selectedCategory }
        
        return searchText.isEmpty ? categoryFiltered : categoryFiltered.filter { disease in
            disease.nameEnglish.localizedCaseInsensitiveContains(searchText) ||
            disease.namePortuguese.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search conditions...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(categories, id: \.self) { category in
                            Button(category) {
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
                }
                
                // Diseases List
                List(filteredDiseases) { disease in
                    NavigationLink(destination: PatientSimulationView(disease: disease)
                        .environmentObject(dataManager)) {
                        PatientRowView(disease: disease, language: userProfile.currentLanguage)
                            .environmentObject(dataManager)
                    }
                }
                
                // Debug button (remove in production)
                Button("Debug Database") {
                    dataManager.debugDatabaseConnection()
                    let issues = dataManager.validateData()
                    if !issues.isEmpty {
                        print("Data issues found:")
                        issues.forEach { print("  - \($0)") }
                    }
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
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
            }
            .sheet(isPresented: $showingProfile) {
                UserProfileView()
                    .environmentObject(userProfile)
            }
        }
    }
}

// MARK: - Patient Row View
struct PatientRowView: View {
    let disease: Disease
    let language: AppLanguage
    @EnvironmentObject var dataManager: MedicalDatabaseManager
    
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
                Text("\(language == .portuguese ? "Paciente:" : "Patient:") \(patientCase.demographics.name)")
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
                    Text(disease.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.2))
                        .foregroundColor(categoryColor)
                        .cornerRadius(8)
                    
                    Spacer()
                    
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
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text(userProfile.currentLanguage == .portuguese ? "Perfil" : "Profile")
                            .font(.largeTitle)
                            .bold()
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
                            StatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Pacientes Entrevistados" : "Patients Interviewed",
                                value: "\(userProfile.profile.totalPatientsInterviewed)",
                                color: .blue
                            )
                            
                            StatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Diagnósticos Tentados" : "Diagnoses Attempted",
                                value: "\(userProfile.profile.totalDiagnosesAttempted)",
                                color: .orange
                            )
                            
                            StatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Precisão Total" : "Total Accuracy",
                                value: String(format: "%.1f%%", userProfile.profile.accuracyPercentage),
                                color: userProfile.profile.accuracyPercentage >= 70 ? .green : .orange
                            )
                            
                            StatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Dicas Usadas" : "Hints Used",
                                value: "\(userProfile.profile.hintsUsed)",
                                color: .yellow
                            )
                            
                            StatCard(
                                title: userProfile.currentLanguage == .portuguese ? "Exames Solicitados" : "Tests Ordered",
                                value: "\(userProfile.profile.testsOrdered)",
                                color: .purple
                            )
                            
                            StatCard(
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(userProfile.currentLanguage == .portuguese ? "Concluído" : "Done") {
                        dismiss()
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
struct StatCard: View {
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

// MARK: - Patient Simulation View (Complete with all features)
struct PatientSimulationView: View {
    let disease: Disease
    @EnvironmentObject var userProfile: UserProfileManager
    @EnvironmentObject var dataManager: MedicalDatabaseManager
    @StateObject private var aiService = ClaudeAIService(apiKey: "API_KEY_PLACEHOLDER")
    
    @State private var currentQuestion = ""
    @State private var conversationHistory: [ConversationTurn] = []
    @State private var showingDiagnosisEntry = false
    @State private var showingTestEntry = false
    @State private var userDiagnosis = ""
    @State private var testRequest = ""
    @State private var showingResults = false
    @State private var showingStudyMaterials = false
    @State private var diagnosisResult: DiagnosisResult?
    @State private var hintsUsed = 0
    @State private var testsOrdered = 0
    @State private var sessionStartTime = Date()
    
    private var patientCase: PatientCase? {
        dataManager.getPatientCase(for: disease)
    }
    
    var body: some View {
        VStack {
            // Patient Header
            if let patient = patientCase {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(userProfile.currentLanguage == .portuguese ? "Paciente:" : "Patient:") \(patient.demographics.name)")
                        .font(.headline)
                    
                    Text("\(patient.demographics.age) \(userProfile.currentLanguage == .portuguese ? "anos" : "years old"), \(patient.demographics.gender)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userProfile.currentLanguage == .portuguese ? "Queixa Principal:" : "Chief Complaint:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let chiefComplaints = patient.presentingSymptoms.filter { $0.isChiefComplaint }
                        
                        if chiefComplaints.isEmpty {
                            Text("Symptoms being evaluated...")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            ForEach(chiefComplaints, id: \.id) { symptom in
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
                    
                    // Show loading indicator when AI is responding
                    if aiService.isGeneratingResponse {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(userProfile.currentLanguage == .portuguese ?
                                         "Processando..." :
                                         "Processing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(15)
                            }
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            
            // Quick Questions (only show when no conversation yet)
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
            
            // Input Area
            VStack(spacing: 8) {
                HStack {
                    TextField(userProfile.currentLanguage == .portuguese ? "Faça uma pergunta ao paciente..." : "Ask the patient a question...", text: $currentQuestion)
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
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: {
                        showingTestEntry = true
                    }) {
                        HStack {
                            Image(systemName: "testtube.2")
                            Text(userProfile.currentLanguage == .portuguese ? "Solicitar Exame" : "Order Test")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(10)
                    }
                    .disabled(aiService.isGeneratingResponse)
                    
                    Button(action: {
                        getHint()
                    }) {
                        HStack {
                            Image(systemName: "lightbulb")
                            Text(userProfile.currentLanguage == .portuguese ? "Obter Dica" : "Get Hint")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(10)
                    }
                    .disabled(aiService.isGeneratingResponse)
                }
                
                Button(action: {
                    showingDiagnosisEntry = true
                }) {
                    HStack {
                        Image(systemName: "stethoscope")
                        Text(userProfile.currentLanguage == .portuguese ? "Enviar Diagnóstico" : "Submit Diagnosis")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(aiService.isGeneratingResponse ? Color.gray : Color.green)
                    .cornerRadius(10)
                }
                .disabled(aiService.isGeneratingResponse)
            }
            .padding()
        }
        .navigationTitle(userProfile.currentLanguage == .portuguese ? "Entrevista com Paciente" : "Patient Interview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sessionStartTime = Date()
        }
        .onDisappear {
            let sessionTime = Date().timeIntervalSince(sessionStartTime)
            userProfile.addStudyTime(sessionTime)
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
                    correctDisease: disease,
                    language: userProfile.currentLanguage,
                    onShowStudyMaterials: {
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
    }
    
    private func getQuickQuestions() -> [String] {
        userProfile.currentLanguage == .portuguese ? [
            "Como você está se sentindo?",
            "Quando isso começou?",
            "Pode descrever os sintomas?"
        ] : [
            "How are you feeling?",
            "When did this start?",
            "Can you describe your symptoms?"
        ]
    }
    
    private func askQuestion() {
        guard !currentQuestion.isEmpty && !aiService.isGeneratingResponse,
              let patient = patientCase else { return }
        
        let question = currentQuestion
        currentQuestion = ""
        
        Task {
            let response = await aiService.generatePatientResponse(
                question: question,
                patientCase: patient,
                conversationHistory: conversationHistory,
                language: userProfile.currentLanguage
            )
            
            await MainActor.run {
                conversationHistory.append(ConversationTurn(
                    question: question,
                    response: response,
                    timestamp: Date(),
                    isTest: false
                ))
            }
        }
    }
    
    private func orderTest(_ test: String) {
        guard let patient = patientCase else { return }
        
        testsOrdered += 1
        
        Task {
            let response = await aiService.generateTestResult(
                testRequest: test,
                patientCase: patient,
                language: userProfile.currentLanguage
            )
            
            await MainActor.run {
                conversationHistory.append(ConversationTurn(
                    question: "Test ordered: \(test)",
                    response: response,
                    timestamp: Date(),
                    isTest: true
                ))
            }
        }
    }
    
    private func getHint() {
        guard let patient = patientCase else { return }
        
        hintsUsed += 1
        
        Task {
            let hint = await aiService.generateHint(
                patientCase: patient,
                conversationHistory: conversationHistory,
                language: userProfile.currentLanguage
            )
            
            await MainActor.run {
                let hintQuestion = userProfile.currentLanguage == .portuguese ? "Solicitou uma dica" : "Requested a hint"
                conversationHistory.append(ConversationTurn(
                    question: hintQuestion,
                    response: "💡 \(hint)",
                    timestamp: Date(),
                    isTest: false
                ))
            }
        }
    }
    
    private func checkDiagnosis(_ diagnosis: String) {
        guard let patient = patientCase else { return }
        
        let isCorrect = isDiagnosisCorrect(diagnosis)
        
        diagnosisResult = DiagnosisResult(
            userDiagnosis: diagnosis,
            isCorrect: isCorrect,
            conversationTurns: conversationHistory.filter { !$0.isTest }.count,
            patientName: patient.demographics.name,
            hintsUsed: hintsUsed,
            testsOrdered: testsOrdered
        )
        
        userProfile.recordDiagnosis(
            disease: disease,
            isCorrect: isCorrect,
            questionCount: conversationHistory.filter { !$0.isTest }.count,
            hintsUsed: hintsUsed,
            testsOrdered: testsOrdered
        )
        
        showingResults = true
    }
    
    private func isDiagnosisCorrect(_ diagnosis: String) -> Bool {
        let diagnosisLower = diagnosis.lowercased()
        let conditionNameLower = disease.nameEnglish.lowercased()
        let conditionPortugueseLower = disease.namePortuguese.lowercased()
        
        return diagnosisLower.contains(conditionNameLower) ||
               conditionNameLower.contains(diagnosisLower) ||
               diagnosisLower.contains(conditionPortugueseLower) ||
               conditionPortugueseLower.contains(diagnosisLower)
    }
}

// MARK: - Supporting Views
struct ConversationBubbleView: View {
    let turn: ConversationTurn
    let language: AppLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Question/Test
            HStack {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(turn.question)
                        .padding()
                        .background(turn.isTest ? Color.purple : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    
                    Text(turn.isTest ?
                         (language == .portuguese ? "Exame" : "Test") :
                         (language == .portuguese ? "Você" : "You"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Response
            HStack {
                VStack(alignment: .leading) {
                    Text(turn.response)
                        .padding()
                        .background(turn.isTest ? Color.purple.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(15)
                    
                    Text(turn.isTest ?
                         (language == .portuguese ? "Resultado" : "Result") :
                         (language == .portuguese ? "Paciente" : "Patient"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
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
            
            TextField(language == .portuguese ? "Digite seu diagnóstico..." : "Enter your diagnosis...", text: $localDiagnosis)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            HStack {
                Button(language == .portuguese ? "Cancelar" : "Cancel") {
                    dismiss()
                }
                .padding()
                
                Spacer()
                
                Button(language == .portuguese ? "Enviar" : "Submit") {
                    onSubmit(localDiagnosis)
                }
                .padding()
                .background(localDiagnosis.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(localDiagnosis.isEmpty)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
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
            Text(language == .portuguese ? "Que exame você gostaria de solicitar?" : "What test would you like to order?")
                .font(.title2)
                .bold()
                .padding(.top)
            
            TextField(language == .portuguese ? "Digite o exame..." : "Enter test...", text: $localTest)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            // Quick test buttons
            VStack(spacing: 8) {
                Text(language == .portuguese ? "Exames Comuns:" : "Common Tests:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                    ForEach(getCommonTests(), id: \.self) { test in
                        Button(test) {
                            localTest = test
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                        .font(.caption)
                    }
                }
            }
            .padding()
            
            HStack {
                Button(language == .portuguese ? "Cancelar" : "Cancel") {
                    dismiss()
                }
                .padding()
                
                Spacer()
                
                Button(language == .portuguese ? "Enviar" : "Submit") {
                    onSubmit(localTest)
                }
                .padding()
                .background(localTest.isEmpty ? Color.gray : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(localTest.isEmpty)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private func getCommonTests() -> [String] {
        language == .portuguese ? [
            "Pressão arterial",
            "Temperatura",
            "Reflexos",
            "Ausculta pulmonar",
            "Palpação abdominal",
            "Exame neurológico"
        ] : [
            "Blood pressure",
            "Temperature",
            "Reflexes",
            "Lung auscultation",
            "Abdominal palpation",
            "Neurological exam"
        ]
    }
}

struct DiagnosisResultView: View {
    let result: DiagnosisResult
    let correctDisease: Disease
    let language: AppLanguage
    let onShowStudyMaterials: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Result
            VStack(spacing: 16) {
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(result.isCorrect ? .green : .red)
                
                Text(result.isCorrect ?
                     (language == .portuguese ? "Correto!" : "Correct!") :
                     (language == .portuguese ? "Incorreto" : "Incorrect"))
                    .font(.title)
                    .bold()
                    .foregroundColor(result.isCorrect ? .green : .red)
            }
            
            // Your Diagnosis
            VStack(alignment: .leading, spacing: 8) {
                Text(language == .portuguese ? "Seu Diagnóstico:" : "Your Diagnosis:")
                    .font(.headline)
                Text(result.userDiagnosis)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Correct Answer
            VStack(alignment: .leading, spacing: 8) {
                Text(language == .portuguese ? "Resposta Correta:" : "Correct Answer:")
                    .font(.headline)
                Text(correctDisease.getDisplayName(language))
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Performance Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("Performance")
                    .font(.headline)
                
                HStack {
                    VStack {
                        Text("\(result.conversationTurns)")
                            .font(.title2)
                            .bold()
                        Text("Questions")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(result.testsOrdered)")
                            .font(.title2)
                            .bold()
                        Text("Tests")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(result.hintsUsed)")
                            .font(.title2)
                            .bold()
                        Text("Hints")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Action Buttons
            VStack(spacing: 12) {
                if !result.isCorrect {
                    Button("Continue Questions") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button("Study Materials") {
                    onShowStudyMaterials()
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button(language == .portuguese ? "Concluído" : "Done") {
                    dismiss()
                }
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct StudyMaterialsView: View {
    let disease: Disease
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Condition Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(disease.getDisplayName(language))
                            .font(.largeTitle)
                            .bold()
                        
                        Text(disease.category)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description:")
                            .font(.headline)
                        
                        Text(disease.getDescription(language))
                            .font(.body)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // Symptoms
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Symptoms:")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 8) {
                            ForEach(disease.symptoms, id: \.id) { symptom in
                                Text("• \(symptom.getText(language))")
                                    .font(.body)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Physical Exam Findings
                    if !disease.physicalFindings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(language == .portuguese ? "Achados do Exame Físico:" : "Physical Exam Findings:")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 8) {
                                ForEach(disease.physicalFindings, id: \.id) { finding in
                                    Text("• \(finding.getText(language))")
                                        .font(.body)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Lab Results
                    if !disease.labResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(language == .portuguese ? "Resultados Laboratoriais:" : "Laboratory Results:")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 8) {
                                ForEach(disease.labResults, id: \.id) { result in
                                    Text("• \(result.getText(language))")
                                        .font(.body)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Study Materials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Concluído" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
