#!/usr/bin/env bash
# Runs all plugin validation tests.
# Exit codes: 0 = all pass, 1 = any failures

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_ERRORS=0

echo "========================================"
echo "  Agentic-OS Plugin Test Suite"
echo "========================================"
echo ""

# Run plugin structure validation
echo ">>> Running plugin structure validation..."
if bash "$SCRIPT_DIR/validate-plugin.sh"; then
    echo ">>> Plugin validation: ALL PASSED"
else
    echo ">>> Plugin validation: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run skill validation
echo ">>> Running skill validation..."
if bash "$SCRIPT_DIR/validate-skills.sh"; then
    echo ">>> Skill validation: ALL PASSED"
else
    echo ">>> Skill validation: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""
echo "========================================"
if [ "$TOTAL_ERRORS" -eq 0 ]; then
    echo "  ALL TEST SUITES PASSED"
else
    echo "  $TOTAL_ERRORS TEST SUITE(S) FAILED"
fi
echo "========================================"

[ "$TOTAL_ERRORS" -eq 0 ] && exit 0 || exit 1
