import Foundation
import SQLite3
import Combine

/// Debug-only log helper — compiled out entirely in Release builds.
@inline(__always) private func dbLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}

// MARK: - Database Manager
// Low-level SQLite manager: opens/copies/queries the medical_conditions.sqlite database.
class DatabaseManager: ObservableObject {
    private var db: OpaquePointer?

    // Version string — increment whenever the bundle database is updated so the app
    // re-copies the SQLite file on next launch instead of reusing the stale Documents copy.
    private static let bundleDBVersion = "2"
    private let dbVersionDefaultsKey = "med_ia_db_version"

    init() {
        openDatabase()
        // Don't create tables or insert sample data - use existing database
    }

    deinit {
        if sqlite3_close(db) != SQLITE_OK {
            dbLog("Error closing database")
        }
    }

    private func openDatabase() {
        // First try to copy database from bundle to documents directory
        copyDatabaseIfNeeded()

        do {
            let fileURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("medical_conditions.sqlite")

            if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
                dbLog("Successfully opened connection to database at \(fileURL.path)")
            } else {
                dbLog("Unable to open database - creating fallback")
                createFallbackDatabase()
            }
        } catch {
            dbLog("❌ Failed to get documents directory: \(error)")
            createFallbackDatabase()
        }
    }

    private func copyDatabaseIfNeeded() {
        let fileManager = FileManager.default
        guard let documentsURL = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            dbLog("❌ Cannot access documents directory")
            return
        }
        let destinationURL = documentsURL.appendingPathComponent("medical_conditions.sqlite")

        // Check if we have the populated database in the bundle
        guard let bundlePath = Bundle.main.path(forResource: "medical_conditions", ofType: "sqlite") else {
            dbLog("❌ Database file not found in bundle - will create fallback")
            return
        }
        let bundleURL = URL(fileURLWithPath: bundlePath)

        // Version check: skip copy if the Documents copy is already at the current version.
        // This avoids an unnecessary file-system write on every app launch.
        let storedVersion = UserDefaults.standard.string(forKey: dbVersionDefaultsKey) ?? ""
        let dbExists = fileManager.fileExists(atPath: destinationURL.path)
        guard !dbExists || storedVersion != DatabaseManager.bundleDBVersion else {
            dbLog("✅ Database up to date (v\(DatabaseManager.bundleDBVersion)) — skipping copy")
            return
        }

        do {
            if dbExists {
                try fileManager.removeItem(at: destinationURL)
                dbLog("🔄 Removed old database to update with latest data")
            }
            try fileManager.copyItem(at: bundleURL, to: destinationURL)
            UserDefaults.standard.set(DatabaseManager.bundleDBVersion, forKey: dbVersionDefaultsKey)
            dbLog("✅ Database copied from bundle to documents directory (v\(DatabaseManager.bundleDBVersion))")
        } catch {
            dbLog("❌ Error copying database: \(error)")
            dbLog("Will create fallback database with sample data")
        }
    }

    func forceCopyDatabase() {
        // Invalidate stored version so copyDatabaseIfNeeded always re-copies.
        UserDefaults.standard.removeObject(forKey: dbVersionDefaultsKey)

        // Close current database connection
        if sqlite3_close(db) != SQLITE_OK {
            dbLog("Error closing database for update")
        }

        // Force copy the database
        copyDatabaseIfNeeded()

        // Reopen the database
        do {
            let fileURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("medical_conditions.sqlite")

            if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
                dbLog("Successfully reopened updated database")
            } else {
                dbLog("Error reopening database after update")
            }
        } catch {
            dbLog("❌ Failed to get documents directory on reopen: \(error)")
        }
    }

    private func createFallbackDatabase() {
        do {
            let fileURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("medical_conditions.sqlite")

            if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
                dbLog("Creating fallback database with sample data")
                createTables()
                insertSampleData()
            }
        } catch {
            dbLog("❌ Failed to get documents directory for fallback database: \(error)")
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

        let createTreatmentsSQL = """
        CREATE TABLE IF NOT EXISTS treatments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER NOT NULL,
            treatment_english TEXT NOT NULL,
            treatment_portuguese TEXT NOT NULL,
            is_primary_treatment BOOLEAN DEFAULT FALSE,
            category TEXT NOT NULL,
            FOREIGN KEY (disease_id) REFERENCES diseases(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_treatments_disease_id ON treatments(disease_id);
        """

        // Execute table creation
        if sqlite3_exec(db, createDiseasesSQL, nil, nil, nil) != SQLITE_OK {
            dbLog("Error creating diseases table")
        }
        if sqlite3_exec(db, createSymptomsSQL, nil, nil, nil) != SQLITE_OK {
            dbLog("Error creating symptoms table")
        }
        if sqlite3_exec(db, createPhysicalFindingsSQL, nil, nil, nil) != SQLITE_OK {
            dbLog("Error creating physical_findings table")
        }
        if sqlite3_exec(db, createLabResultsSQL, nil, nil, nil) != SQLITE_OK {
            dbLog("Error creating lab_results table")
        }
        if sqlite3_exec(db, createHintsSQL, nil, nil, nil) != SQLITE_OK {
            dbLog("Error creating diagnostic_hints table")
        }
        if sqlite3_exec(db, createTreatmentsSQL, nil, nil, nil) != SQLITE_OK {
            dbLog("Error creating treatments table")
        }
    }

    private func insertSampleData() {
        dbLog("Inserting sample medical data...")

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
            insertTreatment(diseaseId: diseaseId, english: "Emergency appendectomy", portuguese: "Apendicectomia de emergência", isPrimary: true, category: "procedure")
            insertTreatment(diseaseId: diseaseId, english: "Intravenous antibiotics", portuguese: "Antibióticos intravenosos", isPrimary: true, category: "medication")
            insertTreatment(diseaseId: diseaseId, english: "Pain management", portuguese: "Controle da dor", isPrimary: false, category: "supportive")

        case 1: // Migraine
            insertSymptom(diseaseId: diseaseId, english: "Severe unilateral headache", portuguese: "Dor de cabeça unilateral severa", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Nausea", portuguese: "Náusea", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Photophobia", portuguese: "Fotofobia", isChief: false)
            insertSymptom(diseaseId: diseaseId, english: "Visual aura", portuguese: "Aura visual", isChief: false)
            insertTreatment(diseaseId: diseaseId, english: "Triptans (e.g., sumatriptan)", portuguese: "Triptanos (ex: sumatriptano)", isPrimary: true, category: "medication")
            insertTreatment(diseaseId: diseaseId, english: "NSAIDs for pain relief", portuguese: "AINEs para alívio da dor", isPrimary: true, category: "medication")
            insertTreatment(diseaseId: diseaseId, english: "Rest in dark, quiet room", portuguese: "Descanso em quarto escuro e silencioso", isPrimary: false, category: "lifestyle")

        case 2: // Pneumonia
            insertSymptom(diseaseId: diseaseId, english: "Productive cough", portuguese: "Tosse produtiva", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Fever", portuguese: "Febre", isChief: true)
            insertSymptom(diseaseId: diseaseId, english: "Shortness of breath", portuguese: "Falta de ar", isChief: false)
            insertSymptom(diseaseId: diseaseId, english: "Chest pain", portuguese: "Dor no peito", isChief: false)
            insertTreatment(diseaseId: diseaseId, english: "Broad-spectrum antibiotics", portuguese: "Antibióticos de amplo espectro", isPrimary: true, category: "medication")
            insertTreatment(diseaseId: diseaseId, english: "Oxygen therapy if hypoxic", portuguese: "Oxigenoterapia se hipóxico", isPrimary: true, category: "supportive")
            insertTreatment(diseaseId: diseaseId, english: "Hydration and rest", portuguese: "Hidratação e repouso", isPrimary: false, category: "lifestyle")

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
                dbLog("Error inserting symptom: \(english)")
            }
        }
        sqlite3_finalize(statement)
    }

    private func insertTreatment(diseaseId: Int, english: String, portuguese: String, isPrimary: Bool, category: String) {
        let insertSQL = "INSERT INTO treatments (disease_id, treatment_english, treatment_portuguese, is_primary_treatment, category) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(diseaseId))
            sqlite3_bind_text(statement, 2, english, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, portuguese, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 4, isPrimary ? 1 : 0)
            sqlite3_bind_text(statement, 5, category, -1, SQLITE_TRANSIENT)

            if sqlite3_step(statement) != SQLITE_DONE {
                dbLog("Error inserting treatment: \(english)")
            }
        }
        sqlite3_finalize(statement)
    }

    // MARK: - Integrity Checks

    /// Checks that all expected tables exist in the database. Returns a list of issues found.
    func validateTables() -> [String] {
        guard let db = db else { return ["Database connection not available"] }
        let expectedTables = ["diseases", "symptoms", "physical_findings", "lab_results", "diagnostic_hints", "treatments"]
        let querySQL = "SELECT name FROM sqlite_master WHERE type='table';"
        var statement: OpaquePointer?
        var foundTables = Set<String>()
        var issues: [String] = []

        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    foundTables.insert(String(cString: cString))
                }
            }
        } else {
            issues.append("Cannot query sqlite_master: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)

        for table in expectedTables where !foundTables.contains(table) {
            issues.append("Missing required table: '\(table)'")
        }
        return issues
    }

    /// Checks for rows in related tables whose disease_id does not reference a valid disease.
    /// Returns a list of warnings for any orphaned records found.
    func checkOrphanedRecords() -> [String] {
        guard let db = db else { return [] }
        var issues: [String] = []

        let tables: [(String, String)] = [
            ("symptoms", "symptom"),
            ("physical_findings", "physical finding"),
            ("lab_results", "lab result"),
            ("diagnostic_hints", "diagnostic hint"),
            ("treatments", "treatment")
        ]

        for (table, label) in tables {
            let sql = "SELECT COUNT(*) FROM \(table) WHERE disease_id NOT IN (SELECT id FROM diseases);"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    let count = Int(sqlite3_column_int(statement, 0))
                    if count > 0 {
                        issues.append("\(count) orphaned \(label) record(s) with no matching disease")
                    }
                }
            } else {
                issues.append("Cannot check orphans in '\(table)': \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
        return issues
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
        guard let db = db else { return [] }
        // Exclude placeholder/invalid diseases that have no clinical value:
        // "Not specified", "No specific medical condition described", "Positive and Negative Predictive Values"
        let querySQL = "SELECT id, name_english, name_portuguese, category, severity, description_english, description_portuguese FROM diseases WHERE name_english NOT LIKE 'Not specified%' AND name_english NOT LIKE 'No specific medical%' AND name_english NOT LIKE 'Positive and Negative%' ORDER BY id;"
        var statement: OpaquePointer?
        var diseases: [Disease] = []

        dbLog("🔍 Starting disease fetch with query: \(querySQL)")

        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))

                let nameEnglish = extractString(from: statement, column: 1) ?? "Unknown Disease"
                let namePortuguese = extractString(from: statement, column: 2) ?? "Doença Desconhecida"
                let category = extractString(from: statement, column: 3) ?? "General"
                let severity = extractString(from: statement, column: 4) ?? "Unknown"
                let descriptionEnglish = extractString(from: statement, column: 5) ?? "No description available"
                let descriptionPortuguese = extractString(from: statement, column: 6) ?? "Nenhuma descrição disponível"

                var disease = Disease(
                    id: id,
                    nameEnglish: nameEnglish,
                    namePortuguese: namePortuguese,
                    category: category,
                    severity: severity,
                    descriptionEnglish: descriptionEnglish,
                    descriptionPortuguese: descriptionPortuguese,
                    difficultyRating: 3 // Default value, will use computedDifficulty
                )

                disease.symptoms = fetchSymptoms(for: id)
                disease.physicalFindings = fetchPhysicalFindings(for: id)
                disease.labResults = fetchLabResults(for: id)
                disease.hints = fetchHints(for: id)
                disease.treatments = fetchTreatments(for: id)

                diseases.append(disease)
            }
        } else {
            dbLog("❌ Error preparing diseases query: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        dbLog("✅ Loaded \(diseases.count) diseases from database")
        return diseases
    }

    func fetchSymptoms(for diseaseId: Int) -> [Symptom] {
        guard let db = db else { return [] }
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
        } else {
            dbLog("❌ fetchSymptoms: sqlite3_prepare_v2 failed for disease \(diseaseId): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return symptoms
    }

    func fetchPhysicalFindings(for diseaseId: Int) -> [PhysicalFinding] {
        guard let db = db else { return [] }
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
        } else {
            dbLog("❌ fetchPhysicalFindings: sqlite3_prepare_v2 failed for disease \(diseaseId): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return findings
    }

    func fetchLabResults(for diseaseId: Int) -> [LabResult] {
        guard let db = db else { return [] }
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
        } else {
            dbLog("❌ fetchLabResults: sqlite3_prepare_v2 failed for disease \(diseaseId): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return results
    }

    func fetchHints(for diseaseId: Int) -> [DiagnosticHint] {
        guard let db = db else { return [] }
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
        } else {
            dbLog("❌ fetchHints: sqlite3_prepare_v2 failed for disease \(diseaseId): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return hints
    }

    func fetchTreatments(for diseaseId: Int) -> [Treatment] {
        guard let db = db else { return [] }
        let querySQL = "SELECT id, disease_id, treatment_english, treatment_portuguese, is_primary_treatment, category FROM treatments WHERE disease_id = ?;"
        var statement: OpaquePointer?
        var treatments: [Treatment] = []

        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(diseaseId))

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let diseaseId = Int(sqlite3_column_int(statement, 1))

                let english = extractString(from: statement, column: 2) ?? "Unknown treatment"
                let portuguese = extractString(from: statement, column: 3) ?? "Tratamento desconhecido"
                let isPrimary = sqlite3_column_int(statement, 4) == 1
                let categoryString = extractString(from: statement, column: 5) ?? "medication"
                let category = TreatmentCategory(rawValue: categoryString) ?? .medication

                treatments.append(Treatment(
                    id: id,
                    diseaseId: diseaseId,
                    treatmentEnglish: english,
                    treatmentPortuguese: portuguese,
                    isPrimaryTreatment: isPrimary,
                    category: category
                ))
            }
        } else {
            dbLog("❌ fetchTreatments: sqlite3_prepare_v2 failed for disease \(diseaseId): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return treatments
    }
}

// MARK: - Medical Database Manager
// High-level manager: loads diseases, generates patient cases, provides search/filter API.
class MedicalDatabaseManager: ObservableObject {
    @Published var diseases: [Disease] = []
    @Published var isLoading = false
    @Published var patientCases: [PatientCase] = []
    @Published var loadingError: String?

    private let dbManager = DatabaseManager()
    private var hasLoadedOnce = false
    /// Cache for disease symptoms keyed by disease ID (task 13.2).
    /// Avoids O(N) SQLite queries in findDifferentialDiagnoses().
    private var symptomCache: [Int: [Symptom]] = [:]

    init() {
        loadDiseases()
    }

    func loadDiseases() {
        guard !hasLoadedOnce && !isLoading else {
            dbLog("Skipping database load - already loaded or in progress")
            return
        }

        dbLog("Starting database load...")
        isLoading = true
        hasLoadedOnce = true
        loadingError = nil

        // Step 1: Validate that all required tables exist before loading data
        let tableIssues = dbManager.validateTables()
        if !tableIssues.isEmpty {
            dbLog("⚠️ Database structure issues found:")
            for issue in tableIssues {
                dbLog("  - \(issue)")
            }
            // A missing core table is a critical structural problem — surface it to the user
            loadingError = tableIssues.first
        }

        // Step 2: Load diseases from database
        diseases = dbManager.fetchAllDiseases()

        if diseases.isEmpty {
            if loadingError == nil {
                loadingError = "No diseases found in database"
            }
            dbLog("❌ No diseases loaded from database")
        } else {
            dbLog("✅ Database load completed with \(diseases.count) diseases")
            dbLog("🔍 First few diseases loaded:")
            for (index, disease) in diseases.prefix(5).enumerated() {
                dbLog("  \(index + 1). \(disease.nameEnglish) (Category: \(disease.category))")
            }
            generateConsistentPatientCases()

            // Step 3: Run data quality checks after diseases are loaded
            runIntegrityChecks()
        }

        isLoading = false
        printLoadedDataSummary()
    }

    /// Runs all post-load integrity checks and logs warnings. Does not modify loadingError
    /// (only structural issues from validateTables() warrant blocking the user).
    private func runIntegrityChecks() {
        // Data quality: diseases with no symptoms, no chief complaints, etc.
        let dataIssues = validateData()

        // Referential integrity: orphaned rows in related tables
        let orphanIssues = dbManager.checkOrphanedRecords()

        let allIssues = dataIssues + orphanIssues
        if allIssues.isEmpty {
            dbLog("✅ Database integrity check passed — no issues found")
        } else {
            dbLog("⚠️ Database integrity warnings (\(allIssues.count) issue(s)):")
            for issue in allIssues {
                dbLog("  ⚠️ \(issue)")
            }
        }
    }

    private func printLoadedDataSummary() {
        #if DEBUG
        dbLog("\n=== LOADED DATA SUMMARY ===")
        dbLog("Total diseases: \(diseases.count)")

        if !diseases.isEmpty {
            let categoryCounts = Dictionary(grouping: diseases, by: { $0.category })
                .mapValues { $0.count }

            dbLog("By category:")
            for (category, count) in categoryCounts.sorted(by: { $0.key < $1.key }) {
                dbLog("  \(category): \(count)")
            }

            let totalSymptoms = diseases.reduce(0) { $0 + $1.symptoms.count }
            let totalChiefComplaints = diseases.reduce(0) { $0 + $1.symptoms.filter { $0.isChiefComplaint }.count }
            let totalPhysicalFindings = diseases.reduce(0) { $0 + $1.physicalFindings.count }
            let totalLabResults = diseases.reduce(0) { $0 + $1.labResults.count }
            let totalHints = diseases.reduce(0) { $0 + $1.hints.count }

            dbLog("Total symptoms: \(totalSymptoms) (\(totalChiefComplaints) chief complaints)")
            dbLog("Total physical findings: \(totalPhysicalFindings)")
            dbLog("Total lab results: \(totalLabResults)")
            dbLog("Total diagnostic hints: \(totalHints)")

            // Sample disease info
            if let firstDisease = diseases.first {
                dbLog("\nSample disease: \(firstDisease.nameEnglish)")
                dbLog("  Category: \(firstDisease.category)")
                dbLog("  Symptoms: \(firstDisease.symptoms.count)")
                dbLog("  Chief complaints: \(firstDisease.symptoms.filter { $0.isChiefComplaint }.count)")
            }
        }
        dbLog("========================\n")
        #endif
    }

    private func generateConsistentPatientCases() {
        patientCases = diseases.map { disease in
            generatePatientCase(from: disease, language: .english)
        }
        dbLog("Generated \(patientCases.count) consistent patient cases from extracted PDF data")

        // Verify patient cases have data
        let casesWithSymptoms = patientCases.filter { !$0.presentingSymptoms.isEmpty }
        dbLog("Patient cases with symptoms: \(casesWithSymptoms.count)/\(patientCases.count)")

        // Print some demographic distribution statistics
        printPatientDemographics()
    }

    private func printPatientDemographics() {
        #if DEBUG
        let ageGroups = Dictionary(grouping: patientCases) { patient in
            switch patient.demographics.age {
            case 1...17: return "Pediatric (1-17)"
            case 18...39: return "Young Adult (18-39)"
            case 40...64: return "Middle Age (40-64)"
            case 65...85: return "Elderly (65+)"
            default: return "Other"
            }
        }

        dbLog("\n=== PATIENT DEMOGRAPHICS ===")
        for (group, patients) in ageGroups.sorted(by: { $0.key < $1.key }) {
            dbLog("\(group): \(patients.count) patients")
        }

        let categoryDistribution = Dictionary(grouping: patientCases) { $0.disease.category }
        dbLog("\n=== DISEASE CATEGORIES ===")
        for (category, patients) in categoryDistribution.sorted(by: { $0.value.count > $1.value.count }) {
            dbLog("\(category): \(patients.count) cases")
        }
        dbLog("============================\n")
        #endif
    }

    func regeneratePatientCases() {
        dbLog("Regenerating patient cases with enhanced demographics...")
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
            dbLog("⚠️ Warning: No symptoms found for disease: \(disease.nameEnglish)")
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
        return stages.last ?? .moderate
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
        dbLog("Refreshing database data...")
        hasLoadedOnce = false
        diseases = []
        patientCases = []
        loadingError = nil
        loadDiseases()
    }

    func forceUpdateDatabase() {
        dbLog("Forcing database update with latest extracted data...")

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
        #if DEBUG
        dbLog("=== DATABASE DEBUG INFO ===")
        dbLog("Diseases count: \(diseases.count)")
        dbLog("Patient cases count: \(patientCases.count)")
        dbLog("Has loaded once: \(hasLoadedOnce)")
        dbLog("Is loading: \(isLoading)")
        dbLog("Loading error: \(loadingError ?? "None")")

        if let firstDisease = diseases.first {
            dbLog("\nFirst disease details:")
            dbLog("  ID: \(firstDisease.id)")
            dbLog("  English: \(firstDisease.nameEnglish)")
            dbLog("  Portuguese: \(firstDisease.namePortuguese)")
            dbLog("  Category: \(firstDisease.category)")
            dbLog("  Symptoms: \(firstDisease.symptoms.count)")
            dbLog("  Chief complaints: \(firstDisease.symptoms.filter { $0.isChiefComplaint }.count)")

            if let patientCase = getPatientCase(for: firstDisease) {
                dbLog("  Patient case symptoms: \(patientCase.presentingSymptoms.count)")
                dbLog("  Patient name: \(patientCase.demographics.name)")
            }
        }
        dbLog("===========================")
        #endif
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

    // MARK: - Symptom Cache (task 13.2)
    /// Returns symptoms for a disease, hitting the in-memory cache first to avoid
    /// repeated SQLite queries when called many times during differential diagnosis.
    private func cachedSymptoms(for diseaseId: Int) -> [Symptom] {
        if let cached = symptomCache[diseaseId] { return cached }
        let fetched = dbManager.fetchSymptoms(for: diseaseId)
        symptomCache[diseaseId] = fetched
        return fetched
    }

    // MARK: - Differential Diagnosis (task 3.3)
    /// Returns up to 3 diseases in the same category that share the most symptoms
    /// with the given disease. Used to show differential diagnosis feedback after a session.
    func findDifferentialDiagnoses(for disease: Disease, language: AppLanguage) -> [DifferentialEntry] {
        let candidates = diseases.filter { $0.category == disease.category && $0.id != disease.id }
        guard !candidates.isEmpty else { return [] }

        // Build a normalised set of the target disease's symptom names for fast lookup.
        // Pre-populate the cache with the target disease's already-loaded symptoms.
        if !disease.symptoms.isEmpty {
            symptomCache[disease.id] = disease.symptoms
        }
        let targetSymptomSet = Set(disease.symptoms.map { $0.symptomEnglish.lowercased() })

        // When no symptoms are loaded for the disease, fall back to name-only entries
        guard !targetSymptomSet.isEmpty else {
            return candidates.prefix(3).map {
                DifferentialEntry(name: $0.getDisplayName(language), sharedSymptoms: [])
            }
        }

        var scored: [(entry: DifferentialEntry, score: Int)] = []

        for candidate in candidates {
            let candidateSymptoms = cachedSymptoms(for: candidate.id)
            let candidateSet = Set(candidateSymptoms.map { $0.symptomEnglish.lowercased() })

            // Shared = symptoms both diseases have in common
            let sharedNames = disease.symptoms.filter { symptom in
                candidateSet.contains(symptom.symptomEnglish.lowercased())
            }

            guard !sharedNames.isEmpty else { continue }

            let displayedShared = sharedNames.prefix(3).map { $0.getText(language) }

            // Distinguishing features = correct disease symptoms NOT present in this differential
            let distinguishing = disease.symptoms.filter { symptom in
                !candidateSet.contains(symptom.symptomEnglish.lowercased())
            }
            let displayedDistinguishing = distinguishing.prefix(2).map { $0.getText(language) }

            let entry = DifferentialEntry(
                name: candidate.getDisplayName(language),
                sharedSymptoms: Array(displayedShared),
                distinguishingFeatures: Array(displayedDistinguishing)
            )
            scored.append((entry, sharedNames.count))
        }

        scored.sort { $0.score > $1.score }
        return scored.prefix(3).map { $0.entry }
    }
}
