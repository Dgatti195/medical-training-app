import SwiftUI

// MARK: - Theme Settings View
struct ThemeSettingsView: View {
    @EnvironmentObject var userProfile: UserProfileManager
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var language: AppLanguage {
        userProfile.currentLanguage
    }

    var body: some View {
        NavigationView {
            List {
                // Theme Selection
                Section(
                    header: Text(language == .portuguese ? "Tema do Aplicativo" : "App Theme"),
                    footer: Text(language == .portuguese ?
                                "Escolha como o aplicativo deve aparecer" :
                                "Choose how the app should appear")
                ) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeSelectionRow(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme,
                            language: language
                        ) {
                            themeManager.setTheme(theme)
                        }
                    }
                }

                // Font Size
                Section(
                    header: Text(language == .portuguese ? "Tamanho da Fonte" : "Font Size"),
                    footer: Text(language == .portuguese ?
                                "Ajuste o tamanho do texto para melhor legibilidade" :
                                "Adjust text size for better readability")
                ) {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Aa")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(
                                value: Binding(
                                    get: { Double(FontSizeScale.allCases.firstIndex(of: themeManager.fontSizeScale) ?? 1) },
                                    set: { themeManager.setFontScale(FontSizeScale.allCases[Int($0)]) }
                                ),
                                in: 0...Double(FontSizeScale.allCases.count - 1),
                                step: 1
                            )

                            Text("Aa")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }

                        Text(language == .portuguese ? "Texto de Exemplo" : "Sample Text")
                            .themedFont(.body, themeManager: themeManager)
                            .animation(.easeInOut(duration: 0.3), value: themeManager.fontSizeScale)

                        HStack {
                            Text(language == .portuguese ? "Atual:" : "Current:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(themeManager.fontSizeScale.getDisplayName(language: language))
                                .font(.caption)
                                .fontWeight(.medium)

                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Accessibility Features
                Section(
                    header: Text(language == .portuguese ? "Acessibilidade" : "Accessibility"),
                    footer: Text(language == .portuguese ?
                                "Recursos para melhorar a experiência de usuários com necessidades especiais" :
                                "Features to improve experience for users with special needs")
                ) {
                    ForEach(AccessibilityFeature.getFeatures(themeManager: themeManager, language: language), id: \.title) { feature in
                        AccessibilityFeatureRow(feature: feature)
                    }
                }

                // Color Preview
                Section(
                    header: Text(language == .portuguese ? "Pré-visualização" : "Preview"),
                    footer: Text(language == .portuguese ?
                                "Veja como as cores aparecem no tema selecionado" :
                                "See how colors appear in the selected theme")
                ) {
                    ColorPreviewGrid(themeManager: themeManager, language: language)
                }

                // Reset Section
                Section {
                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.orange)

                            Text(language == .portuguese ? "Restaurar Padrões" : "Reset to Defaults")
                                .foregroundColor(.orange)
                        }
                    }
                    .accessibilityLabel(language == .portuguese ? "Restaurar todas as configurações para os valores padrão" : "Reset all settings to default values")
                }
            }
            .navigationTitle(language == .portuguese ? "Tema e Acessibilidade" : "Theme & Accessibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .portuguese ? "Fechar" : "Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(themeManager.getColorScheme())
    }

    private func resetToDefaults() {
        themeManager.setTheme(.system)
        themeManager.setFontScale(.medium)
        themeManager.setHighContrast(false)
        themeManager.setReducedMotion(false)
        themeManager.setVoiceOverOptimization(false)
    }
}

// MARK: - Theme Selection Row
struct ThemeSelectionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let language: AppLanguage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: theme.icon)
                    .foregroundColor(.blue)
                    .font(.title2)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.getDisplayName(language: language))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(getThemeDescription(theme))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibleTapTarget()
        .accessibilityLabel("\(theme.getDisplayName(language: language)). \(getThemeDescription(theme))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func getThemeDescription(_ theme: AppTheme) -> String {
        switch theme {
        case .system:
            return language == .portuguese ? "Segue as configurações do dispositivo" : "Follows device settings"
        case .light:
            return language == .portuguese ? "Fundo claro, texto escuro" : "Light background, dark text"
        case .dark:
            return language == .portuguese ? "Fundo escuro, texto claro" : "Dark background, light text"
        case .highContrast:
            return language == .portuguese ? "Contraste máximo para visibilidade" : "Maximum contrast for visibility"
        case .colorBlindFriendly:
            return language == .portuguese ? "Cores alternativas para acessibilidade" : "Alternative colors for accessibility"
        }
    }
}

// MARK: - Accessibility Feature Row
struct AccessibilityFeatureRow: View {
    let feature: AccessibilityFeature

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .foregroundColor(feature.isEnabled ? .blue : .secondary)
                .font(.title2)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)

                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { feature.isEnabled },
                set: { _ in feature.toggle() }
            ))
            .labelsHidden()
        }
        .accessibleTapTarget()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feature.title)
        .accessibilityValue(feature.isEnabled ? "Habilitado" : "Desabilitado")
        .accessibilityHint(feature.description)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Color Preview Grid
struct ColorPreviewGrid: View {
    @ObservedObject var themeManager: ThemeManager
    let language: AppLanguage
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 8 : 4), spacing: 12) {
                ColorSwatch(
                    color: themeManager.themedColors.primary,
                    label: language == .portuguese ? "Principal" : "Primary"
                )

                ColorSwatch(
                    color: themeManager.themedColors.secondary,
                    label: language == .portuguese ? "Secundária" : "Secondary"
                )

                ColorSwatch(
                    color: themeManager.themedColors.accent,
                    label: language == .portuguese ? "Destaque" : "Accent"
                )

                ColorSwatch(
                    color: themeManager.themedColors.success,
                    label: language == .portuguese ? "Sucesso" : "Success"
                )

                ColorSwatch(
                    color: themeManager.themedColors.error,
                    label: language == .portuguese ? "Erro" : "Error"
                )

                ColorSwatch(
                    color: themeManager.themedColors.warning,
                    label: language == .portuguese ? "Aviso" : "Warning"
                )

                ColorSwatch(
                    color: themeManager.themedColors.background,
                    label: language == .portuguese ? "Fundo" : "Background"
                )

                ColorSwatch(
                    color: themeManager.themedColors.surface,
                    label: language == .portuguese ? "Superfície" : "Surface"
                )
            }

            // Sample UI elements
            VStack(spacing: 12) {
                Text(language == .portuguese ? "Exemplo de Interface" : "Sample Interface")
                    .themedFont(.headline, themeManager: themeManager)
                    .themedPrimaryText()

                HStack {
                    Button(language == .portuguese ? "Botão Principal" : "Primary Button") {}
                        .padding()
                        .background(themeManager.themedColors.primary)
                        .foregroundColor(themeManager.themedColors.background)
                        .cornerRadius(8)

                    Button(language == .portuguese ? "Secundário" : "Secondary") {}
                        .padding()
                        .background(themeManager.themedColors.surface)
                        .foregroundColor(themeManager.themedColors.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.themedColors.primary, lineWidth: 1)
                        )
                        .cornerRadius(8)
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.themedColors.success)

                    Text(language == .portuguese ? "Operação bem-sucedida" : "Operation successful")
                        .themedFont(.body, themeManager: themeManager)
                        .themedSecondaryText()

                    Spacer()
                }

                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(themeManager.themedColors.warning)

                    Text(language == .portuguese ? "Atenção necessária" : "Attention required")
                        .themedFont(.body, themeManager: themeManager)
                        .themedSecondaryText()

                    Spacer()
                }
            }
            .padding()
            .themedSurface()
            .cornerRadius(12)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Color Swatch
struct ColorSwatch: View {
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) color")
    }
}

// MARK: - Theme Preview Card
struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let language: AppLanguage
    let onTap: () -> Void

    private var previewColors: ThemeManager.ThemedColors {
        ThemeManager.ThemedColors.getColors(for: theme, highContrast: false)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: theme.icon)
                        .foregroundColor(previewColors.primary)
                        .font(.title3)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(previewColors.primary)
                            .frame(width: 12, height: 12)

                        Circle()
                            .fill(previewColors.accent)
                            .frame(width: 12, height: 12)

                        Circle()
                            .fill(previewColors.success)
                            .frame(width: 12, height: 12)

                        Spacer()
                    }

                    Text(theme.getDisplayName(language: language))
                        .font(.caption)
                        .foregroundColor(previewColors.primary)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(previewColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(theme.getDisplayName(language: language))
        .accessibilityHint(language == .portuguese ? "Toque para selecionar este tema" : "Tap to select this theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Accessibility Testing View
struct AccessibilityTestingView: View {
    @ObservedObject var themeManager: ThemeManager
    let language: AppLanguage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(language == .portuguese ? "Teste de Acessibilidade" : "Accessibility Testing")
                    .themedFont(.largeTitle, themeManager: themeManager)
                    .themedPrimaryText()

                // Font size samples
                VStack(alignment: .leading, spacing: 8) {
                    Text(language == .portuguese ? "Tamanhos de Fonte" : "Font Sizes")
                        .themedFont(.headline, themeManager: themeManager)
                        .themedPrimaryText()

                    Text("Large Title - Lorem ipsum dolor")
                        .themedFont(.largeTitle, themeManager: themeManager)
                        .themedPrimaryText()

                    Text("Title - Lorem ipsum dolor")
                        .themedFont(.title, themeManager: themeManager)
                        .themedPrimaryText()

                    Text("Headline - Lorem ipsum dolor")
                        .themedFont(.headline, themeManager: themeManager)
                        .themedPrimaryText()

                    Text("Body - Lorem ipsum dolor sit amet")
                        .themedFont(.body, themeManager: themeManager)
                        .themedPrimaryText()

                    Text("Caption - Lorem ipsum dolor sit amet")
                        .themedFont(.caption, themeManager: themeManager)
                        .themedSecondaryText()
                }

                // Color contrast samples
                VStack(alignment: .leading, spacing: 8) {
                    Text(language == .portuguese ? "Contraste de Cores" : "Color Contrast")
                        .themedFont(.headline, themeManager: themeManager)
                        .themedPrimaryText()

                    HStack {
                        Text("Normal")
                            .padding()
                            .background(themeManager.themedColors.primary)
                            .foregroundColor(themeManager.themedColors.background)
                            .cornerRadius(8)

                        Text("Success")
                            .padding()
                            .background(themeManager.themedColors.success)
                            .foregroundColor(themeManager.themedColors.background)
                            .cornerRadius(8)

                        Text("Error")
                            .padding()
                            .background(themeManager.themedColors.error)
                            .foregroundColor(themeManager.themedColors.background)
                            .cornerRadius(8)
                    }
                }

                // Interactive elements
                VStack(alignment: .leading, spacing: 8) {
                    Text(language == .portuguese ? "Elementos Interativos" : "Interactive Elements")
                        .themedFont(.headline, themeManager: themeManager)
                        .themedPrimaryText()

                    Button("Sample Button") {}
                        .accessibleTapTarget()
                        .padding()
                        .background(themeManager.themedColors.primary)
                        .foregroundColor(themeManager.themedColors.background)
                        .cornerRadius(8)

                    Toggle("Sample Toggle", isOn: .constant(true))
                        .accessibleTapTarget()
                }
            }
            .padding()
        }
        .themedBackground()
    }
}