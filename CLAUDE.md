# Med.IA 4.0 - Project Context for Claude Code

## Project Overview
Med.IA 4.0 is an AI-powered medical education iOS app (SwiftUI) for medical students to practice diagnostic skills through interactive patient interviews powered by Claude AI. Fully bilingual (English/Portuguese-Brazil).

## Architecture

### iOS App (`ios-app/Med.IA4.0_CLAUDE/`)
- **Framework**: SwiftUI, iOS 16+
- **Database**: SQLite3 (raw SQL, NOT Core Data)
- **AI**: Claude API via URLSession
- **State**: @StateObject, @EnvironmentObject, @Published

### Key Files
| File | Lines | Purpose |
|------|-------|---------|
| `Med.IA4.0_CLAUDE/Med.IA4.0_CLAUDE/Med_IA4_0_CLAUDEApp.swift` | ~8,700 | **COMPILED** main monolith - models, views, managers, DB logic |
| `Med.IA4.0_CLAUDE/Med_IA4_0_CLAUDEApp.swift` (root) | stub | Stale backup — NOT compiled, do not edit |
| `NetworkManager.swift` | ~88 | Claude API networking |
| `MainAppWrapper.swift` | ~277 | App entry point and navigation |
| `ThemeManager.swift` | ~379 | App-wide theming |
| `ProgressTracker.swift` | ~322 | Daily streaks, session stats |
| `StudyToolsView.swift` | ~1,121 | Reference materials UI |
| `SocialHubView.swift` | ~805 | Community/leaderboard UI |
| `SocialFeaturesManager.swift` | ~541 | Social feature logic |

### Data Pipeline (`python-extraction/`)
- `pdf_extractor.py` - Extract medical data from PDF textbooks via Claude AI
- `manual_curator.py` - Review and curate extracted data
- `database_populator.py` - Populate SQLite from JSON
- `treatment_extractor.py` - Extract treatments (already completed, 1,941 treatments)

### Database (`medical_conditions.sqlite`)
- 447 diseases (bilingual names, categories, severity)
- 2,200 symptoms (with chief complaint flags)
- 846 physical findings
- 512 lab results
- Diagnostic hints
- 1,941 treatments (medication/procedure/lifestyle/supportive)
- All tables have `_english` and `_portuguese` columns

## Coding Conventions
- SwiftUI views use `@StateObject` for owned state, `@EnvironmentObject` for shared
- All user-facing strings must support both English and Portuguese via `AppLanguage` enum
- Database queries use raw SQLite3 C API (sqlite3_prepare_v2, sqlite3_step, etc.)
- Use `SQLITE_TRANSIENT` constant defined at top of main file
- Patient personalities: anxious, stoic, talkative, defensive, cooperative, confused
- Difficulty levels: beginner, intermediate, advanced, expert
- Training modes: Clinical (full simulation) and Basic (structured anamnese)

## Autonomous Run Rules

### MUST DO
- Read IMPROVEMENTS.md to find the next uncompleted task
- Mark tasks as `[DONE]` in IMPROVEMENTS.md when completed
- Add a dated entry to IMPROVEMENTS.md under "## Completed" when finishing a task
- Ensure all Swift files compile (no syntax errors)
- Preserve ALL existing functionality
- Maintain bilingual support (English + Portuguese) for any new user-facing strings
- Test database queries mentally for correctness

### MUST NOT
- Never commit changes (user reviews diffs manually)
- Never delete files without creating replacements
- Never modify the .gitignore or config/.env
- Never break existing imports or remove public APIs other code depends on
- Never add new Swift package dependencies (SPM)
- Never modify the Xcode project file (.xcodeproj) unless absolutely necessary
- Never hardcode API keys
- Never remove the `SQLITE_TRANSIENT` constant

### SAFE OPERATIONS
- Editing existing Swift files
- Creating new Swift files (add to same directory as related files)
- Refactoring code within files
- Running Python scripts in python-extraction/
- Reading/writing to output/ directory
- Modifying IMPROVEMENTS.md to track progress

## Simulator Testing with Maestro

Maestro CLI is installed for interacting with the iOS Simulator. Use it to tap buttons, type text, and navigate the app.

### Available Tools
- **Xcode**: `xcodebuild` for building the app
- **Simulator**: `xcrun simctl` for install/launch/screenshot
- **Maestro**: `maestro` for UI interaction (tap, type, swipe, assert)
- **Booted Simulator**: iPhone 16 Pro (iOS 18.5), ID: `3A062052-94B5-4FDD-BEFE-DBDC0A34386C`

### App Bundle ID
`DOL.Med-IA4-0-CLAUDE2`

### Maestro Quick Reference
```yaml
# Tap a button by its visible text
- tapOn: "English"

# Tap by ID (accessibility identifier)
- tapOn:
    id: "startInterviewButton"

# Type text into a focused field
- inputText: "Where does it hurt?"

# Swipe down to scroll
- swipe:
    direction: DOWN

# Take a screenshot
- takeScreenshot: "screen_name"

# Wait for an element
- assertVisible: "Patient Interview"

# Wait with timeout
- extendedWaitUntil:
    visible: "some text"
    timeout: 10000
```

### Running Maestro Flows
```bash
# Run a single flow file
maestro test flows/test_interview.yaml

# Run with the specific simulator
maestro test --device 3A062052-94B5-4FDD-BEFE-DBDC0A34386C flows/test_interview.yaml
```

### Build + Install + Launch (before Maestro)
```bash
# Build
xcodebuild build -project ios-app/Med.IA4.0_CLAUDE/Med.IA4.0_CLAUDE.xcodeproj \
  -scheme "Med.IA4.0_CLAUDE" \
  -destination "platform=iOS Simulator,id=3A062052-94B5-4FDD-BEFE-DBDC0A34386C" \
  -derivedDataPath build/

# Install
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Med.IA4.0_CLAUDE.app

# Launch
xcrun simctl launch booted DOL.Med-IA4-0-CLAUDE2
```

### Screenshots
Save to `screenshots/` directory with descriptive names.
