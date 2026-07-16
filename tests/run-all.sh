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

# Run PreToolUse shell circuit breaker tests
echo ">>> Running PreToolUse shell circuit breaker tests..."
if bash "$SCRIPT_DIR/test-pretooluse-shell-circuit-breaker.sh"; then
    echo ">>> PreToolUse shell circuit breaker tests: ALL PASSED"
else
    echo ">>> PreToolUse shell circuit breaker tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run PostToolUse dirty-tracker tests (python; try python3 first, then python)
echo ">>> Running PostToolUse dirty-tracker tests..."
PY_BIN=""
command -v python3 > /dev/null 2>&1 && PY_BIN="python3"
[ -z "$PY_BIN" ] && command -v python > /dev/null 2>&1 && PY_BIN="python"
if [ -n "$PY_BIN" ] && "$PY_BIN" "$SCRIPT_DIR/test-posttooluse-dirty-tracker.py"; then
    echo ">>> PostToolUse dirty-tracker tests: ALL PASSED"
elif [ -z "$PY_BIN" ]; then
    echo ">>> PostToolUse dirty-tracker tests: SKIPPED (no python found)"
else
    echo ">>> PostToolUse dirty-tracker tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run learnings schema-fields contract test (v4.4.0: derived_from + review_after)
echo ">>> Running learnings schema-fields contract test..."
PY_BIN=""
command -v python3 > /dev/null 2>&1 && PY_BIN="python3"
[ -z "$PY_BIN" ] && command -v python > /dev/null 2>&1 && PY_BIN="python"
if [ -n "$PY_BIN" ] && "$PY_BIN" "$SCRIPT_DIR/test-learnings-schema-fields.py"; then
    echo ">>> Learnings schema-fields contract: ALL PASSED"
elif [ -z "$PY_BIN" ]; then
    echo ">>> Learnings schema-fields contract: SKIPPED (no python found)"
else
    echo ">>> Learnings schema-fields contract: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Python unit tests + quality-signal contract test removed in v4.0.0
# (tools/ watermark pipeline and quality-gate skill deleted)

# Run wrap-up long-term memory contract test
echo ">>> Running wrap-up long-term memory contract test..."
if bash "$SCRIPT_DIR/test-wrap-up-long-term-memory-contract.sh"; then
    echo ">>> Wrap-up long-term memory contract: ALL PASSED"
else
    echo ">>> Wrap-up long-term memory contract: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run obsidian-sync decision promotion contract test (v4.5.0)
echo ">>> Running obsidian-sync decision promotion contract test..."
if bash "$SCRIPT_DIR/test-obsidian-sync-decision-promotion.sh"; then
    echo ">>> Obsidian-sync decision promotion contract: ALL PASSED"
else
    echo ">>> Obsidian-sync decision promotion contract: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run stage-0 preprocess-state tests (v4.7.0)
echo ">>> Running preprocess-state tests..."
PY_BIN=""
command -v python3 > /dev/null 2>&1 && PY_BIN="python3"
[ -z "$PY_BIN" ] && command -v python > /dev/null 2>&1 && PY_BIN="python"
if [ -n "$PY_BIN" ] && "$PY_BIN" "$SCRIPT_DIR/test-preprocess-state.py"; then
    echo ">>> Preprocess-state tests: ALL PASSED"
elif [ -z "$PY_BIN" ]; then
    echo ">>> Preprocess-state tests: SKIPPED (no python found)"
else
    echo ">>> Preprocess-state tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run handoff write-guard tests (T-19)
echo ">>> Running handoff write-guard tests..."
PY_BIN=""
command -v python3 > /dev/null 2>&1 && PY_BIN="python3"
[ -z "$PY_BIN" ] && command -v python > /dev/null 2>&1 && PY_BIN="python"
if [ -n "$PY_BIN" ] && "$PY_BIN" "$SCRIPT_DIR/test-handoff-write-guard.py"; then
    echo ">>> Handoff write-guard tests: ALL PASSED"
elif [ -z "$PY_BIN" ]; then
    echo ">>> Handoff write-guard tests: SKIPPED (no python found)"
else
    echo ">>> Handoff write-guard tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run model-routing SSoT tests (v4.7.0)
echo ">>> Running model-routing SSoT tests..."
if bash "$SCRIPT_DIR/test-model-routing.sh"; then
    echo ">>> Model-routing SSoT tests: ALL PASSED"
else
    echo ">>> Model-routing SSoT tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run cost-trace tests (v4.7.0)
echo ">>> Running cost-trace tests..."
if bash "$SCRIPT_DIR/test-cost-trace.sh"; then
    echo ">>> Cost-trace tests: ALL PASSED"
else
    echo ">>> Cost-trace tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""

# Run pattern rueckfluss contract test (v4.6.0: implemented_by/validated_by + delta gate)
echo ">>> Running pattern rueckfluss contract test..."
if bash "$SCRIPT_DIR/test-pattern-rueckfluss-contract.sh"; then
    echo ">>> Pattern rueckfluss contract: ALL PASSED"
else
    echo ">>> Pattern rueckfluss contract: FAILURES DETECTED"
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
