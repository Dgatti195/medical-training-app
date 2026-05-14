#!/bin/bash
# =============================================================================
# Med.IA 4.0 - Marathon Autonomous Run
# Runs Claude Code repeatedly until time or budget limit is reached.
# Usage: ./scripts/claude-marathon-run.sh
# =============================================================================

set -euo pipefail

PROJECT_DIR="/Users/douglasgatti/medical-training-app"
LOG_DIR="${PROJECT_DIR}/scripts/logs"
CLAUDE_BIN="/Users/douglasgatti/.local/bin/claude"
BRANCH="claude-auto"

# Limits
MAX_TOTAL_BUDGET=50
BUDGET_PER_RUN=10
MAX_DURATION_SECONDS=28800  # 8 hours
START_TIME=$(date +%s)
RUN_NUMBER=0

# Ensure Java + Maestro are on PATH
export PATH="/opt/homebrew/opt/openjdk/bin:$HOME/.maestro/bin:/opt/homebrew/bin:$PATH"
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
unset CLAUDECODE 2>/dev/null || true

mkdir -p "$LOG_DIR"

MARATHON_LOG="${LOG_DIR}/marathon-$(date +"%Y-%m-%d_%H-%M-%S").log"

log() {
    echo "$1" | tee -a "$MARATHON_LOG"
}

log "============================================="
log "Med.IA 4.0 - Marathon Run"
log "Started: $(date)"
log "Budget: \$${MAX_TOTAL_BUDGET} total, \$${BUDGET_PER_RUN}/run"
log "Time limit: $((MAX_DURATION_SECONDS / 60)) minutes"
log "============================================="
log ""

cd "$PROJECT_DIR"

# Ensure we're on the right branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    git checkout "$BRANCH" 2>&1 | tee -a "$MARATHON_LOG"
fi

# Loop until time or budget exhausted
TOTAL_SPENT=0
while true; do
    # Check time limit
    ELAPSED=$(( $(date +%s) - START_TIME ))
    if [ $ELAPSED -ge $MAX_DURATION_SECONDS ]; then
        log ""
        log "TIME LIMIT REACHED ($((ELAPSED / 60)) minutes elapsed)"
        break
    fi

    # Check budget limit
    REMAINING_BUDGET=$(( MAX_TOTAL_BUDGET - TOTAL_SPENT ))
    if [ $REMAINING_BUDGET -le 2 ]; then
        log ""
        log "BUDGET LIMIT REACHED (\$${TOTAL_SPENT} of \$${MAX_TOTAL_BUDGET} used)"
        break
    fi

    # Cap this run's budget
    RUN_BUDGET=$BUDGET_PER_RUN
    if [ $RUN_BUDGET -gt $REMAINING_BUDGET ]; then
        RUN_BUDGET=$REMAINING_BUDGET
    fi

    RUN_NUMBER=$((RUN_NUMBER + 1))
    MINUTES_ELAPSED=$((ELAPSED / 60))
    RUN_LOG="${LOG_DIR}/marathon-run-${RUN_NUMBER}-$(date +"%H-%M-%S").log"

    log "--- Run #${RUN_NUMBER} | \$${TOTAL_SPENT}/\$${MAX_TOTAL_BUDGET} spent | ${MINUTES_ELAPSED}min elapsed | Budget: \$${RUN_BUDGET} ---"

    # Run Claude
    "$CLAUDE_BIN" \
        --print \
        --dangerously-skip-permissions \
        --max-budget-usd "$RUN_BUDGET" \
        --model sonnet \
        "You are running autonomously to improve the Med.IA 4.0 medical training app.

INSTRUCTIONS:
1. Read CLAUDE.md for project context and rules.
2. Read IMPROVEMENTS.md to find the next uncompleted task (the first one with [ ] checkboxes).
3. Work on ONLY ONE task section per run (e.g., just task 1.2 or just task 1.3).
4. Make the changes carefully. Ensure Swift code compiles correctly.
5. After completing the task, update IMPROVEMENTS.md:
   - Check off completed items: [x]
   - Add a dated entry under ## Completed with a brief summary of what you did.
6. Do NOT commit any changes. Do NOT run git add or git commit.
7. Do NOT modify .gitignore, config/.env, or the Xcode project file unless the task specifically requires it.

IMPORTANT CONSTRAINTS:
- Preserve all existing functionality.
- Maintain bilingual support (English and Portuguese) for any user-facing strings.
- Do not add new package dependencies.
- Do not delete files without creating replacements first.
- Keep changes focused and reviewable - prefer small, clean changes over big rewrites.
- If a refactoring task is too large for one run, do a portion and note progress in IMPROVEMENTS.md.
- Build with xcodebuild after making changes to verify 0 errors.

OBSERVATIONS: As you work, add any bugs, UX issues, architectural problems, or improvement ideas you notice to a file called OBSERVATIONS.md. This is a running list of things you noticed while working — not just what you fixed, but what ELSE could be improved. Format each observation with a severity (CRITICAL/HIGH/MEDIUM/LOW) and a brief description.

START: Read CLAUDE.md, then IMPROVEMENTS.md, then begin working on the next task." 2>&1 | tee -a "$RUN_LOG"

    # Estimate cost (rough: $10 per run worst case)
    TOTAL_SPENT=$((TOTAL_SPENT + RUN_BUDGET))

    log ""
    log "Run #${RUN_NUMBER} completed at $(date)"
    log "Files changed so far:"
    git diff --stat 2>&1 | tee -a "$MARATHON_LOG"
    log ""

    # Brief pause between runs
    sleep 5
done

DURATION_MIN=$(( ($(date +%s) - START_TIME) / 60 ))

# Generate marathon report
REPORT_FILE="${LOG_DIR}/marathon-report-$(date +"%Y-%m-%d_%H-%M-%S").md"

{
    echo "# Marathon Run Report — $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "## Summary"
    echo "- **Total runs:** ${RUN_NUMBER}"
    echo "- **Estimated spend:** \$${TOTAL_SPENT} of \$${MAX_TOTAL_BUDGET} budget"
    echo "- **Duration:** ${DURATION_MIN} minutes"
    echo "- **Budget per run:** \$${BUDGET_PER_RUN}"
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
    echo "## Tasks Completed (from IMPROVEMENTS.md)"
    echo '```'
    git diff IMPROVEMENTS.md 2>/dev/null | grep '^+.*\[x\]' | head -30 || echo "(none detected)"
    echo '```'
    echo ""
    echo "## New Observations"
    echo '```'
    git diff OBSERVATIONS.md 2>/dev/null | grep '^+' | grep -v '^+++' | head -30 || echo "(none)"
    echo '```'
    echo ""
    echo "## Per-Run Logs"
    for i in $(seq 1 $RUN_NUMBER); do
        RUN_LOG_MATCH=$(ls -t "${LOG_DIR}"/marathon-run-${i}-*.log 2>/dev/null | head -1)
        if [ -n "$RUN_LOG_MATCH" ]; then
            echo "- Run #${i}: $(basename "$RUN_LOG_MATCH")"
        fi
    done
} > "$REPORT_FILE"

log ""
log "============================================="
log "Marathon complete!"
log "Total runs: ${RUN_NUMBER}"
log "Estimated spend: \$${TOTAL_SPENT} of \$${MAX_TOTAL_BUDGET}"
log "Duration: ${DURATION_MIN} minutes"
log "============================================="
log ""

# Print the full report
cat "$REPORT_FILE" | tee -a "$MARATHON_LOG"

log ""
log "Full report: $REPORT_FILE"
log "Review: ./scripts/review-changes.sh"
log "Observations: cat OBSERVATIONS.md"
