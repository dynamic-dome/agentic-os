#!/usr/bin/env bash
# Unit tests for scripts/global-schema.sh — the pure, sourceable helpers that back
# the global cross-project memory layer (4.A). Unlike the marker/grep tests in the
# other suites, these call the functions with real inputs and check real outputs, so
# a broken invariant fails loudly (the L11 reason the logic lives in a script, not a prompt).
# Exit codes: 0 = all pass, 1 = failures found

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$PLUGIN_ROOT/scripts/global-schema.sh"
ERRORS=0
TESTS=0
PASSED=0

pass() { TESTS=$((TESTS + 1)); PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { TESTS=$((TESTS + 1)); ERRORS=$((ERRORS + 1)); echo "  FAIL: $1"; }

# assert_eq <label> <expected> <actual>
assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1 (= '$2')"; else fail "$1 — expected '$2', got '$3'"; fi
}
# assert_rc <label> <expected_rc> <actual_rc>
assert_rc() {
  if [ "$2" = "$3" ]; then pass "$1 (rc=$2)"; else fail "$1 — expected rc $2, got $3"; fi
}

echo "=== Global Schema Helper Tests ==="

if [ ! -f "$SCHEMA" ]; then
  fail "scripts/global-schema.sh missing — the 4.A helper contract must live in one sourceable file"
  echo ""
  echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
  [ "$ERRORS" -eq 0 ] && exit 0 || exit 1
fi

# shellcheck source=/dev/null
. "$SCHEMA"
# Denylist lives in mem-schema.sh (SSoT) — source it so is_denied() sees the array.
# shellcheck source=/dev/null
. "$PLUGIN_ROOT/scripts/mem-schema.sh" 2>/dev/null || true

echo "-- normalize: lowercase, trim, strip punctuation, collapse whitespace --"
assert_eq "normalize collapses + lowercases" "use pytest" "$(normalize '  Use   PyTest!! ')"
assert_eq "normalize is idempotent" "use pytest" "$(normalize "$(normalize '  Use   PyTest!! ')")"

echo "-- compute_scope: type + normalized SORTED tags --"
assert_eq "compute_scope sorts tags" "pattern|bash,windows" "$(compute_scope pattern 'windows,Bash')"
assert_eq "compute_scope sort is order-independent" "pattern|bash,windows" "$(compute_scope pattern 'Bash,windows')"

echo "-- passes_promotion_gate: conf>=0.6 AND occ>=3 AND projects>=2 --"
passes_promotion_gate 0.6 3 2; assert_rc "gate passes at exact thresholds" 0 $?
passes_promotion_gate 0.6 2 2; assert_rc "gate fails when occ<3" 1 $?
passes_promotion_gate 0.5 3 2; assert_rc "gate fails when conf<0.6" 1 $?
passes_promotion_gate 0.6 3 1; assert_rc "gate fails when projects<2" 1 $?

echo "-- apply_decay: -0.1 per 90 days, floor 0.3 --"
assert_eq "decay one step" "0.80" "$(apply_decay 0.9 90)"
assert_eq "decay floors at 0.3 (not 0.15)" "0.30" "$(apply_decay 0.35 180)"
assert_eq "decay no-op under 90 days" "0.70" "$(apply_decay 0.7 89)"

echo "-- is_denied: privacy denylist (MEM_GLOBAL_DENY_TAGS) --"
is_denied api_key; assert_rc "denied tag is blocked" 0 $?
is_denied credentials; assert_rc "credentials blocked" 0 $?
is_denied pytest; assert_rc "ordinary tag is allowed" 1 $?

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ] && exit 0 || exit 1
