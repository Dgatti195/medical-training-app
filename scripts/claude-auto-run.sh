#!/bin/bash
# =============================================================================
# Med.IA 4.0 - Autonomous Claude Code Runner
# Runs Claude Code to make improvements without committing changes.
# Usage: ./scripts/claude-auto-run.sh [--dry-run]
# =============================================================================

set -euo pipefail

PROJECT_DIR="/Users/douglasgatti/medical-training-app"
LOG_DIR="${PROJECT_DIR}/scripts/logs"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/claude-run-${TIMESTAMP}.log"
CLAUDE_BIN="/Users/douglasgatti/.local/bin/claude"
BRANCH="claude-auto"

# Max budget per run (in USD) - safety cap
MAX_BUDGET="10.00"

# Create log directory if needed
mkdir -p "$LOG_DIR"

# Cleanup old logs (keep last 30)
ls -t "$LOG_DIR"/claude-run-*.log 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true

echo "=============================================" | tee "$LOG_FILE"
echo "Med.IA 4.0 - Autonomous Claude Code Run"      | tee -a "$LOG_FILE"
echo "Started: $(date)"                               | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"

# Check if claude CLI exists
if [ ! -f "$CLAUDE_BIN" ]; then
    echo "ERROR: Claude CLI not found at $CLAUDE_BIN" | tee -a "$LOG_FILE"
    exit 1
fi

# Clear nested session detection (allows running from within Claude Code or cron)
unset CLAUDECODE 2>/dev/null || true

# Ensure Java + Maestro are on PATH (needed for simulator interaction)
export PATH="/opt/homebrew/opt/openjdk/bin:$HOME/.maestro/bin:/opt/homebrew/bin:$PATH"
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

# Navigate to project
cd "$PROJECT_DIR"

# Ensure we're on the claude-auto branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "Switching to branch: $BRANCH" | tee -a "$LOG_FILE"
    git checkout "$BRANCH" 2>&1 | tee -a "$LOG_FILE"
fi

# Dry run mode - just show what would happen
if [ "${1:-}" = "--dry-run" ]; then
    echo ""
    echo "DRY RUN - Would execute Claude Code with:"
    echo "  Project: $PROJECT_DIR"
    echo "  Branch: $BRANCH"
    echo "  Budget: \$${MAX_BUDGET}"
    echo "  Log: $LOG_FILE"
    echo ""
    echo "Run without --dry-run to execute."
    exit 0
fi

echo "" | tee -a "$LOG_FILE"
echo "Running Claude Code autonomously..." | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Run Claude Code with full autonomy
"$CLAUDE_BIN" \
    --print \
    --dangerously-skip-permissions \
    --max-budget-usd "$MAX_BUDGET" \
    --model sonnet \
    "You are running autonomously to improve the Med.IA 4.0 medical training app.

INSTRUCTIONS:
1. Read CLAUDE.md for project context and rules.
2. Read IMPROVEMENTS.md to find the next uncompleted task (the first one with [ ] checkboxes).
3. Work on ONLY ONE task section per run (e.g., just task 0.1 or just task 0.2).
4. Make the changes carefully. Ensure Swift code compiles correctly.
5. After completing the task, update IMPROVEMENTS.md:
   - Check off completed items: [x]
   - Add a dated entry under ## Completed with a brief summary of what you did.
6. Do NOT commit any changes. Do NOT run git add or git commit.
7. Do NOT modify .gitignore, config/.env, or the Xcode project file.

IMPORTANT CONSTRAINTS:
- Preserve all existing functionality.
- Maintain bilingual support (English and Portuguese) for any user-facing strings.
- Do not add new package dependencies.
- Do not delete files without creating replacements first.
- Keep changes focused and reviewable - prefer small, clean changes over big rewrites.
- If a refactoring task is too large for one run, do a portion and note progress in IMPROVEMENTS.md.

START: Read CLAUDE.md, then IMPROVEMENTS.md, then begin working on the next task." 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"
echo "Run completed: $(date)"                         | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"

# Generate run report
REPORT_FILE="${LOG_DIR}/report-${TIMESTAMP}.md"

{
    echo "# Auto-Run Report — $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "## Budget"
    echo "- Max budget: \$${MAX_BUDGET}"
    echo ""
    echo "## Files Changed"
    echo '```'
    git diff --stat 2>/dev/null || echo "(no changes)"
    echo '```'
    echo ""
    echo "## Diff Summary"
    echo '```'
    git diff --shortstat 2>/dev/null || echo "(no changes)"
    echo '```'
    echo ""
    echo "## Recent IMPROVEMENTS.md Changes"
    echo '```'
    git diff IMPROVEMENTS.md 2>/dev/null | head -80 || echo "(no changes)"
    echo '```'
    echo ""
    echo "## Recent OBSERVATIONS.md Changes"
    echo '```'
    git diff OBSERVATIONS.md 2>/dev/null | head -40 || echo "(no changes)"
    echo '```'
} > "$REPORT_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"
echo "RUN REPORT" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"
cat "$REPORT_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Full report: $REPORT_FILE" | tee -a "$LOG_FILE"
echo "Review changes with: git diff" | tee -a "$LOG_FILE"
echo "Or run: ./scripts/review-changes.sh" | tee -a "$LOG_FILE"
