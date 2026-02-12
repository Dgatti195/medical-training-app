import SwiftUI

// MARK: - Study Tools View
struct StudyToolsView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var studyToolsManager = StudyToolsManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    private var language: AppLanguage {
        userProfile.currentLanguage
    }

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                BookmarksView(studyToolsManager: studyToolsManager, language: language)
                    .tabItem {
                        Image(systemName: "bookmark.fill")
                        Text(language == .portuguese ? "Favoritos" : "Bookmarks")
                    }
                    .tag(0)

                StudyNotesView(studyToolsManager: studyToolsManager, language: language)
                    .tabItem {
                        Image(systemName: "note.text")
                        Text(language == .portuguese ? "Anotações" : "Notes")
                    }
                    .tag(1)

                StudySetsView(studyToolsManager: studyToolsManager, language: language)
                    .tabItem {
                        Image(systemName: "folder.fill")
                        Text(language == .portuguese ? "Conjuntos" : "Sets")
                    }
                    .tag(2)

                FlashCardsView(studyToolsManager: studyToolsManager, language: language)
                    .tabItem {
                        Image(systemName: "rectangle.stack.fill")
                        Text(language == .portuguese ? "Flashcards" : "Flashcards")
                    }
                    .tag(3)

                ExportView(studyToolsManager: studyToolsManager, language: language)
                    .tabItem {
                        Image(systemName: "square.and.arrow.up")
                        Text(language == .portuguese ? "Exportar" : "Export")
                    }
                    .tag(4)
            }
            .navigationTitle(language == .portuguese ? "Ferramentas de Estudo" : "Study Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(themeManager.getColorScheme())
    }
}

// MARK: - Bookmarks View
struct BookmarksView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @StateObject private var dataManager = MedicalDatabaseManager()

    var bookmarkedDiseases: [Disease] {
        return dataManager.diseases.filter { disease in
            studyToolsManager.bookmarkedDiseases.contains(disease.nameEnglish)
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if bookmarkedDiseases.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text(language == .portuguese ?
                             "Nenhum favorito ainda" :
                             "No bookmarks yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(language == .portuguese ?
                             "Toque no ícone de favorito em qualquer condição médica para adicioná-la aqui" :
                             "Tap the bookmark icon on any medical condition to add it here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(bookmarkedDiseases) { disease in
                            BookmarkRow(
                                disease: disease,
                                language: language,
                                onRemove: {
                                    studyToolsManager.toggleBookmark(for: disease.nameEnglish)
                                }
                            )
                        }
                    }
                    .themedBackground()
                }
            }
            .navigationTitle(language == .portuguese ? "Favoritos" : "Bookmarks")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct BookmarkRow: View {
    let disease: Disease
    let language: AppLanguage
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(disease.getDisplayName(language))
                    .font(.headline)
                    .themedPrimaryText()

                Text(disease.category)
                    .font(.caption)
                    .themedSecondaryText()

                Text(disease.getDescription(language))
                    .font(.caption)
                    .themedSecondaryText()
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Study Notes View
struct StudyNotesView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @State private var showingAddNote = false
    @State private var showingNoteDetail: StudyNote? = nil

    var body: some View {
        NavigationView {
            VStack {
                if studyToolsManager.studyNotes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text(language == .portuguese ?
                             "Nenhuma anotação ainda" :
                             "No notes yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Button(language == .portuguese ? "Criar Primeira Anotação" : "Create First Note") {
                            showingAddNote = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(studyToolsManager.studyNotes) { note in
                            StudyNoteRow(note: note, language: language) {
                                showingNoteDetail = note
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                    .themedBackground()
                }
            }
            .navigationTitle(language == .portuguese ? "Anotações" : "Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddNote = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddNote) {
                AddStudyNoteView(studyToolsManager: studyToolsManager, language: language)
            }
            .sheet(item: $showingNoteDetail) { note in
                NoteDetailView(note: note, studyToolsManager: studyToolsManager, language: language)
            }
        }
    }

    private func deleteNotes(offsets: IndexSet) {
        for index in offsets {
            let note = studyToolsManager.studyNotes[index]
            studyToolsManager.deleteStudyNote(note)
        }
    }
}

struct StudyNoteRow: View {
    let note: StudyNote
    let language: AppLanguage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.diseaseName)
                        .font(.headline)
                        .themedPrimaryText()

                    Text(note.content)
                        .font(.body)
                        .themedSecondaryText()
                        .lineLimit(3)

                    Text(note.formattedLastModified)
                        .font(.caption)
                        .themedSecondaryText()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }
}

// MARK: - Add Study Note View
struct AddStudyNoteView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = MedicalDatabaseManager()

    @State private var selectedDisease = ""
    @State private var noteContent = ""
    @State private var selectedCategory = "General"

    private var categories: [String] {
        dataManager.getAllCategories()
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(language == .portuguese ? "Condição Médica" : "Medical Condition")) {
                    Picker(language == .portuguese ? "Selecionar Condição" : "Select Condition", selection: $selectedDisease) {
                        Text(language == .portuguese ? "Selecione..." : "Select...").tag("")
                        ForEach(dataManager.diseases, id: \.nameEnglish) { disease in
                            Text(disease.getDisplayName(language)).tag(disease.nameEnglish)
                        }
                    }
                }

                Section(header: Text(language == .portuguese ? "Categoria" : "Category")) {
                    Picker(language == .portuguese ? "Categoria" : "Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text(language == .portuguese ? "Suas Anotações" : "Your Notes")) {
                    TextEditor(text: $noteContent)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle(language == .portuguese ? "Nova Anotação" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language == .portuguese ? "Cancelar" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Salvar" : "Save") {
                        if !selectedDisease.isEmpty && !noteContent.isEmpty {
                            studyToolsManager.addStudyNote(
                                for: selectedDisease,
                                content: noteContent,
                                category: selectedCategory
                            )
                            dismiss()
                        }
                    }
                    .disabled(selectedDisease.isEmpty || noteContent.isEmpty)
                }
            }
        }
    }
}

// MARK: - Note Detail View
struct NoteDetailView: View {
    let note: StudyNote
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var editedContent: String = ""
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.diseaseName)
                            .font(.title2)
                            .bold()
                            .themedPrimaryText()

                        Text(note.formattedLastModified)
                            .font(.caption)
                            .themedSecondaryText()

                        Text(note.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }

                    Divider()

                    if isEditing {
                        TextEditor(text: $editedContent)
                            .frame(minHeight: 200)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        Text(note.content)
                            .font(.body)
                            .themedPrimaryText()
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(language == .portuguese ? "Detalhes da Anotação" : "Note Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language == .portuguese ? "Fechar" : "Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ?
                           (language == .portuguese ? "Salvar" : "Save") :
                           (language == .portuguese ? "Editar" : "Edit")) {
                        if isEditing {
                            studyToolsManager.updateStudyNote(note, content: editedContent)
                            isEditing = false
                        } else {
                            editedContent = note.content
                            isEditing = true
                        }
                    }
                }
            }
        }
        .onAppear {
            editedContent = note.content
        }
    }
}

// MARK: - Study Sets View
struct StudySetsView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @State private var showingCreateSet = false

    var body: some View {
        NavigationView {
            VStack {
                if studyToolsManager.studySets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text(language == .portuguese ?
                             "Nenhum conjunto de estudo" :
                             "No study sets")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Button(language == .portuguese ? "Criar Primeiro Conjunto" : "Create First Set") {
                            showingCreateSet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(studyToolsManager.studySets) { studySet in
                            StudySetRow(studySet: studySet, language: language)
                        }
                        .onDelete(perform: deleteStudySets)
                    }
                    .themedBackground()
                }
            }
            .navigationTitle(language == .portuguese ? "Conjuntos de Estudo" : "Study Sets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSet) {
                CreateStudySetView(studyToolsManager: studyToolsManager, language: language)
            }
        }
    }

    private func deleteStudySets(offsets: IndexSet) {
        for index in offsets {
            let studySet = studyToolsManager.studySets[index]
            studyToolsManager.deleteStudySet(studySet)
        }
    }
}

struct StudySetRow: View {
    let studySet: StudySet
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(studySet.name)
                    .font(.headline)
                    .themedPrimaryText()

                Spacer()

                Text("\(studySet.diseases.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }

            Text(studySet.description)
                .font(.body)
                .themedSecondaryText()
                .lineLimit(2)

            HStack {
                Text(language == .portuguese ? "Criado:" : "Created:")
                    .font(.caption)
                    .themedSecondaryText()
                Text(studySet.formattedCreatedDate)
                    .font(.caption)
                    .themedSecondaryText()

                Spacer()

                Text(language == .portuguese ? "Estudado:" : "Studied:")
                    .font(.caption)
                    .themedSecondaryText()
                Text(studySet.formattedLastStudied)
                    .font(.caption)
                    .themedSecondaryText()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Study Set View
struct CreateStudySetView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = MedicalDatabaseManager()

    @State private var setName = ""
    @State private var setDescription = ""
    @State private var selectedDiseases: [String] = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(language == .portuguese ? "Informações do Conjunto" : "Set Information")) {
                    TextField(language == .portuguese ? "Nome do conjunto" : "Set name", text: $setName)
                    TextField(language == .portuguese ? "Descrição" : "Description", text: $setDescription, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section(header: Text(language == .portuguese ? "Selecionar Condições" : "Select Conditions")) {
                    ForEach(dataManager.diseases, id: \.nameEnglish) { disease in
                        HStack {
                            Button(action: {
                                if selectedDiseases.contains(disease.nameEnglish) {
                                    selectedDiseases.removeAll { $0 == disease.nameEnglish }
                                } else {
                                    selectedDiseases.append(disease.nameEnglish)
                                }
                            }) {
                                Image(systemName: selectedDiseases.contains(disease.nameEnglish) ?
                                      "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedDiseases.contains(disease.nameEnglish) ? .blue : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(disease.getDisplayName(language))
                                    .font(.body)
                                Text(disease.category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }

                if !selectedDiseases.isEmpty {
                    Section(header: Text(language == .portuguese ? "Selecionadas (\(selectedDiseases.count))" : "Selected (\(selectedDiseases.count))")) {
                        ForEach(selectedDiseases, id: \.self) { diseaseName in
                            Text(diseaseName)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle(language == .portuguese ? "Novo Conjunto" : "New Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language == .portuguese ? "Cancelar" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Criar" : "Create") {
                        studyToolsManager.createStudySet(
                            name: setName,
                            description: setDescription,
                            diseases: selectedDiseases
                        )
                        dismiss()
                    }
                    .disabled(setName.isEmpty || selectedDiseases.isEmpty)
                }
            }
        }
    }
}

// MARK: - Flash Cards View
struct FlashCardsView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @State private var showingCreateCard = false
    @State private var showingStudySession = false

    var body: some View {
        NavigationView {
            VStack {
                if studyToolsManager.flashCards.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text(language == .portuguese ?
                             "Nenhum flashcard criado" :
                             "No flashcards created")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Button(language == .portuguese ? "Criar Primeiro Flashcard" : "Create First Flashcard") {
                            showingCreateCard = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        // Study session button
                        Button(action: { showingStudySession = true }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(language == .portuguese ? "Iniciar Sessão de Estudo" : "Start Study Session")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        List {
                            ForEach(studyToolsManager.flashCards) { flashCard in
                                FlashCardRow(flashCard: flashCard, language: language)
                            }
                            .onDelete(perform: deleteFlashCards)
                        }
                        .themedBackground()
                    }
                }
            }
            .navigationTitle(language == .portuguese ? "Flashcards" : "Flashcards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateCard = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateCard) {
                CreateFlashCardView(studyToolsManager: studyToolsManager, language: language)
            }
            .fullScreenCover(isPresented: $showingStudySession) {
                FlashCardStudyView(studyToolsManager: studyToolsManager, language: language)
            }
        }
    }

    private func deleteFlashCards(offsets: IndexSet) {
        for index in offsets {
            let flashCard = studyToolsManager.flashCards[index]
            studyToolsManager.deleteFlashCard(flashCard)
        }
    }
}

struct FlashCardRow: View {
    let flashCard: FlashCard
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flashCard.question)
                        .font(.headline)
                        .themedPrimaryText()
                        .lineLimit(2)

                    Text(flashCard.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(flashCard.difficulty.color.opacity(0.2))
                        .foregroundColor(flashCard.difficulty.color)
                        .cornerRadius(4)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(flashCard.difficulty.displayName(language: language))
                        .font(.caption)
                        .foregroundColor(flashCard.difficulty.color)

                    if flashCard.reviewCount > 0 {
                        Text(flashCard.formattedAccuracy)
                            .font(.caption)
                            .themedSecondaryText()
                    }
                }
            }

            if flashCard.reviewCount > 0 {
                HStack {
                    Text(language == .portuguese ? "Revisões:" : "Reviews:")
                        .font(.caption)
                        .themedSecondaryText()
                    Text("\(flashCard.reviewCount)")
                        .font(.caption)
                        .themedSecondaryText()

                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Flash Card View
struct CreateFlashCardView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = MedicalDatabaseManager()

    @State private var question = ""
    @State private var answer = ""
    @State private var selectedCategory = "General"
    @State private var selectedDifficulty: FlashCard.Difficulty = .medium

    private var categories: [String] {
        dataManager.getAllCategories()
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(language == .portuguese ? "Pergunta" : "Question")) {
                    TextEditor(text: $question)
                        .frame(minHeight: 60)
                }

                Section(header: Text(language == .portuguese ? "Resposta" : "Answer")) {
                    TextEditor(text: $answer)
                        .frame(minHeight: 80)
                }

                Section(header: Text(language == .portuguese ? "Categoria" : "Category")) {
                    Picker(language == .portuguese ? "Categoria" : "Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                Section(header: Text(language == .portuguese ? "Dificuldade" : "Difficulty")) {
                    Picker(language == .portuguese ? "Dificuldade" : "Difficulty", selection: $selectedDifficulty) {
                        ForEach(FlashCard.Difficulty.allCases, id: \.self) { difficulty in
                            HStack {
                                Text(difficulty.displayName(language: language))
                                Spacer()
                                Circle()
                                    .fill(difficulty.color)
                                    .frame(width: 12, height: 12)
                            }
                            .tag(difficulty)
                        }
                    }
                }
            }
            .navigationTitle(language == .portuguese ? "Novo Flashcard" : "New Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language == .portuguese ? "Cancelar" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Criar" : "Create") {
                        studyToolsManager.createFlashCard(
                            question: question,
                            answer: answer,
                            category: selectedCategory,
                            difficulty: selectedDifficulty
                        )
                        dismiss()
                    }
                    .disabled(question.isEmpty || answer.isEmpty)
                }
            }
        }
    }
}

// MARK: - Flash Card Study View
struct FlashCardStudyView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    @State private var currentCardIndex = 0
    @State private var showingAnswer = false
    @State private var sessionCards: [FlashCard] = []
    @State private var correctAnswers = 0

    var currentCard: FlashCard? {
        guard !sessionCards.isEmpty && currentCardIndex < sessionCards.count else { return nil }
        return sessionCards[currentCardIndex]
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Progress indicator
                HStack {
                    Text("\(currentCardIndex + 1) / \(sessionCards.count)")
                        .font(.headline)
                        .themedPrimaryText()

                    Spacer()

                    Text(language == .portuguese ?
                         "Corretas: \(correctAnswers)" :
                         "Correct: \(correctAnswers)")
                        .font(.headline)
                        .themedSecondaryText()
                }
                .padding(.horizontal)

                if let card = currentCard {
                    VStack(spacing: 20) {
                        // Difficulty indicator
                        HStack {
                            Text(card.difficulty.displayName(language: language))
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(card.difficulty.color.opacity(0.2))
                                .foregroundColor(card.difficulty.color)
                                .cornerRadius(12)

                            Spacer()

                            Text(card.category)
                                .font(.caption)
                                .themedSecondaryText()
                        }

                        // Card content
                        VStack(spacing: 16) {
                            Text(language == .portuguese ? "Pergunta:" : "Question:")
                                .font(.headline)
                                .themedPrimaryText()

                            Text(card.question)
                                .font(.body)
                                .themedPrimaryText()
                                .multilineTextAlignment(.center)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .themedSurface()
                                .cornerRadius(12)

                            if showingAnswer {
                                Text(language == .portuguese ? "Resposta:" : "Answer:")
                                    .font(.headline)
                                    .themedPrimaryText()

                                Text(card.answer)
                                    .font(.body)
                                    .themedPrimaryText()
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }

                        // Action buttons
                        VStack(spacing: 12) {
                            if !showingAnswer {
                                Button(language == .portuguese ? "Mostrar Resposta" : "Show Answer") {
                                    showingAnswer = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            } else {
                                HStack(spacing: 16) {
                                    Button(language == .portuguese ? "Incorreta" : "Incorrect") {
                                        nextCard(isCorrect: false)
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                    .controlSize(.large)

                                    Button(language == .portuguese ? "Correta" : "Correct") {
                                        nextCard(isCorrect: true)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    .controlSize(.large)
                                }
                            }
                        }
                    }
                    .padding()
                } else {
                    // Session complete
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)

                        Text(language == .portuguese ? "Sessão Completa!" : "Session Complete!")
                            .font(.title)
                            .bold()
                            .themedPrimaryText()

                        Text(language == .portuguese ?
                             "Você acertou \(correctAnswers) de \(sessionCards.count) cards" :
                             "You got \(correctAnswers) out of \(sessionCards.count) cards correct")
                            .font(.headline)
                            .themedSecondaryText()
                            .multilineTextAlignment(.center)

                        Button(language == .portuguese ? "Finalizar" : "Finish") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }

                Spacer()
            }
            .navigationTitle(language == .portuguese ? "Estudo de Flashcards" : "Flashcard Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Sair" : "Exit") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            sessionCards = studyToolsManager.flashCards.shuffled()
        }
        .themedBackground()
    }

    private func nextCard(isCorrect: Bool) {
        if let card = currentCard {
            studyToolsManager.updateFlashCardStats(card, isCorrect: isCorrect)
            if isCorrect {
                correctAnswers += 1
            }
        }

        currentCardIndex += 1
        showingAnswer = false
    }
}

// MARK: - Export View
struct ExportView: View {
    @ObservedObject var studyToolsManager: StudyToolsManager
    let language: AppLanguage
    @State private var showingShareSheet = false
    @State private var exportedData = ""

    var statistics: StudyStatistics {
        studyToolsManager.getStudyStatistics()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Statistics overview
                    VStack(alignment: .leading, spacing: 16) {
                        Text(language == .portuguese ? "Resumo dos Dados" : "Data Summary")
                            .font(.headline)
                            .themedPrimaryText()

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            StatisticCard(
                                title: language == .portuguese ? "Favoritos" : "Bookmarks",
                                value: "\(statistics.totalBookmarks)",
                                icon: "bookmark.fill",
                                color: .blue
                            )

                            StatisticCard(
                                title: language == .portuguese ? "Anotações" : "Notes",
                                value: "\(statistics.totalNotes)",
                                icon: "note.text",
                                color: .green
                            )

                            StatisticCard(
                                title: language == .portuguese ? "Conjuntos" : "Sets",
                                value: "\(statistics.totalStudySets)",
                                icon: "folder.fill",
                                color: .orange
                            )

                            StatisticCard(
                                title: language == .portuguese ? "Flashcards" : "Flashcards",
                                value: "\(statistics.totalFlashCards)",
                                icon: "rectangle.stack.fill",
                                color: .purple
                            )
                        }
                    }

                    Divider()

                    // Export options
                    VStack(alignment: .leading, spacing: 16) {
                        Text(language == .portuguese ? "Exportar Dados" : "Export Data")
                            .font(.headline)
                            .themedPrimaryText()

                        Text(language == .portuguese ?
                             "Exporte todos os seus dados de estudo para backup ou para usar em outros dispositivos." :
                             "Export all your study data for backup or to use on other devices.")
                            .font(.body)
                            .themedSecondaryText()

                        Button(action: exportData) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text(language == .portuguese ? "Exportar Como Texto" : "Export as Text")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(language == .portuguese ? "Exportar" : "Export")
            .navigationBarTitleDisplayMode(.large)
            .themedBackground()
        }
        .sheet(isPresented: $showingShareSheet) {
            if !exportedData.isEmpty {
                ActivityViewController(activityItems: [exportedData])
            }
        }
    }

    private func exportData() {
        exportedData = studyToolsManager.exportStudyData(language: language)
        showingShareSheet = true
    }
}

struct StatisticCard: View {
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
                .font(.title2)
                .bold()
                .themedPrimaryText()

            Text(title)
                .font(.caption)
                .themedSecondaryText()
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .themedSurface()
        .cornerRadius(12)
    }
}

// MARK: - Activity View Controller for sharing
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}