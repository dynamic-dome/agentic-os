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
        for field in name description model; do
            if grep -q "^${field}:" "$agent_file"; then
                pass "$aname has '$field'"
            else
                fail "$aname missing '$field'"
            fi
        done
        # Tool restriction key must be 'allowed_tools' (not bare 'tools')
        if grep -q "^tools:" "$agent_file"; then
            fail "$aname uses 'tools:' instead of 'allowed_tools:' — wrong frontmatter key"
        else
            pass "$aname uses correct tool key (allowed_tools or none)"
        fi
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

# 5b. Commands must use allowed_tools (underscore), not allowed-tools (hyphen)
echo ""
echo "-- Command allowed_tools key --"
for cmd_file in "$PLUGIN_ROOT/commands"/*.md; do
    [ -f "$cmd_file" ] || continue
    cname=$(basename "$cmd_file")
    if grep -q "^allowed-tools:" "$cmd_file"; then
        fail "$cname uses 'allowed-tools:' instead of 'allowed_tools:' — wrong frontmatter key (hyphen vs underscore)"
    else
        pass "$cname uses correct allowed_tools key (underscore) or omits it"
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

# 13. auto-commit command should not contain hardcoded model-specific co-author
echo ""
echo "-- auto-commit co-author portability --"
AC_CMD="$PLUGIN_ROOT/commands/auto-commit.md"
if [ -f "$AC_CMD" ]; then
    if grep -q "Claude Opus 4.6\|claude-opus-4\|claude-3-opus\|Claude Opus 3" "$AC_CMD"; then
        fail "auto-commit: has hardcoded model-specific co-author string — breaks portability across model versions"
    else
        pass "auto-commit: co-author string is model-portable"
    fi
else
    fail "auto-commit: command file not found"
fi

# 14. quality-gate agent should have explicit trigger phrases (not just examples)
echo ""
echo "-- quality-gate trigger phrases --"
QG_AGENT="$PLUGIN_ROOT/agents/quality-gate.md"
if [ -f "$QG_AGENT" ]; then
    if grep -qi "trigger\|Trigger\|phrases\|trigger:" "$QG_AGENT" || grep -qi "quality check\|pre-commit check\|is the code ready\|qualitaet" "$QG_AGENT"; then
        pass "quality-gate: has trigger phrases for discoverability"
    else
        fail "quality-gate: missing explicit trigger phrases — agent is hard to discover without them"
    fi
else
    fail "quality-gate: agent file not found"
fi


# 15. self-improve skill should not have hardcoded model-specific co-author string
echo ""
echo "-- self-improve co-author portability --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    if grep -q "Claude Opus 4.6\|claude-opus-4\|claude-3-opus\|Claude Opus 3" "$SI_SKILL"; then
        fail "self-improve: has hardcoded model-specific co-author string — breaks portability when model changes"
    else
        pass "self-improve: co-author string is model-portable"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 16. self-improve skill should not silently auto-push (commits must stay local until user decides)
echo ""
echo "-- self-improve no-auto-push policy --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    # The skill must explicitly state commits stay local / Do NOT push automatically
    if grep -qi "Do NOT push\|stay local\|no.*push\|not.*push.*auto\|commits stay local" "$SI_SKILL"; then
        pass "self-improve: explicitly states no auto-push (commits stay local)"
    else
        fail "self-improve: missing no-auto-push policy — Step 6 instructs 'git push' without user confirmation, risking unintended pushes"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 17. auto-commit command description must not claim it "pushes" automatically
#     (contradicts the no-auto-push policy established in iteration 8)
echo ""
echo "-- auto-commit no-auto-push consistency --"
AC_CMD="$PLUGIN_ROOT/commands/auto-commit.md"
if [ -f "$AC_CMD" ]; then
    # The description field (first YAML line with "description:") must not promise automatic push
    DESCRIPTION_LINE=$(grep -m1 "^description:" "$AC_CMD")
    if echo "$DESCRIPTION_LINE" | grep -qi "pushes\|push to"; then
        fail "auto-commit: description claims it auto-pushes — contradicts no-auto-push policy; update description to reflect push is optional"
    else
        pass "auto-commit: description is consistent with no-auto-push policy"
    fi
else
    fail "auto-commit: command file not found"
fi


# 18. Agents that write files must declare Write in allowed_tools
echo ""
echo "-- agent write-tool consistency --"
for agent_file in "$PLUGIN_ROOT/agents"/*.md; do
    [ -f "$agent_file" ] || continue
    aname=$(basename "$agent_file")
    # Check if agent body instructs writing to files
    if grep -qiE "^Write |^Append |write.*\.agent-memory|\.agent-memory.*write|write.*project-context|write.*quality/" "$agent_file"; then
        if grep -A20 "^allowed_tools:" "$agent_file" | grep -q "Write"; then
            pass "$aname: declares Write tool (agent writes files)"
        else
            fail "$aname: writes files but 'Write' missing from allowed_tools — tool may be blocked at runtime"
        fi
    fi
done


# 19. SubagentStop prompt hook must not instruct LLM to run bash commands
#     Prompt hooks run in LLM context without bash execution — instructing LLM
#     to "run git status" leads to hallucinated results; use agent context instead
echo ""
echo "-- SubagentStop hook no-bash-in-prompt --"
HOOKS_FILE="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_FILE" ]; then
    # Check if SubagentStop section contains misleading bash-run instructions
    # Use grep directly on the JSON file since the SubagentStop prompt is on one line
    if grep -A10 '"SubagentStop"' "$HOOKS_FILE" | grep -qiE "via \`git |run \`git |execute.*git |via git status|run git "; then
        fail "SubagentStop: prompt hook instructs LLM to run bash commands (e.g. 'via \`git status\`') — prompt hooks have no bash access, leads to hallucinated results"
    else
        pass "SubagentStop: prompt hook does not instruct LLM to run bash commands directly"
    fi
else
    fail "hooks.json not found"
fi


# 20. self-improve SKILL.md state.json history entry template must include
#     the extended tracking fields added since iteration 5
#     (false_alarm_count, quality_score, tests_plugin, tests_skill)
echo ""
echo "-- self-improve state history entry completeness --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    if grep -q "false_alarm_count" "$SI_SKILL" && grep -q "quality_score" "$SI_SKILL" && grep -q "tests_plugin" "$SI_SKILL"; then
        pass "self-improve: state.json history entry template includes extended tracking fields"
    else
        fail "self-improve: state.json history entry template missing extended fields (false_alarm_count, quality_score, tests_plugin, tests_skill) — agents following this template produce incomplete history entries"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 21. self-improve SKILL.md error handling must specify a concrete rollback command
#     "Revert the fix" is ambiguous — agents need a specific git command.
#     Accepted: git reset --hard (commit-hash checkpoint), git checkout ., git restore .
echo ""
echo "-- self-improve rollback command specificity --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    if grep -qE "git reset --hard|git checkout \.|git restore \." "$SI_SKILL"; then
        pass "self-improve: error handling specifies concrete rollback command"
    else
        fail "self-improve: error handling gives no concrete git rollback command — agents will guess and may lose test file changes"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 22. self-improve SKILL.md must instruct to create a safety checkpoint BEFORE making
#     changes. Accepted: commit-hash checkpoint (git rev-parse HEAD + git reset --hard)
#     or git stash. commit-hash is preferred as stash is fragile with untracked files.
echo ""
echo "-- self-improve pre-fix safety checkpoint --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    if grep -qE "checkpoint_sha|git rev-parse HEAD|safety checkpoint|git stash push" "$SI_SKILL"; then
        pass "self-improve: TDD Fix step includes safety checkpoint before making changes"
    else
        fail "self-improve: TDD Fix step missing safety checkpoint — cannot recover from failed fix without a checkpoint"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 23. self-improve SKILL.md Step 2 analysis prompt must instruct the agent to
#     read state.json history and skip previously-fixed weaknesses by name.
#     Without this, improvement-scout re-identifies the same things each run
#     and the loop wastes iterations re-fixing already-solved problems.
echo ""
echo "-- self-improve history dedup guidance --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    if grep -qiE "previously.fixed|skip.*history|history.*skip|state\.json.*history|already.fixed|dedup|avoid.*duplicate" "$SI_SKILL"; then
        pass "self-improve: analysis step instructs agent to skip previously-fixed weaknesses from history"
    else
        fail "self-improve: analysis step missing history dedup guidance — improvement-scout will re-identify already-fixed weaknesses causing wasted iterations"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 24. quality-gate agent hook timeout bounds must match the enforced policy (>= 10s)
#     quality-gate says "5-30s" but the plugin test enforces >= 10s minimum.
#     An agent following quality-gate could approve a hooks.json with 7s timeout
#     that fails the actual test suite.
echo ""
echo "-- quality-gate hook timeout policy consistency --"
QG_AGENT="$PLUGIN_ROOT/agents/quality-gate.md"
if [ -f "$QG_AGENT" ]; then
    # The quality-gate must not suggest a lower bound below 10s for hook timeouts
    if grep -qiE "timeout.*5-30|5-30s|minimum.*5s|5s.*minimum|\(5-" "$QG_AGENT"; then
        fail "quality-gate: specifies hook timeout range '5-30s' but plugin enforces >= 10s — quality-gate may approve hooks with 5-9s timeouts that fail tests"
    else
        pass "quality-gate: hook timeout lower bound is consistent with plugin policy (>= 10s)"
    fi
else
    fail "quality-gate: agent file not found"
fi


# 25. self-improve SKILL.md must instruct agents to filter weaknesses by severity
#     (only fix critical/warning, log suggestions without fixing) and report
#     "DIMINISHING RETURNS" when no actionable weaknesses remain.
#     Without this, agents waste iterations fixing cosmetic suggestions and never
#     gracefully exit when the plugin has no critical/warning-level issues.
echo ""
echo "-- self-improve severity filter and diminishing returns --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    # Must explicitly instruct: only fix critical/warning severity, log suggestions without fixing
    HAS_SEVERITY=$(grep -ciE "only fix critical|Only fix critical|fix critical.and.warning|critical.*warning.*only|suggestion.*do not fix|do not fix.*suggestion|log suggestion|suggestion.*log.*not fix" "$SI_SKILL")
    # Must explicitly name the diminishing-returns exit condition
    HAS_DIMINISHING=$(grep -ciE "DIMINISHING RETURNS|diminishing.returns" "$SI_SKILL")
    if [ "$HAS_SEVERITY" -gt 0 ] && [ "$HAS_DIMINISHING" -gt 0 ]; then
        pass "self-improve: instructs severity-based filtering and diminishing-returns exit condition"
    else
        fail "self-improve: missing severity filter (only fix critical/warning, log suggestions) and/or diminishing-returns exit — agents will fix trivial suggestions and never gracefully stop"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 26. improvement-scout agent must use critical/warning/suggestion severity labels
#     to match the self-improve severity filter. improvement-scout currently uses
#     HIGH/MEDIUM/LOW which causes label mismatch when self-improve interprets output.
#     Even though self-improve overrides the prompt for severity labels, the agent's
#     own output template should match the ecosystem standard to avoid confusion
#     when improvement-scout is called independently.
echo ""
echo "-- improvement-scout severity label consistency --"
IS_AGENT="$PLUGIN_ROOT/agents/improvement-scout.md"
if [ -f "$IS_AGENT" ]; then
    if grep -qiE "\[critical\]|\[warning\]|\[suggestion\]|severity.*critical|critical.*warning.*suggestion" "$IS_AGENT"; then
        pass "improvement-scout: uses critical/warning/suggestion severity labels consistent with self-improve filter"
    else
        fail "improvement-scout: uses HIGH/MEDIUM/LOW severity labels — mismatches self-improve's critical/warning/suggestion filter; update to use consistent labels"
    fi
else
    fail "improvement-scout: agent file not found"
fi


# 27. self-improve SKILL.md Step 2 must not have duplicate step numbers.
#     Duplicate numbering (two items labeled "2.") makes the procedure ambiguous —
#     agents may skip or repeat the feedback-check step.
echo ""
echo "-- self-improve step 2 no duplicate numbering --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    # Extract the Step 2 section and count how many lines start with "2. "
    # A correct numbered list has each number appear exactly once
    STEP2_SECTION=$(awk '/^### Step 2:/,/^### Step [^2]:/' "$SI_SKILL")
    DUP_COUNT=$(echo "$STEP2_SECTION" | grep -cE "^[[:space:]]*2\. ")
    if [ "$DUP_COUNT" -le 1 ]; then
        pass "self-improve: Step 2 has no duplicate step numbers"
    else
        fail "self-improve: Step 2 has $DUP_COUNT items numbered '2.' — duplicate numbering makes procedure ambiguous; renumber the feedback-check and subsequent steps"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 28. self-improve SKILL.md batch_start formula must use floor() for integer division.
#     Without floor(), agents using floating-point division compute wrong batch numbers.
#     E.g. iteration 22: ((22-1)/5)*5+1 = 4.2*5+1 = 22 (wrong) vs floor(4.2)*5+1 = 21 (correct).
echo ""
echo "-- self-improve batch formula uses floor --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    if grep -qE "floor\(\(" "$SI_SKILL"; then
        pass "self-improve: batch_start formula uses floor() for correct integer division"
    else
        fail "self-improve: batch_start formula missing floor() — floating-point division produces wrong batch file names (e.g. iteration 22 gives batch 22 instead of 21)"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 29. self-improve SKILL.md Step 7 report and Output Format section must use the
#     full path placeholder {batch_start}-{batch_end}, not the abbreviated {batch}.
#     Step 1 defines the correct filename as iterations-{batch_start:03d}-{batch_end:03d}.md
#     but Step 7 and Output Format reference iterations-{batch}.md — agents following
#     the report template will log the wrong filename, making iteration docs hard to find.
echo ""
echo "-- self-improve step 7 report uses correct batch placeholder --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    # Check that nowhere after "### Step 7" or "## Output Format" does "{batch}" appear alone
    # (without being part of "{batch_start}" or "{batch_end}")
    BARE_BATCH=$(grep -nE "iterations-\{batch\}" "$SI_SKILL" | grep -vE "\{batch_start\}|\{batch_end\}")
    if [ -z "$BARE_BATCH" ]; then
        pass "self-improve: Step 7 report uses full batch path placeholder (not bare {batch})"
    else
        fail "self-improve: Step 7 / Output Format uses 'iterations-{batch}.md' — should be 'iterations-{batch_start:03d}-{batch_end:03d}.md' to match Step 1's defined path"
    fi
else
    fail "self-improve: SKILL.md not found"
fi


# 30. skill-generator SKILL.md template must include 'name:' field in generated SKILL.md frontmatter.
#     The template at Step 3 only contains 'description:' in its frontmatter block.
#     Skills generated from this template will be missing 'name:', failing registry identification
#     and the validate-skills.sh 'has name' check (which all existing skills pass).
echo ""
echo "-- skill-generator template name field --"
SG_SKILL="$PLUGIN_ROOT/skills/skill-generator/SKILL.md"
if [ -f "$SG_SKILL" ]; then
    # The SKILL.md template inside the file must include 'name:' as a template placeholder.
    # We verify that beyond the first 'name: skill-generator' line (the skill's own frontmatter),
    # there is a second 'name:' line inside the generated template block (e.g. 'name: <skill-name>').
    NAME_COUNT=$(grep -c "^name:" "$SG_SKILL")
    if [ "$NAME_COUNT" -ge 2 ]; then
        pass "skill-generator: generated SKILL.md template includes 'name:' in frontmatter"
    else
        fail "skill-generator: generated SKILL.md template missing 'name:' in frontmatter — generated skills won't be identifiable by registry or pass skill validation"
    fi
else
    fail "skill-generator: SKILL.md not found"
fi


# 33. init command must not reference notebooklm:navigate (nonexistent tool — should use notebooklm:chat)
echo ""
echo "-- init command notebooklm workflow consistency --"
INIT_CMD="$PLUGIN_ROOT/commands/init.md"
if [ -f "$INIT_CMD" ]; then
    if grep -q "notebooklm:navigate" "$INIT_CMD"; then
        fail "init: references 'notebooklm:navigate' which does not exist — the generated CLAUDE.md workflow will be broken; use 'notebooklm:chat' consistently"
    else
        pass "init: notebooklm workflow references valid commands only (no notebooklm:navigate)"
    fi
else
    fail "init: command file not found"
fi


# 34. session-bootstrap and init must not reference notebooklm:chat as a callable command
echo ""
echo "-- notebooklm:chat phantom command reference --"
SB_SKILL="$PLUGIN_ROOT/skills/session-bootstrap/SKILL.md"
INIT_CMD2="$PLUGIN_ROOT/commands/init.md"
NB_FAIL=0
if [ -f "$SB_SKILL" ]; then
    if grep -q "notebooklm:chat" "$SB_SKILL"; then
        fail "session-bootstrap: references 'notebooklm:chat' which is not a skill in this plugin — phantom command confuses agents"
        NB_FAIL=1
    fi
fi
if [ -f "$INIT_CMD2" ]; then
    if grep -q "notebooklm:chat" "$INIT_CMD2"; then
        fail "init: references 'notebooklm:chat' which is not a skill in this plugin — phantom command in generated CLAUDE.md will mislead agents"
        NB_FAIL=1
    fi
fi
if [ "$NB_FAIL" -eq 0 ]; then
    pass "session-bootstrap and init: no phantom notebooklm:chat command references"
fi


# 35. sync-context skill must not reference AskUserQuestion (nonexistent Claude Code tool)
#     AskUserQuestion is not a real tool in Claude Code. When the skill instructs the agent
#     to "Use AskUserQuestion", execution fails or the agent hallucinates the tool.
#     The correct approach is to output a question as plain text and wait for user response.
echo ""
echo "-- sync-context no phantom AskUserQuestion tool --"
SYNC_SKILL="$PLUGIN_ROOT/skills/sync-context/SKILL.md"
if [ -f "$SYNC_SKILL" ]; then
    if grep -q "AskUserQuestion" "$SYNC_SKILL"; then
        fail "sync-context: references 'AskUserQuestion' which is not a real Claude Code tool — replace with plain text question output"
    else
        pass "sync-context: does not reference nonexistent AskUserQuestion tool"
    fi
else
    fail "sync-context: SKILL.md not found"
fi



# 36. skill-generator template must include user_invocable field
#     All user-facing skills in this plugin have user_invocable: true in their frontmatter.
#     The skill-generator template is what agents use to generate new skills — if the
#     template is missing user_invocable, every generated skill will lack this field,
#     making them appear non-invocable (or rely on defaults that may differ by runtime).
echo ""
echo "-- skill-generator template user_invocable field --"
SG_SKILL="$PLUGIN_ROOT/skills/skill-generator/SKILL.md"
if [ -f "$SG_SKILL" ]; then
    if grep -qA5 "^name: <skill-name>" "$SG_SKILL" | grep -q "user_invocable" 2>/dev/null || \
       awk '/^```markdown/{p=1} p && /user_invocable/{found=1} /^```$/{p=0} END{exit !found}' "$SG_SKILL"; then
        pass "skill-generator: generated SKILL.md template includes 'user_invocable' field"
    else
        fail "skill-generator: generated SKILL.md template missing 'user_invocable' field — generated skills will lack invocability declaration"
    fi
else
    fail "skill-generator: SKILL.md not found"
fi



# 37. wrap-up skill must not claim "Stop hook triggers this automatically"
#     The hooks.json Stop hook only does lightweight iteration logging — it does NOT
#     trigger the wrap-up skill. Claiming it does misleads users into thinking wrap-up
#     runs automatically when it is actually manual-only.
echo ""
echo "-- wrap-up hook trigger accuracy --"
WU_SKILL="$PLUGIN_ROOT/skills/wrap-up/SKILL.md"
if [ -f "$WU_SKILL" ]; then
    if grep -qiE "Stop hook triggers this automatically|Stop hook.*triggers.*wrap.?up|automatically.*Stop hook" "$WU_SKILL"; then
        fail "wrap-up: claims 'Stop hook triggers this automatically' but hooks.json Stop hook only does lightweight logging — this misleads users; wrap-up is manual-only"
    else
        pass "wrap-up: does not claim false automatic Stop hook trigger"
    fi
else
    fail "wrap-up: SKILL.md not found"
fi


# 38. session-start.sh auto-init must create knowledge/notebook-registry.md
#     session-bootstrap health check verifies knowledge/notebook-registry.md exists.
#     If auto-init (session-start.sh) skips this file, bootstrap always warns about
#     a missing file after a fresh auto-init, producing spurious health alerts.
echo ""
echo "-- session-start.sh auto-init creates knowledge/notebook-registry.md --"
SESSION_HOOK="$PLUGIN_ROOT/scripts/session-start.sh"
if [ -f "$SESSION_HOOK" ]; then
    if grep -q "knowledge" "$SESSION_HOOK" && grep -q "notebook-registry" "$SESSION_HOOK"; then
        pass "session-start.sh: auto-init creates knowledge/notebook-registry.md"
    else
        fail "session-start.sh: auto-init missing knowledge/notebook-registry.md creation — session-bootstrap health check will always warn after auto-init"
    fi
else
    fail "session-start.sh: not found"
fi



# 39. status command must reference full subdirectory paths for memory files
#     status.md tells agents to count entries in bare filenames like "patterns.json",
#     "errors.json", "decisions.json", "iteration-log.md" — without the subdirectory
#     prefix. The actual paths are patterns/patterns.json, iterations/errors.json,
#     context/decisions.json, iterations/iteration-log.md. An agent following the
#     bare-name instructions will look in the wrong location and report 0 entries.
echo ""
echo "-- status command memory file paths --"
STATUS_CMD="$PLUGIN_ROOT/commands/status.md"
if [ -f "$STATUS_CMD" ]; then
    # The statistics section should reference subdirectory paths, not bare filenames
    if grep -qE "iterations/iteration-log|patterns/patterns\.json|iterations/errors\.json|context/decisions\.json" "$STATUS_CMD"; then
        pass "status: memory file paths include subdirectory prefixes (agents can locate files correctly)"
    else
        fail "status: statistics section references bare filenames (e.g. 'patterns.json') without subdirectory paths — agents will look in wrong location and always report 0 entries"
    fi
else
    fail "status: command file not found"
fi



# 40. plugin.json skill count must match actual number of skill directories
#     plugin.json description claims a specific number of skills. If skills are
#     added without updating the description, the count becomes stale and misleads
#     users about the plugin's capabilities.
echo ""
echo "-- plugin.json skill count accuracy --"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
if [ -f "$MANIFEST" ]; then
    ACTUAL_SKILL_COUNT=$(ls -d "$PLUGIN_ROOT/skills"/*/  2>/dev/null | wc -l | tr -d '[:space:]')
    # Extract the number from description (e.g. "10 skills" -> 10)
    CLAIMED_COUNT=$(grep -o '[0-9]\+ skills' "$MANIFEST" | grep -o '[0-9]\+' | head -1)
    if [ -z "$CLAIMED_COUNT" ]; then
        echo "  SKIP: plugin.json description does not mention a skill count"
    elif [ "$CLAIMED_COUNT" -eq "$ACTUAL_SKILL_COUNT" ]; then
        pass "plugin.json: skill count in description ($CLAIMED_COUNT) matches actual skill directories ($ACTUAL_SKILL_COUNT)"
    else
        fail "plugin.json: skill count in description ($CLAIMED_COUNT) does not match actual directories ($ACTUAL_SKILL_COUNT) — update description to reflect current skill count"
    fi
else
    fail "plugin.json not found"
fi



# 41. DEPENDENCIES.md must use the correct batch filename placeholder for self-improve output.
#     iterations-{batch}.md is the old/wrong format. The correct format (as defined in
#     self-improve SKILL.md) is iterations-{batch_start:03d}-{batch_end:03d}.md.
#     Stale DEPENDENCIES.md misleads developers and agents about where iteration docs are stored.
echo ""
echo "-- DEPENDENCIES.md self-improve batch filename accuracy --"
DEPS="$PLUGIN_ROOT/skills/DEPENDENCIES.md"
if [ -f "$DEPS" ]; then
    # The bare {batch}.md pattern (without batch_start/batch_end) should not appear
    if grep -qE "iterations-\{batch\}\.md" "$DEPS"; then
        fail "DEPENDENCIES.md: self-improve output path uses stale '{batch}.md' placeholder — should be '{batch_start:03d}-{batch_end:03d}.md' to match actual file naming"
    else
        pass "DEPENDENCIES.md: self-improve batch filename placeholder is accurate (no stale '{batch}.md')"
    fi
else
    fail "DEPENDENCIES.md not found"
fi



# 42. status command must show code-reviews count in statistics
#     The status command tracks iterations, patterns, errors, and decisions.
#     code-reviews.json is a key quality metric — omitting it leaves users blind
#     to how many reviews have been logged. All four tracked quality assets should
#     appear together for a complete health picture.
echo ""
echo "-- status command code-reviews count --"
STATUS_CMD="$PLUGIN_ROOT/commands/status.md"
if [ -f "$STATUS_CMD" ]; then
    if grep -qi "code.review\|reviews" "$STATUS_CMD"; then
        pass "status: includes code-reviews count in statistics"
    else
        fail "status: missing code-reviews count — statistics section tracks iterations/patterns/errors/decisions but omits code-reviews.json, leaving review history invisible to the user"
    fi
else
    fail "status.md not found"
fi


# 43. code-reviewer must not reference a nonexistent plugin-setting 'max_review_entries'
#     plugin.json has no settings/configuration block. Claiming 'konfigurierbar via
#     Plugin-Setting max_review_entries' is a false affordance that misleads users into
#     searching for a setting that cannot be configured.
echo ""
echo "-- code-reviewer no phantom plugin-setting reference --"
CR_SKILL="$PLUGIN_ROOT/skills/code-reviewer/SKILL.md"
if [ -f "$CR_SKILL" ]; then
    if grep -q "Plugin-Setting\|plugin-setting\|plugin setting" "$CR_SKILL"; then
        fail "code-reviewer: references a nonexistent plugin-setting (max_review_entries) — plugin.json has no settings block, so this is a false affordance"
    else
        pass "code-reviewer: does not reference nonexistent plugin-settings"
    fi
else
    fail "code-reviewer: SKILL.md not found"
fi



# 44. init command must use English default content for initialized Markdown files
#     The plugin uses English for all technical content (skills, agents, commands).
#     init.md initializes iteration-log.md, patterns.md, and session-summary.md with
#     German placeholder strings ("Noch keine Eintraege", "Pattern-Katalog", etc.).
#     This is inconsistent with the plugin's language convention and was fixed for
#     test-validator, code-reviewer, and wrap-up in prior iterations.
echo ""
echo "-- init command markdown defaults use English --"
INIT_CMD="$PLUGIN_ROOT/commands/init.md"
if [ -f "$INIT_CMD" ]; then
    if grep -q "Noch keine\|Pattern-Katalog\|Letzte Session\|Erste Session\|Naechste Schritte" "$INIT_CMD"; then
        fail "init: default Markdown file content uses German strings (e.g. 'Noch keine Eintraege', 'Pattern-Katalog') — should use English to match plugin language convention"
    else
        pass "init: default Markdown file content uses English (no German placeholder strings)"
    fi
else
    fail "init.md not found"
fi



# 45. context-detective agent example response must use English, not German
#     context-detective.md has an example where the assistant says
#     "Ich analysiere das Repository..." (German). All skill examples and agent
#     content should be in English for consistency with the plugin's language convention.
echo ""
echo "-- context-detective agent example uses English --"
CTX_DET="$PLUGIN_ROOT/agents/context-detective.md"
if [ -f "$CTX_DET" ]; then
    if grep -q "Ich analysiere\|Ich überprüfe\|Ich starte\|Das Repository" "$CTX_DET"; then
        fail "context-detective: example assistant response uses German (e.g. 'Ich analysiere das Repository...') — should use English"
    else
        pass "context-detective: example assistant response uses English (no German phrases)"
    fi
else
    fail "context-detective.md not found"
fi


# 46. hooks.json SessionEnd prompt must use English, not German
#     SessionEnd hook prompt uses German section headers: "Was wurde gemacht",
#     "Offene Punkte", "Naechste Schritte". All hook prompts should be in English.
echo ""
echo "-- hooks.json SessionEnd prompt language consistency --"
HOOKS_FILE="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_FILE" ]; then
    if grep -A20 '"SessionEnd"' "$HOOKS_FILE" | grep -q "Was wurde gemacht\|Offene Punkte\|Naechste Schritte"; then
        fail "hooks.json SessionEnd: prompt uses German headers (e.g. 'Was wurde gemacht', 'Offene Punkte', 'Naechste Schritte') — should use English"
    else
        pass "hooks.json SessionEnd: prompt uses English (no German headers)"
    fi
else
    fail "hooks.json not found"
fi

# 47. hooks.json SubagentStop prompt must use English, not German
#     SubagentStop hook prompts user with German question: "Soll ich diese
#     Aenderungen committen?" — should be English for plugin language consistency.
echo ""
echo "-- hooks.json SubagentStop prompt language consistency --"
if [ -f "$HOOKS_FILE" ]; then
    if grep -A10 '"SubagentStop"' "$HOOKS_FILE" | grep -q "Soll ich\|Aenderungen\|committen\|Vorgeschlagene"; then
        fail "hooks.json SubagentStop: prompt uses German dialog (e.g. 'Soll ich diese Aenderungen committen?') — should use English"
    else
        pass "hooks.json SubagentStop: prompt uses English (no German dialog)"
    fi
else
    fail "hooks.json not found"
fi


# 48. init command notebook-registry.md template must use English
#     commands/init.md initializes knowledge/notebook-registry.md with a German
#     template ("Zentrales Register", "Aktive Notebooks", "Stichwörter", etc.).
#     session-start.sh already uses English for the same file. When users run
#     /init manually, they get German content — inconsistent with the plugin's
#     English language convention applied everywhere else.
echo ""
echo "-- init command notebook-registry.md template language consistency --"
INIT_CMD="$PLUGIN_ROOT/commands/init.md"
if [ -f "$INIT_CMD" ]; then
    if grep -q "Zentrales Register\|Aktive Notebooks\|Stichwörter\|aktualisieren\|Wann NotebookLM\|Thema:\|Staerken:" "$INIT_CMD"; then
        fail "init: notebook-registry.md template contains German strings — must use English for language consistency (cf. session-start.sh uses English)"
    else
        pass "init: notebook-registry.md template uses English (no German placeholder strings)"
    fi
else
    fail "init: commands/init.md not found"
fi


# 49. init command soul.md template must not default to German language
#     commands/init.md creates soul.md with "Language: de" as the default,
#     which forces every new project to start in German. All other plugin
#     content uses English. The default should be "en" to match the plugin's
#     English-first convention; users can change it to "de" if desired.
echo ""
echo "-- init command soul.md language default consistency --"
INIT_CMD="$PLUGIN_ROOT/commands/init.md"
if [ -f "$INIT_CMD" ]; then
    if grep -q "Language: de" "$INIT_CMD"; then
        fail "init: soul.md template defaults to 'Language: de' (German) — inconsistent with the plugin's English-first convention; default should be 'en'"
    else
        pass "init: soul.md template language default is English (no 'Language: de')"
    fi
else
    fail "init: commands/init.md not found"
fi


# 50. iteration-logger and test-validator must not reference phantom plugin settings
#     Both skills say their log-rotation thresholds are "configurable via plugin settings"
#     (max_iterations_log_entries, max_error_log_entries, max_test_result_entries), but
#     no such configuration file or mechanism exists in the plugin. Agents following these
#     instructions would search for a non-existent config, causing confusion. The thresholds
#     should be stated as hardcoded values.
echo ""
echo "-- iteration-logger phantom plugin settings reference --"
IL_FILE="$PLUGIN_ROOT/skills/iteration-logger/SKILL.md"
if [ -f "$IL_FILE" ]; then
    if grep -q "configurable via plugin setting" "$IL_FILE"; then
        fail "iteration-logger: references 'configurable via plugin settings' (max_iterations_log_entries, max_error_log_entries) but no such plugin config exists — agents will look for a non-existent mechanism; remove phantom setting references"
    else
        pass "iteration-logger: does not reference phantom plugin settings (log rotation thresholds are hardcoded)"
    fi
else
    fail "iteration-logger: SKILL.md not found"
fi

echo ""
echo "-- test-validator phantom plugin settings reference --"
TV_FILE="$PLUGIN_ROOT/skills/test-validator/SKILL.md"
if [ -f "$TV_FILE" ]; then
    if grep -q "configurable via plugin setting" "$TV_FILE"; then
        fail "test-validator: references 'configurable via plugin setting' (max_test_result_entries) but no such plugin config exists — agents will look for a non-existent mechanism; remove phantom setting reference"
    else
        pass "test-validator: does not reference phantom plugin settings (log rotation threshold is hardcoded)"
    fi
else
    fail "test-validator: SKILL.md not found"
fi


# 51. session-start.sh auto-init must use English for all initialized markdown file content
#     session-start.sh creates iteration-log.md, patterns.md, learnings.md, and
#     session-summary.md during auto-init. The current content uses German strings
#     ("Noch keine Eintraege", "Pattern-Katalog", "Erste Session — frisch initialisiert",
#     "Naechste Schritte"). The init.md command was fixed (iteration 38) to use English
#     for the same files, but session-start.sh was never updated. This means auto-init
#     (SessionStart hook) still creates German content, while /init creates English content —
#     a language inconsistency depending on how the memory system is initialized.
echo ""
echo "-- session-start.sh auto-init markdown content uses English --"
SS_HOOK="$PLUGIN_ROOT/scripts/session-start.sh"
if [ -f "$SS_HOOK" ]; then
    if grep -q "Noch keine Eintraege\|Pattern-Katalog\|Noch keine Patterns\|Noch keine Session-Learnings\|Erste Session.*frisch initialisiert\|frisch initialisiert\|Language: de" "$SS_HOOK"; then
        fail "session-start.sh: auto-init creates markdown files with German content (e.g. 'Noch keine Eintraege', 'Pattern-Katalog', 'Language: de') — inconsistent with /init command which uses English; fix to match init.md"
    else
        pass "session-start.sh: auto-init markdown file content uses English (language-consistent with /init command)"
    fi
else
    fail "session-start.sh: not found"
fi



# 52. session-start.sh runtime context messages must use English, not German
#     session-start.sh injects context into Claude's system prompt at session start.
#     Several runtime messages are in German: the INIT_MSG variable ("Memory-System
#     initialisiert fuer..."), quality warning ("WARNUNG: Quality Scores declining!"),
#     error hint ("Hinweis: Viele Fehler — Pattern-Extract empfohlen."), briefing section
#     extractors for "Naechste Schritte" / "Offene Punkte" / "Aktive Warnungen", and the
#     main briefing instruction to Claude ("Bei deiner ERSTEN Antwort in dieser Session...").
#     These German strings directly instruct Claude in German, causing inconsistent
#     behavior vs. the plugin's English-first convention established everywhere else.
echo ""
echo "-- session-start.sh runtime context messages use English --"
SS_HOOK="$PLUGIN_ROOT/scripts/session-start.sh"
if [ -f "$SS_HOOK" ]; then
    if grep -q "Memory-System initialisiert\|Bei deiner ERSTEN Antwort\|WARNUNG:.*declining\|Hinweis: Viele Fehler\|Naechste Schritte\|Offene Punkte\|Aktive Warnungen\|Neu initialisiert\|Iterationen.*Fehler.*Patterns" "$SS_HOOK"; then
        fail "session-start.sh: runtime context messages injected into Claude's session use German (e.g. 'Bei deiner ERSTEN Antwort', 'Memory-System initialisiert', 'Naechste Schritte') — these directly instruct Claude in German; must use English for consistency"
    else
        pass "session-start.sh: runtime context messages use English (no German in Claude-facing strings)"
    fi
else
    fail "session-start.sh: not found"
fi


# 53. marketplace.json skill count must match actual number of skill directories
#     marketplace.json is the public-facing listing for the Claude Code marketplace.
#     If marketplace.json description says "10 skills" but there are 11 skill directories,
#     potential users browsing the marketplace get an incorrect picture of plugin capabilities.
#     The plugin.json was fixed in iteration 32 but marketplace.json was overlooked.
echo ""
echo "-- marketplace.json skill count accuracy --"
MKTPLACE="$PLUGIN_ROOT/.claude-plugin/marketplace.json"
if [ -f "$MKTPLACE" ]; then
    ACTUAL_SKILL_COUNT=$(ls -d "$PLUGIN_ROOT/skills"/*/  2>/dev/null | wc -l | tr -d '[:space:]')
    # Extract the number from description (e.g. "10 skills" -> 10)
    CLAIMED_COUNT=$(grep -o '[0-9]\+ skills' "$MKTPLACE" | grep -o '[0-9]\+' | head -1)
    if [ -z "$CLAIMED_COUNT" ]; then
        echo "  SKIP: marketplace.json description does not mention a skill count"
    elif [ "$CLAIMED_COUNT" -eq "$ACTUAL_SKILL_COUNT" ]; then
        pass "marketplace.json: skill count in description ($CLAIMED_COUNT) matches actual skill directories ($ACTUAL_SKILL_COUNT)"
    else
        fail "marketplace.json: skill count in description ($CLAIMED_COUNT) does not match actual skill directories ($ACTUAL_SKILL_COUNT) — update description to reflect current skill count"
    fi
else
    echo "  SKIP: .claude-plugin/marketplace.json not found"
fi



# 54. code-reviewer skill must have a quality-score.json update step
#     code-reviewer's File Structure section declares quality-score.json as an output file,
#     and DEPENDENCIES.md lists it as a write target. However, the procedure has no step
#     that updates quality-score.json. This means the quality score trend tracking is
#     non-functional: code reviews run but never feed into the quality dashboard.
echo ""
echo "-- code-reviewer skill: quality-score.json update step --"
CR_SKILL="$PLUGIN_ROOT/skills/code-reviewer/SKILL.md"
if [ -f "$CR_SKILL" ]; then
    if grep -q "quality-score" "$CR_SKILL" && grep -qiE "update.*quality.score|quality.score.*update|quality-score\.json.*Step|Step.*quality-score" "$CR_SKILL"; then
        pass "code-reviewer: skill has a quality-score.json update step"
    else
        fail "code-reviewer: skill declares quality-score.json as output (File Structure) but procedure has no step to update it — quality trend tracking is non-functional"
    fi
else
    fail "code-reviewer: SKILL.md not found"
fi



# 55. pre-compact.sh must use English for all Claude-facing strings
#     pre-compact.sh injects a context restoration message into Claude's system
#     prompt before context compression. The current script uses German strings:
#     "KONTEXT-WIEDERHERSTELLUNG", "Session-Kontext", "Kontext wurde komprimiert.
#     Bei Bedarf relevante Dateien neu lesen." and the fallback message
#     "Kontext wiederhergestellt." — these directly instruct Claude in German,
#     which is inconsistent with the plugin's English-first convention.
echo ""
echo "-- pre-compact.sh body language consistency --"
PC_HOOK="$PLUGIN_ROOT/scripts/pre-compact.sh"
if [ -f "$PC_HOOK" ]; then
    if grep -q "KONTEXT-WIEDERHERSTELLUNG\|Session-Kontext\|Kontext wurde komprimiert\|Bei Bedarf relevante Dateien\|Kontext wiederhergestellt\|Re-injected.*Kontext\|BEVOR die Context-Komprimierung\|Weist Claude an" "$PC_HOOK"; then
        fail "pre-compact.sh: contains German strings visible to Claude (e.g. 'KONTEXT-WIEDERHERSTELLUNG', 'Kontext wurde komprimiert') — must use English for language consistency"
    else
        pass "pre-compact.sh: body uses English (no German strings in Claude-facing content)"
    fi
else
    echo "  SKIP: scripts/pre-compact.sh not found"
fi


# 56. session-end.sh must use English for all Claude-facing strings
#     session-end.sh injects a wrap-up instruction into Claude's systemMessage
#     at session end. The current script uses German: "Session wird beendet.
#     Führe jetzt das Wrap-Up durch:", "Aktualisiere session-summary.md",
#     "Logge alle ungeloggten Iterationen", "Extrahiere Learnings",
#     "Führe Pattern-Extract aus", "Session beendet. Bitte wrap-up durchführen."
#     These German instructions directly tell Claude what to do in German,
#     which is inconsistent with the plugin's English-first convention.
echo ""
echo "-- session-end.sh body language consistency --"
SE_HOOK="$PLUGIN_ROOT/scripts/session-end.sh"
if [ -f "$SE_HOOK" ]; then
    if grep -q "Session wird beendet\|Führe jetzt\|Aktualisiere session-summary\|Logge alle ungeloggten\|Extrahiere Learnings\|Führe Pattern-Extract\|Session beendet.*wrap-up durchführen\|Weist Claude an.*wrap-up\|Kein .agent-memory\|Statistiken sammeln\|systemMessage bauen\|JSON-safe escapen\|beendet\. Bitte\|Naechste Schritte\|offene Punkte\|nächste Schritte\|was wurde gemacht" "$SE_HOOK"; then
        fail "session-end.sh: contains German strings in Claude-facing systemMessage (e.g. 'Session wird beendet', 'Führe jetzt das Wrap-Up durch') — must use English for language consistency"
    else
        pass "session-end.sh: body uses English (no German strings in Claude-facing content)"
    fi
else
    echo "  SKIP: scripts/session-end.sh not found"
fi



# 57. schedule-manager must reference agentic-os, not self-improve-loop (deprecated plugin)
echo ""
echo "-- schedule-manager plugin reference --"
SM_SKILL="$PLUGIN_ROOT/skills/schedule-manager/SKILL.md"
if [ -f "$SM_SKILL" ]; then
    # Only check frontmatter metadata (part-of and depends-on), not body text like task IDs
    FRONTMATTER=$(awk '/^---/{c++} c==1{print} c==2{exit}' "$SM_SKILL")
    if echo "$FRONTMATTER" | grep -q "self-improve-loop"; then
        fail "schedule-manager: frontmatter references deprecated 'self-improve-loop' plugin — must use 'agentic-os'"
    else
        pass "schedule-manager: frontmatter correctly references 'agentic-os' (no stale self-improve-loop refs)"
    fi
else
    echo "  SKIP: skills/schedule-manager/SKILL.md not found"
fi


# 58. meta-improve body must not reference deprecated 'self-improve-loop' plugin name
echo ""
echo "-- meta-improve body reference --"
MI_SKILL="$PLUGIN_ROOT/skills/meta-improve/SKILL.md"
if [ -f "$MI_SKILL" ]; then
    # Extract body (after second ---)
    BODY=$(awk 'BEGIN{c=0} /^---/{c++; next} c>=2{print}' "$MI_SKILL")
    if echo "$BODY" | grep -q "self-improve-loop plugin"; then
        fail "meta-improve: body references 'self-improve-loop plugin' — should say 'agentic-os plugin'"
    else
        pass "meta-improve: body correctly references agentic-os plugin (no stale self-improve-loop)"
    fi
fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
