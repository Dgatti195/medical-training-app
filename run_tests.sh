#!/bin/bash
# =============================================================================
# Med.IA 4.0 - Overnight Test Runner
# Runs comprehensive UI tests simulating medical student usage
# Usage: ./run_tests.sh [--all | --clinical | --basic | --features]
# =============================================================================

set -euo pipefail

# Configuration
export JAVA_HOME=/Users/douglasgatti/.local/java/jdk-21.0.10+7/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
MAESTRO="/Users/douglasgatti/.maestro/bin/maestro"
DEVICE_ID="3A062052-94B5-4FDD-BEFE-DBDC0A34386C"
APP_BUNDLE="DOL.Med-IA4-0-CLAUDE2"
PROJECT_DIR="/Users/douglasgatti/medical-training-app"
FLOWS_DIR="$PROJECT_DIR/flows"
REPORT_DIR="$PROJECT_DIR/test-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/test_report_$TIMESTAMP.md"
SCREENSHOT_DIR="$PROJECT_DIR/screenshots/test_$TIMESTAMP"

# Test flows to run
CLINICAL_FLOWS=("student_clinical_session.yaml")
BASIC_FLOWS=("student_basic_session.yaml")
FEATURE_FLOWS=("student_explore_features.yaml")
ALL_FLOWS=("${CLINICAL_FLOWS[@]}" "${BASIC_FLOWS[@]}" "${FEATURE_FLOWS[@]}")

# Parse args
RUN_MODE="${1:---all}"
case "$RUN_MODE" in
    --clinical) FLOWS=("${CLINICAL_FLOWS[@]}") ;;
    --basic)    FLOWS=("${BASIC_FLOWS[@]}") ;;
    --features) FLOWS=("${FEATURE_FLOWS[@]}") ;;
    --all)      FLOWS=("${ALL_FLOWS[@]}") ;;
    *)          echo "Usage: $0 [--all | --clinical | --basic | --features]"; exit 1 ;;
esac

# Setup
mkdir -p "$REPORT_DIR" "$SCREENSHOT_DIR"

# Start report
cat > "$REPORT_FILE" << EOF
# Med.IA 4.0 Test Report
**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Device:** iPhone 16 Pro (iOS 18.5) - Simulator
**Mode:** $RUN_MODE

---

## Summary

| Flow | Status | Duration |
|------|--------|----------|
EOF

echo ""
echo "============================================"
echo "  Med.IA 4.0 Overnight Test Runner"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Running ${#FLOWS[@]} test flow(s)"
echo "============================================"
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_START=$(date +%s)

for flow in "${FLOWS[@]}"; do
    FLOW_PATH="$FLOWS_DIR/$flow"
    FLOW_NAME="${flow%.yaml}"

    echo "--- Running: $flow ---"

    # Terminate app before each flow
    xcrun simctl terminate booted "$APP_BUNDLE" 2>/dev/null || true
    sleep 1

    FLOW_START=$(date +%s)

    # Run the flow
    if "$MAESTRO" test --device "$DEVICE_ID" "$FLOW_PATH" 2>&1 | tee "/tmp/maestro_${FLOW_NAME}.log"; then
        STATUS="PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  ✅ PASSED"
    else
        STATUS="FAIL"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  ❌ FAILED"

        # Take a failure screenshot
        xcrun simctl io booted screenshot "$SCREENSHOT_DIR/FAIL_${FLOW_NAME}.png" 2>/dev/null || true
    fi

    FLOW_END=$(date +%s)
    FLOW_DURATION=$((FLOW_END - FLOW_START))

    # Add to report
    echo "| $flow | $STATUS | ${FLOW_DURATION}s |" >> "$REPORT_FILE"

    echo "  Duration: ${FLOW_DURATION}s"
    echo ""
done

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))

# Append detailed section to report
cat >> "$REPORT_FILE" << EOF

## Results

- **Passed:** $PASS_COUNT
- **Failed:** $FAIL_COUNT
- **Total Duration:** ${TOTAL_DURATION}s

---

## Maestro Test Output Directory
\`~/.maestro/tests/\` (sorted by date, most recent first)

## Screenshots
\`$SCREENSHOT_DIR/\`

## Failure Details
EOF

# Append failure logs
for flow in "${FLOWS[@]}"; do
    FLOW_NAME="${flow%.yaml}"
    LOG="/tmp/maestro_${FLOW_NAME}.log"
    if [ -f "$LOG" ] && grep -q "FAILED" "$LOG"; then
        echo "" >> "$REPORT_FILE"
        echo "### $flow" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        grep -A2 "FAILED" "$LOG" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
    fi
done

echo "============================================"
echo "  Test Run Complete"
echo "  Passed: $PASS_COUNT / $((PASS_COUNT + FAIL_COUNT))"
echo "  Report: $REPORT_FILE"
echo "============================================"

# Exit with failure if any test failed
[ $FAIL_COUNT -eq 0 ]
