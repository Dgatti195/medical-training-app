import SwiftUI
import Foundation

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme = .system
    @Published var fontSizeScale: FontSizeScale = .medium
    @Published var isHighContrastEnabled = false
    @Published var isReducedMotionEnabled = false
    @Published var isVoiceOverOptimized = false

    private let themeKey = "AppTheme"
    private let fontScaleKey = "FontSizeScale"
    private let highContrastKey = "HighContrast"
    private let reducedMotionKey = "ReducedMotion"
    private let voiceOverKey = "VoiceOver"

    init() {
        loadSettings()
        setupAccessibilityObservers()
    }

    // MARK: - Theme Management
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }

    func setFontScale(_ scale: FontSizeScale) {
        fontSizeScale = scale
        UserDefaults.standard.set(scale.rawValue, forKey: fontScaleKey)
    }

    func setHighContrast(_ enabled: Bool) {
        isHighContrastEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: highContrastKey)
    }

    func setReducedMotion(_ enabled: Bool) {
        isReducedMotionEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: reducedMotionKey)
    }

    func setVoiceOverOptimization(_ enabled: Bool) {
        isVoiceOverOptimized = enabled
        UserDefaults.standard.set(enabled, forKey: voiceOverKey)
    }

    private func loadSettings() {
        if let themeRaw = UserDefaults.standard.object(forKey: themeKey) as? String,
           let theme = AppTheme(rawValue: themeRaw) {
            currentTheme = theme
        }

        if let scaleRaw = UserDefaults.standard.object(forKey: fontScaleKey) as? String,
           let scale = FontSizeScale(rawValue: scaleRaw) {
            fontSizeScale = scale
        }

        isHighContrastEnabled = UserDefaults.standard.bool(forKey: highContrastKey)
        isReducedMotionEnabled = UserDefaults.standard.bool(forKey: reducedMotionKey)
        isVoiceOverOptimized = UserDefaults.standard.bool(forKey: voiceOverKey)
    }

    private func setupAccessibilityObservers() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if UIAccessibility.isReduceMotionEnabled {
                self?.setReducedMotion(true)
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if UIAccessibility.isVoiceOverRunning {
                self?.setVoiceOverOptimization(true)
            }
        }
    }

    // MARK: - Color Schemes
    func getColorScheme() -> ColorScheme? {
        switch currentTheme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        case .highContrast:
            return .dark
        case .colorBlindFriendly:
            return nil
        }
    }

    // MARK: - Themed Colors
    struct ThemedColors {
        let primary: Color
        let secondary: Color
        let background: Color
        let surface: Color
        let error: Color
        let success: Color
        let warning: Color
        let accent: Color

        static func getColors(for theme: AppTheme, highContrast: Bool) -> ThemedColors {
            switch theme {
            case .system, .light:
                return ThemedColors(
                    primary: highContrast ? .black : .blue,
                    secondary: highContrast ? Color(.systemGray2) : Color(.systemGray),
                    background: highContrast ? .white : Color(.systemBackground),
                    surface: highContrast ? Color(.systemGray6) : Color(.systemGray6),
                    error: highContrast ? Color(.systemRed) : .red,
                    success: highContrast ? Color(.systemGreen) : .green,
                    warning: highContrast ? Color(.systemOrange) : .orange,
                    accent: highContrast ? Color(.systemBlue) : .blue
                )
            case .dark:
                return ThemedColors(
                    primary: highContrast ? .white : .blue,
                    secondary: highContrast ? Color(.systemGray2) : Color(.systemGray),
                    background: highContrast ? .black : Color(.systemBackground),
                    surface: highContrast ? Color(.systemGray5) : Color(.systemGray6),
                    error: highContrast ? Color(.systemRed) : .red,
                    success: highContrast ? Color(.systemGreen) : .green,
                    warning: highContrast ? Color(.systemOrange) : .orange,
                    accent: highContrast ? Color(.systemBlue) : .blue
                )
            case .highContrast:
                return ThemedColors(
                    primary: .white,
                    secondary: Color(.systemGray2),
                    background: .black,
                    surface: Color(.systemGray5),
                    error: Color(.systemRed),
                    success: Color(.systemGreen),
                    warning: Color(.systemYellow),
                    accent: Color(.systemBlue)
                )
            case .colorBlindFriendly:
                return ThemedColors(
                    primary: Color(.systemIndigo),
                    secondary: Color(.systemGray),
                    background: Color(.systemBackground),
                    surface: Color(.systemGray6),
                    error: Color(.systemBrown),
                    success: Color(.systemBlue),
                    warning: Color(.systemYellow),
                    accent: Color(.systemIndigo)
                )
            }
        }
    }

    var themedColors: ThemedColors {
        ThemedColors.getColors(for: currentTheme, highContrast: isHighContrastEnabled)
    }
}

// MARK: - Theme Types
enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    case highContrast = "high_contrast"
    case colorBlindFriendly = "color_blind"

    func getDisplayName(language: AppLanguage) -> String {
        switch self {
        case .system:
            return language == .portuguese ? "Sistema" : "System"
        case .light:
            return language == .portuguese ? "Claro" : "Light"
        case .dark:
            return language == .portuguese ? "Escuro" : "Dark"
        case .highContrast:
            return language == .portuguese ? "Alto Contraste" : "High Contrast"
        case .colorBlindFriendly:
            return language == .portuguese ? "Daltonismo" : "Color Blind Friendly"
        }
    }

    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .highContrast: return "circle.righthalf.filled"
        case .colorBlindFriendly: return "eye.fill"
        }
    }

    var description: String {
        switch self {
        case .system: return "Follows device settings"
        case .light: return "Light background, dark text"
        case .dark: return "Dark background, light text"
        case .highContrast: return "Maximum contrast for visibility"
        case .colorBlindFriendly: return "Alternative colors for accessibility"
        }
    }

    func getDescription(_ language: AppLanguage) -> String {
        switch self {
        case .system:
            return language == .portuguese ? "Segue as configurações do dispositivo" : "Follows device settings"
        case .light:
            return language == .portuguese ? "Fundo claro, texto escuro" : "Light background, dark text"
        case .dark:
            return language == .portuguese ? "Fundo escuro, texto claro" : "Dark background, light text"
        case .highContrast:
            return language == .portuguese ? "Contraste máximo para melhor visibilidade" : "Maximum contrast for visibility"
        case .colorBlindFriendly:
            return language == .portuguese ? "Cores alternativas para acessibilidade" : "Alternative colors for accessibility"
        }
    }
}

enum FontSizeScale: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extra_large"

    func getDisplayName(language: AppLanguage) -> String {
        switch self {
        case .small:
            return language == .portuguese ? "Pequeno" : "Small"
        case .medium:
            return language == .portuguese ? "Médio" : "Medium"
        case .large:
            return language == .portuguese ? "Grande" : "Large"
        case .extraLarge:
            return language == .portuguese ? "Extra Grande" : "Extra Large"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }
}

// MARK: - View Extensions
extension View {
    func themedFont(_ font: Font, themeManager: ThemeManager = ThemeManager.shared) -> some View {
        self.font(font.scaledFont(scale: themeManager.fontSizeScale.multiplier))
    }

    func accessibleTapTarget() -> some View {
        self.frame(minWidth: 44, minHeight: 44)
    }

    func reducedMotionSafe(animation: Animation?, themeManager: ThemeManager = ThemeManager.shared) -> some View {
        self.animation(themeManager.isReducedMotionEnabled ? nil : animation, value: 1)
    }

    func voiceOverLabel(_ label: String) -> some View {
        self.accessibilityLabel(label)
    }

    func voiceOverHint(_ hint: String) -> some View {
        self.accessibilityHint(hint)
    }
}

extension Font {
    func scaledFont(scale: CGFloat) -> Font {
        switch self {
        case .largeTitle: return .system(size: 34 * scale, weight: .bold, design: .default)
        case .title: return .system(size: 28 * scale, weight: .bold, design: .default)
        case .title2: return .system(size: 22 * scale, weight: .bold, design: .default)
        case .title3: return .system(size: 20 * scale, weight: .semibold, design: .default)
        case .headline: return .system(size: 17 * scale, weight: .semibold, design: .default)
        case .body: return .system(size: 17 * scale, weight: .regular, design: .default)
        case .callout: return .system(size: 16 * scale, weight: .regular, design: .default)
        case .subheadline: return .system(size: 15 * scale, weight: .regular, design: .default)
        case .footnote: return .system(size: 13 * scale, weight: .regular, design: .default)
        case .caption: return .system(size: 12 * scale, weight: .regular, design: .default)
        case .caption2: return .system(size: 11 * scale, weight: .regular, design: .default)
        default: return self
        }
    }
}

// MARK: - Themed View Modifiers
struct ThemedBackground: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .background(themeManager.themedColors.background)
    }
}

struct ThemedSurface: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .background(themeManager.themedColors.surface)
    }
}

struct ThemedPrimaryText: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .foregroundColor(themeManager.themedColors.primary)
    }
}

struct ThemedSecondaryText: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .foregroundColor(themeManager.themedColors.secondary)
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }

    func themedSurface() -> some View {
        modifier(ThemedSurface())
    }

    func themedPrimaryText() -> some View {
        modifier(ThemedPrimaryText())
    }

    func themedSecondaryText() -> some View {
        modifier(ThemedSecondaryText())
    }
}

// MARK: - Accessibility Features
struct AccessibilityFeature {
    let title: String
    let description: String
    let icon: String
    let isEnabled: Bool
    let toggle: () -> Void

    static func getFeatures(themeManager: ThemeManager, language: AppLanguage) -> [AccessibilityFeature] {
        return [
            AccessibilityFeature(
                title: language == .portuguese ? "Alto Contraste" : "High Contrast",
                description: language == .portuguese ?
                    "Aumenta o contraste para melhor visibilidade" :
                    "Increases contrast for better visibility",
                icon: "circle.righthalf.filled",
                isEnabled: themeManager.isHighContrastEnabled,
                toggle: { themeManager.setHighContrast(!themeManager.isHighContrastEnabled) }
            ),
            AccessibilityFeature(
                title: language == .portuguese ? "Movimento Reduzido" : "Reduced Motion",
                description: language == .portuguese ?
                    "Reduz animações e transições" :
                    "Reduces animations and transitions",
                icon: "tortoise.fill",
                isEnabled: themeManager.isReducedMotionEnabled,
                toggle: { themeManager.setReducedMotion(!themeManager.isReducedMotionEnabled) }
            ),
            AccessibilityFeature(
                title: language == .portuguese ? "Otimização VoiceOver" : "VoiceOver Optimization",
                description: language == .portuguese ?
                    "Melhora a experiência com leitor de tela" :
                    "Improves screen reader experience",
                icon: "speaker.wave.3.fill",
                isEnabled: themeManager.isVoiceOverOptimized,
                toggle: { themeManager.setVoiceOverOptimization(!themeManager.isVoiceOverOptimized) }
            )
        ]
    }
}