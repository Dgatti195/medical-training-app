import SwiftUI
import Foundation

// MARK: - Study Tools Manager
class StudyToolsManager: ObservableObject {
    static let shared = StudyToolsManager()

    @Published var bookmarkedDiseases: [String] = []
    @Published var studyNotes: [StudyNote] = []
    @Published var studySets: [StudySet] = []
    @Published var flashCards: [FlashCard] = []

    private let bookmarksKey = "BookmarkedDiseases"
    private let notesKey = "StudyNotes"
    private let studySetsKey = "StudySets"
    private let flashCardsKey = "FlashCards"

    init() {
        loadBookmarks()
        loadStudyNotes()
        loadStudySets()
        loadFlashCards()
    }

    // MARK: - Bookmarks Management
    func toggleBookmark(for diseaseName: String) {
        if bookmarkedDiseases.contains(diseaseName) {
            bookmarkedDiseases.removeAll { $0 == diseaseName }
        } else {
            bookmarkedDiseases.append(diseaseName)
        }
        saveBookmarks()
    }

    func isBookmarked(_ diseaseName: String) -> Bool {
        return bookmarkedDiseases.contains(diseaseName)
    }

    private func saveBookmarks() {
        UserDefaults.standard.set(bookmarkedDiseases, forKey: bookmarksKey)
    }

    private func loadBookmarks() {
        bookmarkedDiseases = UserDefaults.standard.stringArray(forKey: bookmarksKey) ?? []
    }

    // MARK: - Study Notes Management
    func addStudyNote(for diseaseName: String, content: String, category: String) {
        let note = StudyNote(
            id: UUID(),
            diseaseName: diseaseName,
            content: content,
            category: category,
            createdDate: Date(),
            lastModified: Date()
        )

        studyNotes.append(note)
        saveStudyNotes()
    }

    func updateStudyNote(_ note: StudyNote, content: String) {
        if let index = studyNotes.firstIndex(where: { $0.id == note.id }) {
            studyNotes[index].content = content
            studyNotes[index].lastModified = Date()
            saveStudyNotes()
        }
    }

    func deleteStudyNote(_ note: StudyNote) {
        studyNotes.removeAll { $0.id == note.id }
        saveStudyNotes()
    }

    func getStudyNotes(for diseaseName: String) -> [StudyNote] {
        return studyNotes.filter { $0.diseaseName == diseaseName }
    }

    private func saveStudyNotes() {
        if let data = try? JSONEncoder().encode(studyNotes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }

    private func loadStudyNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let notes = try? JSONDecoder().decode([StudyNote].self, from: data) {
            studyNotes = notes
        }
    }

    // MARK: - Study Sets Management
    func createStudySet(name: String, description: String, diseases: [String]) {
        let studySet = StudySet(
            id: UUID(),
            name: name,
            description: description,
            diseases: diseases,
            createdDate: Date(),
            lastStudied: nil
        )

        studySets.append(studySet)
        saveStudySets()
    }

    func updateLastStudied(for studySet: StudySet) {
        if let index = studySets.firstIndex(where: { $0.id == studySet.id }) {
            studySets[index].lastStudied = Date()
            saveStudySets()
        }
    }

    func deleteStudySet(_ studySet: StudySet) {
        studySets.removeAll { $0.id == studySet.id }
        saveStudySets()
    }

    private func saveStudySets() {
        if let data = try? JSONEncoder().encode(studySets) {
            UserDefaults.standard.set(data, forKey: studySetsKey)
        }
    }

    private func loadStudySets() {
        if let data = UserDefaults.standard.data(forKey: studySetsKey),
           let sets = try? JSONDecoder().decode([StudySet].self, from: data) {
            studySets = sets
        }
    }

    // MARK: - Flash Cards Management
    func createFlashCard(question: String, answer: String, category: String, difficulty: FlashCard.Difficulty) {
        let flashCard = FlashCard(
            id: UUID(),
            question: question,
            answer: answer,
            category: category,
            difficulty: difficulty,
            createdDate: Date(),
            lastReviewed: nil,
            reviewCount: 0,
            correctCount: 0
        )

        flashCards.append(flashCard)
        saveFlashCards()
    }

    func updateFlashCardStats(_ flashCard: FlashCard, isCorrect: Bool) {
        if let index = flashCards.firstIndex(where: { $0.id == flashCard.id }) {
            flashCards[index].lastReviewed = Date()
            flashCards[index].reviewCount += 1
            if isCorrect {
                flashCards[index].correctCount += 1
            }
            saveFlashCards()
        }
    }

    func deleteFlashCard(_ flashCard: FlashCard) {
        flashCards.removeAll { $0.id == flashCard.id }
        saveFlashCards()
    }

    func getFlashCards(for category: String) -> [FlashCard] {
        return category == "All" ? flashCards : flashCards.filter { $0.category == category }
    }

    private func saveFlashCards() {
        if let data = try? JSONEncoder().encode(flashCards) {
            UserDefaults.standard.set(data, forKey: flashCardsKey)
        }
    }

    private func loadFlashCards() {
        if let data = UserDefaults.standard.data(forKey: flashCardsKey),
           let cards = try? JSONDecoder().decode([FlashCard].self, from: data) {
            flashCards = cards
        }
    }

    // MARK: - Export Functionality
    func exportStudyData(language: AppLanguage) -> String {
        var exportData = language == .portuguese ?
            "=== DADOS DE ESTUDO MÉDICO ===\n\n" :
            "=== MEDICAL STUDY DATA ===\n\n"

        // Export bookmarks
        exportData += language == .portuguese ?
            "FAVORITOS:\n" :
            "BOOKMARKS:\n"

        if bookmarkedDiseases.isEmpty {
            exportData += language == .portuguese ?
                "Nenhum favorito salvo.\n\n" :
                "No bookmarks saved.\n\n"
        } else {
            for bookmark in bookmarkedDiseases {
                exportData += "• \(bookmark)\n"
            }
            exportData += "\n"
        }

        // Export notes
        exportData += language == .portuguese ?
            "ANOTAÇÕES DE ESTUDO:\n" :
            "STUDY NOTES:\n"

        if studyNotes.isEmpty {
            exportData += language == .portuguese ?
                "Nenhuma anotação salva.\n\n" :
                "No notes saved.\n\n"
        } else {
            for note in studyNotes {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                exportData += "\(note.diseaseName) (\(dateFormatter.string(from: note.createdDate))):\n"
                exportData += "\(note.content)\n\n"
            }
        }

        // Export study sets
        exportData += language == .portuguese ?
            "CONJUNTOS DE ESTUDO:\n" :
            "STUDY SETS:\n"

        if studySets.isEmpty {
            exportData += language == .portuguese ?
                "Nenhum conjunto de estudo criado.\n\n" :
                "No study sets created.\n\n"
        } else {
            for studySet in studySets {
                exportData += "\(studySet.name):\n"
                exportData += "\(studySet.description)\n"
                exportData += language == .portuguese ?
                    "Condições: \(studySet.diseases.joined(separator: ", "))\n\n" :
                    "Conditions: \(studySet.diseases.joined(separator: ", "))\n\n"
            }
        }

        // Export flash cards stats
        exportData += language == .portuguese ?
            "ESTATÍSTICAS DE FLASHCARDS:\n" :
            "FLASHCARD STATISTICS:\n"

        if flashCards.isEmpty {
            exportData += language == .portuguese ?
                "Nenhum flashcard criado.\n" :
                "No flashcards created.\n"
        } else {
            let totalCards = flashCards.count
            let reviewedCards = flashCards.filter { $0.reviewCount > 0 }.count
            let averageAccuracy = flashCards.isEmpty ? 0 :
                Double(flashCards.reduce(0) { $0 + $1.correctCount }) /
                Double(flashCards.reduce(0) { $0 + $1.reviewCount })

            exportData += language == .portuguese ?
                "Total de cards: \(totalCards)\n" :
                "Total cards: \(totalCards)\n"

            exportData += language == .portuguese ?
                "Cards revisados: \(reviewedCards)\n" :
                "Cards reviewed: \(reviewedCards)\n"

            if !flashCards.isEmpty && flashCards.reduce(0, { $0 + $1.reviewCount }) > 0 {
                exportData += language == .portuguese ?
                    "Precisão média: \(String(format: "%.1f", averageAccuracy * 100))%\n" :
                    "Average accuracy: \(String(format: "%.1f", averageAccuracy * 100))%\n"
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        exportData += "\n" + (language == .portuguese ?
            "Exportado em: \(dateFormatter.string(from: Date()))" :
            "Exported on: \(dateFormatter.string(from: Date()))")

        return exportData
    }

    func getStudyStatistics() -> StudyStatistics {
        let totalBookmarks = bookmarkedDiseases.count
        let totalNotes = studyNotes.count
        let totalStudySets = studySets.count
        let totalFlashCards = flashCards.count

        let reviewedFlashCards = flashCards.filter { $0.reviewCount > 0 }.count
        let averageAccuracy = flashCards.isEmpty ? 0 :
            Double(flashCards.reduce(0) { $0 + $1.correctCount }) /
            Double(max(1, flashCards.reduce(0) { $0 + $1.reviewCount }))

        return StudyStatistics(
            totalBookmarks: totalBookmarks,
            totalNotes: totalNotes,
            totalStudySets: totalStudySets,
            totalFlashCards: totalFlashCards,
            reviewedFlashCards: reviewedFlashCards,
            averageFlashCardAccuracy: averageAccuracy
        )
    }
}

// MARK: - Study Data Models
struct StudyNote: Identifiable, Codable {
    let id: UUID
    let diseaseName: String
    var content: String
    let category: String
    let createdDate: Date
    var lastModified: Date

    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdDate)
    }

    var formattedLastModified: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastModified)
    }
}

struct StudySet: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let diseases: [String]
    let createdDate: Date
    var lastStudied: Date?

    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdDate)
    }

    var formattedLastStudied: String {
        guard let lastStudied = lastStudied else {
            return "Never"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: lastStudied)
    }
}

struct FlashCard: Identifiable, Codable {
    let id: UUID
    let question: String
    let answer: String
    let category: String
    let difficulty: Difficulty
    let createdDate: Date
    var lastReviewed: Date?
    var reviewCount: Int
    var correctCount: Int

    enum Difficulty: String, CaseIterable, Codable {
        case easy = "easy"
        case medium = "medium"
        case hard = "hard"

        func displayName(language: AppLanguage) -> String {
            switch self {
            case .easy:
                return language == .portuguese ? "Fácil" : "Easy"
            case .medium:
                return language == .portuguese ? "Médio" : "Medium"
            case .hard:
                return language == .portuguese ? "Difícil" : "Hard"
            }
        }

        var color: Color {
            switch self {
            case .easy: return .green
            case .medium: return .orange
            case .hard: return .red
            }
        }
    }

    var accuracy: Double {
        guard reviewCount > 0 else { return 0 }
        return Double(correctCount) / Double(reviewCount)
    }

    var formattedAccuracy: String {
        return String(format: "%.1f%%", accuracy * 100)
    }
}

struct StudyStatistics {
    let totalBookmarks: Int
    let totalNotes: Int
    let totalStudySets: Int
    let totalFlashCards: Int
    let reviewedFlashCards: Int
    let averageFlashCardAccuracy: Double
}