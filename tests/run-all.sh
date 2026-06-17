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

# Run global-schema helper unit tests (4.A)
echo ">>> Running global-schema helper tests..."
if bash "$SCRIPT_DIR/test-global-schema.sh"; then
    echo ">>> Global-schema tests: ALL PASSED"
else
    echo ">>> Global-schema tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run Python unit tests
echo ">>> Running Python unit tests..."
if python -m unittest discover -s "$SCRIPT_DIR" -p "test_*.py"; then
    echo ">>> Python unit tests: ALL PASSED"
else
    echo ">>> Python unit tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run quality-signal contract test (C5)
echo ">>> Running quality-signal contract test..."
if bash "$SCRIPT_DIR/test-quality-signal-contract.sh"; then
    echo ">>> Quality-signal contract: ALL PASSED"
else
    echo ">>> Quality-signal contract: FAILURES DETECTED"
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
