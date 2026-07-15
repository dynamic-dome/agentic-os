#!/usr/bin/env bash
# Tests for scripts/model-routing.sh — the model-class SSoT (v4.7.0).
# Exit codes: 0 = all pass, 1 = failures found

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MR="$PLUGIN_ROOT/scripts/model-routing.sh"
ERRORS=0
TESTS=0
PASSED=0

pass() { TESTS=$((TESTS + 1)); PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { TESTS=$((TESTS + 1)); ERRORS=$((ERRORS + 1)); echo "  FAIL: $1"; }

echo "=== model-routing SSoT tests ==="

# 1. Script exists and `list` exits 0
if [ -f "$MR" ] && OUT=$(bash "$MR" list); then
    pass "list runs and exits 0"
else
    fail "scripts/model-routing.sh missing or 'list' failed"
    echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
    exit 1
fi

# 2. Exactly 9 rows (one per skill)
n=$(echo "$OUT" | grep -c .)
if [ "$n" -eq 9 ]; then pass "list has 9 rows"; else fail "list has $n rows (expected 9)"; fi

# 3. Every listed skill directory exists
while IFS=$'\t' read -r sk cls mdl eff; do
    if [ -d "$PLUGIN_ROOT/skills/$sk" ]; then
        pass "skill dir exists: $sk"
    else
        fail "SSoT lists unknown skill: $sk"
    fi
done <<< "$OUT"

# 4. Classes are from the allowed set
if echo "$OUT" | awk -F'\t' '{print $2}' | grep -vqE '^(deterministic|cheap-read|cheap-write|standard|strong)$'; then
    fail "list contains invalid class value"
else
    pass "all classes valid"
fi

# 5. cheap-write rows use sonnet; standard/strong rows use '-'
if echo "$OUT" | awk -F'\t' '$2=="cheap-write" && $3!="sonnet"' | grep -q .; then
    fail "cheap-write row without model=sonnet"
else
    pass "cheap-write => sonnet"
fi
if echo "$OUT" | awk -F'\t' '($2=="standard" || $2=="strong") && ($3!="-" || $4!="-")' | grep -q .; then
    fail "standard/strong row must have model=- and effort=-"
else
    pass "standard/strong => inherit (-)"
fi

# 6. list-agents: 3 rows, each agent file exists
AOUT=$(bash "$MR" list-agents)
an=$(echo "$AOUT" | grep -c .)
if [ "$an" -eq 3 ]; then pass "list-agents has 3 rows"; else fail "list-agents has $an rows (expected 3)"; fi
while IFS=$'\t' read -r ag cls mdl eff; do
    if [ -f "$PLUGIN_ROOT/agents/$ag.md" ]; then
        pass "agent file exists: $ag"
    else
        fail "SSoT lists unknown agent: $ag"
    fi
done <<< "$AOUT"

# 7. Unknown command exits 2
bash "$MR" bogus >/dev/null 2>&1
if [ "$?" -eq 2 ]; then pass "unknown command exits 2"; else fail "unknown command must exit 2"; fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
