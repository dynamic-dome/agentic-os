#!/usr/bin/env bash
# Validates agentic-os plugin structure, JSON files, and schema compliance.
# Exit codes: 0 = all pass, 1 = failures found

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
TESTS=0
PASSED=0

pass() { TESTS=$((TESTS + 1)); PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { TESTS=$((TESTS + 1)); ERRORS=$((ERRORS + 1)); echo "  FAIL: $1"; }

check_json() {
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$1" 2>/dev/null
}

check_json_has() {
    node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); if(!(process.argv[2] in d)) process.exit(1)" "$1" "$2" 2>/dev/null
}

echo "=== Plugin Structure Validation ==="

# 1. plugin.json
echo ""
echo "-- plugin.json --"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
if [ -f "$MANIFEST" ]; then
    pass "plugin.json exists"
    if check_json "$MANIFEST"; then
        pass "plugin.json is valid JSON"
        for field in name version description; do
            if check_json_has "$MANIFEST" "$field"; then
                pass "plugin.json has '$field'"
            else
                fail "plugin.json missing '$field'"
            fi
        done
    else
        fail "plugin.json is not valid JSON"
    fi
else
    fail "plugin.json not found"
fi

# 2. hooks.json
echo ""
echo "-- hooks.json --"
HOOKS="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS" ]; then
    pass "hooks.json exists"
    if check_json "$HOOKS"; then
        pass "hooks.json is valid JSON"
    else
        fail "hooks.json is not valid JSON"
    fi
    # All prompt hooks must have timeout >= 10 to avoid silent failures
    min_timeout=$(node -e "
      const h = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
      const hooks = Object.values(h.hooks).flat().flatMap(g => g.hooks || []);
      const prompts = hooks.filter(h => h.type === 'prompt' && h.timeout !== undefined);
      console.log(Math.min(...prompts.map(h => h.timeout)));
    " "$HOOKS" 2>/dev/null)
    if [ -n "$min_timeout" ] && [ "$min_timeout" -ge 10 ]; then
        pass "hooks.json: all prompt hooks have timeout >= 10s (min: ${min_timeout}s)"
    else
        fail "hooks.json: prompt hook timeout too low (min: ${min_timeout}s) — risk of silent failure"
    fi
else
    fail "hooks.json not found"
fi

# 3. Memory JSON files
echo ""
echo "-- Memory JSON files --"
MEMORY_DIR="$PLUGIN_ROOT/.agent-memory"
if [ -d "$MEMORY_DIR" ]; then
    for jsonfile in $(find "$MEMORY_DIR" -name "*.json" 2>/dev/null); do
        bname=$(basename "$jsonfile")
        if check_json "$jsonfile"; then
            pass "$bname is valid JSON"
        else
            fail "$bname is NOT valid JSON"
        fi
    done
else
    echo "  SKIP: .agent-memory/ not found"
fi

# 4. Agent frontmatter
echo ""
echo "-- Agent frontmatter --"
for agent_file in "$PLUGIN_ROOT/agents"/*.md; do
    [ -f "$agent_file" ] || continue
    aname=$(basename "$agent_file")
    if head -1 "$agent_file" | grep -q "^---"; then
        pass "$aname has frontmatter"
        for field in description model; do
            if grep -q "^${field}:" "$agent_file"; then
                pass "$aname has '$field'"
            else
                fail "$aname missing '$field'"
            fi
        done
    else
        fail "$aname missing frontmatter"
    fi
done

# 4b. Reviewer agents must have plugin-specific rules
for agent_file in "$PLUGIN_ROOT/agents"/*reviewer*.md "$PLUGIN_ROOT/agents"/*gate*.md; do
    [ -f "$agent_file" ] || continue
    aname=$(basename "$agent_file")
    if grep -qi "hook\|skill.*dependenc\|plugin-specific\|tdd\|circular" "$agent_file"; then
        pass "$aname has plugin-specific review rules"
    else
        fail "$aname missing plugin-specific review rules"
    fi
done

# 5. Command frontmatter
echo ""
echo "-- Command frontmatter --"
for cmd_file in "$PLUGIN_ROOT/commands"/*.md; do
    [ -f "$cmd_file" ] || continue
    cname=$(basename "$cmd_file")
    if head -1 "$cmd_file" | grep -q "^---"; then
        pass "$cname has frontmatter"
    else
        fail "$cname missing frontmatter"
    fi
done

# 6. improvements/state.json
echo ""
echo "-- Improvements state --"
STATE="$PLUGIN_ROOT/improvements/state.json"
if [ -f "$STATE" ]; then
    if check_json_has "$STATE" "iteration"; then
        pass "state.json valid with iteration field"
    else
        fail "state.json missing 'iteration' field"
    fi
else
    echo "  SKIP: improvements/state.json not yet created"
fi

# 7. All skills referenced in DEPENDENCIES.md
echo ""
echo "-- DEPENDENCIES.md completeness --"
DEPS="$PLUGIN_ROOT/skills/DEPENDENCIES.md"
if [ -f "$DEPS" ]; then
    for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        sname=$(basename "$skill_dir")
        if grep -q "$sname" "$DEPS"; then
            pass "$sname documented in DEPENDENCIES.md"
        else
            fail "$sname missing from DEPENDENCIES.md"
        fi
    done
else
    echo "  SKIP: DEPENDENCIES.md not found"
fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
