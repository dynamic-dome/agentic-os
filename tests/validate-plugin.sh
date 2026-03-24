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


# 8. sync-context skill has error handling guidance
echo ""
echo "-- sync-context error handling --"
SYNC_SKILL="$PLUGIN_ROOT/skills/sync-context/SKILL.md"
if [ -f "$SYNC_SKILL" ]; then
    if grep -qi "error\|corrupt\|fail\|missing\|not exist\|does not exist\|fallback" "$SYNC_SKILL"; then
        pass "sync-context: has error handling guidance"
    else
        fail "sync-context: missing error handling guidance (what to do when files are corrupt or missing)"
    fi
else
    fail "sync-context: SKILL.md not found"
fi

# 9. session-start.sh has file size guard before stats counting
echo ""
echo "-- session-start.sh size safety --"
SESSION_HOOK="$PLUGIN_ROOT/scripts/session-start.sh"
if [ -f "$SESSION_HOOK" ]; then
    if grep -q "wc -c\|wc -l\|file_size\|MAX_\|size_guard\|head -c\|-maxdepth\|stat " "$SESSION_HOOK"; then
        pass "session-start.sh: has file size guard"
    else
        fail "session-start.sh: missing file size guard — large files can cause timeout on SessionStart hook"
    fi
else
    fail "session-start.sh: not found"
fi

# 10. skill-generator checks for duplicate skill names in quality checklist
echo ""
echo "-- skill-generator duplicate check --"
SG_SKILL="$PLUGIN_ROOT/skills/skill-generator/SKILL.md"
if [ -f "$SG_SKILL" ]; then
    if grep -qi "duplicate\|unique\|already exist\|conflict\|exists" "$SG_SKILL"; then
        pass "skill-generator: has duplicate/uniqueness check"
    else
        fail "skill-generator: missing duplicate check — two patterns can generate the same skill name"
    fi
else
    fail "skill-generator: SKILL.md not found"
fi


# 11. context-detective has concrete output template
echo ""
echo "-- context-detective output template --"
CD_AGENT="$PLUGIN_ROOT/agents/context-detective.md"
if [ -f "$CD_AGENT" ]; then
    if grep -q "# Project:" "$CD_AGENT" || grep -q "project-context.md" "$CD_AGENT" && grep -q "\`\`\`" "$CD_AGENT"; then
        pass "context-detective: has concrete output template"
    else
        fail "context-detective: missing concrete output template — agents produce inconsistent context files"
    fi
else
    fail "context-detective: agent file not found"
fi

# 12. improvement-scout can handle plugin audit (not just .agent-memory/)
echo ""
echo "-- improvement-scout plugin audit scope --"
IS_AGENT="$PLUGIN_ROOT/agents/improvement-scout.md"
if [ -f "$IS_AGENT" ]; then
    if grep -qi "plugin\|skills/\|hooks.json\|SKILL.md" "$IS_AGENT"; then
        pass "improvement-scout: supports plugin structure audit"
    else
        fail "improvement-scout: only scans .agent-memory/ — cannot audit plugin structure when called by self-improve"
    fi
else
    fail "improvement-scout: agent file not found"
fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
