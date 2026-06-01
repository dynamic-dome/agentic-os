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

# 5b. Commands must have a name field in frontmatter
echo ""
echo "-- Command name field --"
for cmd_file in "$PLUGIN_ROOT/commands"/*.md; do
    [ -f "$cmd_file" ] || continue
    cname=$(basename "$cmd_file")
    FRONTMATTER=$(awk '/^---/{c++} c==1{print} c==2{exit}' "$cmd_file")
    if echo "$FRONTMATTER" | grep -q "^name:"; then
        pass "$cname has name field in frontmatter"
    else
        fail "$cname missing name field — command manifests must declare name for consistent identification"
    fi
done

# 5c. Commands must use allowed_tools (underscore), not allowed-tools (hyphen)
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

# 12. improvement-agent can handle plugin audit (not just .agent-memory/)
echo ""
echo "-- improvement-agent plugin audit scope --"
IS_AGENT="$PLUGIN_ROOT/agents/improvement-agent.md"
if [ -f "$IS_AGENT" ]; then
    if grep -qi "plugin\|skills/\|hooks.json\|SKILL.md" "$IS_AGENT"; then
        pass "improvement-agent: supports plugin structure audit"
    else
        fail "improvement-agent: only scans .agent-memory/ — cannot audit plugin structure when called by self-improve"
    fi
else
    fail "improvement-agent: agent file not found"
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
#     Without this, improvement-agent re-identifies the same things each run
#     and the loop wastes iterations re-fixing already-solved problems.
echo ""
echo "-- self-improve history dedup guidance --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    if grep -qiE "previously.fixed|skip.*history|history.*skip|state\.json.*history|already.fixed|dedup|avoid.*duplicate" "$SI_SKILL"; then
        pass "self-improve: analysis step instructs agent to skip previously-fixed weaknesses from history"
    else
        fail "self-improve: analysis step missing history dedup guidance — improvement-agent will re-identify already-fixed weaknesses causing wasted iterations"
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


# 26. self-improve must define the critical/warning/suggestion severity taxonomy.
#     In v3 the analysis/severity logic lives in the self-improve SKILL.md (the
#     improvement-agent is a thin delegation wrapper with no own severity output).
#     The ecosystem standard is critical/warning/suggestion — verify the skill that
#     actually ranks weaknesses uses these labels, not HIGH/MEDIUM/LOW.
echo ""
echo "-- self-improve severity label consistency --"
SI_SEV_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SEV_SKILL" ]; then
    if grep -qiE "critical.*warning.*suggestion|critical and warning|severity.*critical|\*\*critical\*\*" "$SI_SEV_SKILL"; then
        pass "self-improve: uses critical/warning/suggestion severity taxonomy consistently"
    else
        fail "self-improve: missing critical/warning/suggestion severity taxonomy — analysis ranking may use inconsistent labels"
    fi
else
    fail "self-improve: SKILL.md not found"
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


# 38. auto-init must create knowledge/notebook-registry.md
#     session-bootstrap health check verifies knowledge/notebook-registry.md exists.
#     If auto-init skips this file, bootstrap always warns about a missing file after
#     a fresh auto-init, producing spurious health alerts.
#     FUNCTIONAL check (not grep): the file may be created by the hook inline OR by the
#     sourced mem-schema.sh — we verify it actually appears, regardless of where defined.
echo ""
echo "-- auto-init creates knowledge/notebook-registry.md (functional) --"
SESSION_HOOK="$PLUGIN_ROOT/scripts/session-start.sh"
if [ -f "$SESSION_HOOK" ]; then
    NR_TMP=$(mktemp -d)
    CLAUDE_PROJECT_DIR="$NR_TMP" bash "$SESSION_HOOK" > "$NR_TMP/out.json" 2>/dev/null
    NR_EXIT=$?
    if [ "$NR_EXIT" -eq 0 ] && [ -f "$NR_TMP/.agent-memory/knowledge/notebook-registry.md" ]; then
        pass "auto-init creates knowledge/notebook-registry.md (hook exit 0)"
    else
        fail "auto-init missing knowledge/notebook-registry.md or hook exited non-zero ($NR_EXIT) — session-bootstrap health check will warn after auto-init"
    fi
    rm -rf "$NR_TMP"
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


# 41b. DEPENDENCIES.md inter-skill-call accuracy (Design Principle 4).
#      Principle 4 names the skills that invoke OTHER skills. If a skill's SKILL.md
#      contains a real cross-skill invocation (`invoke ... <other-skill>`) but is NOT
#      listed as an invoker in DEPENDENCIES.md (or vice versa), the graph has drifted.
#      Catches the v3.2.4 finding: wrap-up invokes obsidian-sync (Step 7.5) but the
#      old graph omitted it, and Principle 4 wrongly claimed only wrap-up + self-improve call others.
echo ""
echo "-- DEPENDENCIES.md inter-skill-call accuracy (Principle 4) --"
if [ -f "$DEPS" ]; then
    OTHER_SKILLS="pattern-extractor obsidian-sync memory-maintenance context-keeper iteration-logger"
    CALL_DRIFT=""
    for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        sname=$(basename "$skill_dir")
        SFILE="$skill_dir/SKILL.md"
        [ -f "$SFILE" ] || continue
        # Does this skill REALLY invoke another skill? (an "invoke ... <other>" line,
        # excluding self-references and the depends-on metadata block)
        REAL_CALL=false
        for other in $OTHER_SKILLS; do
            [ "$other" = "$sname" ] && continue
            if grep -iE "(invoke|trigger|call)[^.]*\`?$other\`?" "$SFILE" \
                 | grep -ivE "depends-on|owned by|no longer|does NOT|not replicate|instead of" >/dev/null 2>&1; then
                REAL_CALL=true
                break
            fi
        done
        # Is this skill listed as an invoker in DEPENDENCIES.md Principle 4 line?
        LISTED=false
        grep -E "^4\. \*\*Skills that invoke" "$DEPS" | grep -q "\`$sname\`" && LISTED=true
        if [ "$REAL_CALL" = true ] && [ "$LISTED" = false ]; then
            CALL_DRIFT="$CALL_DRIFT $sname(calls-but-unlisted)"
        fi
    done
    if [ -z "$CALL_DRIFT" ]; then
        pass "DEPENDENCIES.md Principle 4 lists every skill that invokes another skill"
    else
        fail "DEPENDENCIES.md Principle 4 drift — these skills invoke others but aren't listed as invokers:$CALL_DRIFT"
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


# 43. quality-gate must not reference a nonexistent plugin-setting
#     plugin.json has no settings/configuration block.
echo ""
echo "-- quality-gate no phantom plugin-setting reference --"
QG_SKILL="$PLUGIN_ROOT/skills/quality-gate/SKILL.md"
if [ -f "$QG_SKILL" ]; then
    if grep -q "Plugin-Setting\|plugin-setting\|plugin setting" "$QG_SKILL"; then
        fail "quality-gate: references a nonexistent plugin-setting — plugin.json has no settings block"
    else
        pass "quality-gate: does not reference nonexistent plugin-settings"
    fi
else
    fail "quality-gate: SKILL.md not found"
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

# test-validator merged into quality-gate — test removed in v3 consolidation


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



# 54. quality-gate skill must have a quality-score.json update step
echo ""
echo "-- quality-gate skill: quality-score.json update step --"
QG_SKILL="$PLUGIN_ROOT/skills/quality-gate/SKILL.md"
if [ -f "$QG_SKILL" ]; then
    if grep -q "quality-score" "$QG_SKILL" && grep -qiE "update.*quality.score|quality.score.*update|quality-score\.json" "$QG_SKILL"; then
        pass "quality-gate: skill has a quality-score.json update step"
    else
        fail "quality-gate: skill declares quality-score.json as output but procedure has no step to update it"
    fi
else
    fail "quality-gate: SKILL.md not found"
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

# 59. SubagentStop matcher must reference improvement-agent (not deprecated improvement-scout)
echo ""
echo "-- SubagentStop matcher references active agent --"
if grep -q '"matcher":' "$PLUGIN_ROOT/hooks/hooks.json"; then
    SUBAGENT_MATCHER=$(grep '"matcher":' "$PLUGIN_ROOT/hooks/hooks.json" | tail -1)
    if echo "$SUBAGENT_MATCHER" | grep -q "improvement-scout"; then
        fail "SubagentStop: matcher references deprecated improvement-scout — should be improvement-agent"
    else
        pass "SubagentStop: matcher references active agents (no deprecated improvement-scout)"
    fi
fi

# 60. run-loop command must reference agentic-os:self-improve (not loop-orchestrator)
echo ""
echo "-- run-loop command references self-improve skill --"
if [ -f "$PLUGIN_ROOT/commands/run-loop.md" ]; then
    if grep -q "loop-orchestrator" "$PLUGIN_ROOT/commands/run-loop.md"; then
        fail "run-loop: references non-existent loop-orchestrator — should reference self-improve"
    else
        pass "run-loop: correctly references self-improve (no stale loop-orchestrator)"
    fi
fi

# 61. self-improve depends-on must include quality-gate
echo ""
echo "-- self-improve depends-on includes quality-gate --"
SI_SKILL="$PLUGIN_ROOT/skills/self-improve/SKILL.md"
if [ -f "$SI_SKILL" ]; then
    FRONTMATTER=$(awk 'BEGIN{c=0} /^---/{c++; next} c==1{print}' "$SI_SKILL")
    if echo "$FRONTMATTER" | grep -q "quality-gate"; then
        pass "self-improve: depends-on includes quality-gate"
    else
        fail "self-improve: depends-on missing quality-gate (used for validation phase)"
    fi
fi

# 62. research-pipeline body must be in English (no German section headers)
echo ""
echo "-- research-pipeline body language consistency --"
RP_SKILL="$PLUGIN_ROOT/skills/research-pipeline/SKILL.md"
if [ -f "$RP_SKILL" ]; then
    RP_BODY=$(awk 'BEGIN{c=0} /^---/{c++; next} c>=2{print}' "$RP_SKILL")
    if echo "$RP_BODY" | grep -qE '(Architektur|Ablauf|Fehlerbehandlung|Voraussetzungen|Ersparnis)'; then
        fail "research-pipeline: body contains German section headers — must be English"
    else
        pass "research-pipeline: body uses English section headers"
    fi
fi

# 63. sync-context version must be 3.0 (consistent with other skills)
echo ""
echo "-- sync-context version consistency --"
SC_SKILL="$PLUGIN_ROOT/skills/sync-context/SKILL.md"
if [ -f "$SC_SKILL" ]; then
    SC_FM=$(awk 'BEGIN{c=0} /^---/{c++; next} c==1{print}' "$SC_SKILL")
    if echo "$SC_FM" | grep -qE "version:.*['\"]?1\.0"; then
        fail "sync-context: version is 1.0 — should be 3.0 (consistent with other skills)"
    else
        pass "sync-context: version is consistent (not stale 1.0)"
    fi
fi

# 64. session-start.sh must produce valid JSON output
echo ""
echo "-- session-start.sh JSON output validity --"
SS_SCRIPT="$PLUGIN_ROOT/scripts/session-start.sh"
if [ -f "$SS_SCRIPT" ]; then
    # Run in a temp dir to test auto-init path
    TMPDIR_TEST=$(mktemp -d)
    SS_OUTPUT=$(CLAUDE_PROJECT_DIR="$TMPDIR_TEST" bash "$SS_SCRIPT" 2>/dev/null || true)
    if echo "$SS_OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        pass "session-start.sh: produces valid JSON output"
    else
        fail "session-start.sh: output is not valid JSON"
    fi
    # Check that systemMessage field exists
    HAS_MSG=$(echo "$SS_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'systemMessage' in d else 'no')" 2>/dev/null || echo "no")
    if [ "$HAS_MSG" = "yes" ]; then
        pass "session-start.sh: JSON output contains systemMessage field"
    else
        fail "session-start.sh: JSON output missing systemMessage field"
    fi
    rm -rf "$TMPDIR_TEST"
fi

# 65. session-start.sh auto-init creates required directory structure
echo ""
echo "-- session-start.sh auto-init directory structure --"
if [ -f "$SS_SCRIPT" ]; then
    TMPDIR_TEST=$(mktemp -d)
    CLAUDE_PROJECT_DIR="$TMPDIR_TEST" bash "$SS_SCRIPT" > /dev/null 2>&1 || true
    MISSING=""
    for subdir in identity context iterations patterns quality learnings generated-skills knowledge; do
        [ ! -d "$TMPDIR_TEST/.agent-memory/$subdir" ] && MISSING="$MISSING $subdir"
    done
    if [ -z "$MISSING" ]; then
        pass "session-start.sh: auto-init creates all required subdirectories"
    else
        fail "session-start.sh: auto-init missing directories:$MISSING"
    fi
    # Check key files created
    FILES_OK=true
    for keyfile in session-summary.md identity/soul.md context/project-context.md iterations/errors.json patterns/patterns.json quality/quality-score.json knowledge/notebook-registry.md; do
        [ ! -f "$TMPDIR_TEST/.agent-memory/$keyfile" ] && FILES_OK=false
    done
    if [ "$FILES_OK" = true ]; then
        pass "session-start.sh: auto-init creates all required seed files"
    else
        fail "session-start.sh: auto-init missing seed files"
    fi
    rm -rf "$TMPDIR_TEST"
fi

# 66. session-start.sh existing memory dir does not re-init
echo ""
echo "-- session-start.sh no re-init on existing memory --"
if [ -f "$SS_SCRIPT" ]; then
    TMPDIR_TEST=$(mktemp -d)
    mkdir -p "$TMPDIR_TEST/.agent-memory"
    echo "# Existing summary" > "$TMPDIR_TEST/.agent-memory/session-summary.md"
    CLAUDE_PROJECT_DIR="$TMPDIR_TEST" bash "$SS_SCRIPT" > /dev/null 2>&1 || true
    CONTENT=$(cat "$TMPDIR_TEST/.agent-memory/session-summary.md" 2>/dev/null)
    if echo "$CONTENT" | grep -q "Existing summary"; then
        pass "session-start.sh: does not overwrite existing .agent-memory/ files"
    else
        fail "session-start.sh: overwrites existing .agent-memory/ files on re-run"
    fi
    rm -rf "$TMPDIR_TEST"
fi

# 67. SessionEnd prompt hook delegates to wrap-up (no duplicate logic)
echo ""
echo "-- SessionEnd hook delegates to wrap-up --"
SE_PROMPT=$(python3 -c "import json,sys; h=json.load(open(sys.argv[1])); print(h['hooks']['SessionEnd'][0]['hooks'][0]['prompt'])" "$PLUGIN_ROOT/hooks/hooks.json" 2>/dev/null || echo "")
if [ -n "$SE_PROMPT" ]; then
    if echo "$SE_PROMPT" | grep -q "wrap-up"; then
        pass "SessionEnd: prompt hook delegates to wrap-up skill"
    else
        fail "SessionEnd: prompt hook does not delegate to wrap-up — risk of duplicate logic"
    fi
    # Should NOT contain detailed summary update instructions (that's wrap-up's job)
    if echo "$SE_PROMPT" | grep -qE "What was done.*bullet points|Keep under 30 lines"; then
        fail "SessionEnd: prompt hook contains detailed summary logic that duplicates wrap-up skill"
    else
        pass "SessionEnd: prompt hook is lean (no duplicate summary logic)"
    fi
fi

# 68. Dead script cleanup — session-end.sh and pre-compact.sh should not exist
echo ""
echo "-- Dead hook script cleanup --"
if [ -f "$PLUGIN_ROOT/scripts/session-end.sh" ]; then
    fail "scripts/session-end.sh exists but is not referenced in hooks.json (dead code)"
else
    pass "scripts/session-end.sh: removed (was dead code — prompt hook handles SessionEnd)"
fi
if [ -f "$PLUGIN_ROOT/scripts/pre-compact.sh" ]; then
    fail "scripts/pre-compact.sh exists but is not referenced in hooks.json (dead code)"
else
    pass "scripts/pre-compact.sh: removed (was dead code — prompt hook handles PreCompact)"
fi

# 76. wrap-up version must be 3.0 (consistent with all other skills)
#     wrap-up was the only skill still carrying version '2.0' from the v2 era.
#     All other skills are at '3.0' — stale version causes confusion about
#     when the skill was last updated relative to the rest of the plugin.
echo ""
echo "-- wrap-up version consistency --"
WU_VER_SKILL="$PLUGIN_ROOT/skills/wrap-up/SKILL.md"
if [ -f "$WU_VER_SKILL" ]; then
    WU_FM=$(awk 'BEGIN{c=0} /^---/{c++; next} c==1{print}' "$WU_VER_SKILL")
    if echo "$WU_FM" | grep -qE "version:.*['\"]?2\.0"; then
        fail "wrap-up: version is 2.0 — should be 3.0 (all other skills are at version 3.0; stale version number misleads about update history)"
    else
        pass "wrap-up: version is consistent with other skills (not stale 2.0)"
    fi
fi

# 77. All skills must declare user_invocable field (true or false)
#     The skill-generator template enforces user_invocable in generated skills,
#     but 5 existing skills (context-keeper, iteration-logger, pattern-extractor,
#     session-bootstrap, research-pipeline) are missing this field entirely.
#     Missing the field means the plugin framework cannot determine invocability.
echo ""
echo "-- all skills declare user_invocable field --"
for SKILL_FILE in "$PLUGIN_ROOT"/skills/*/SKILL.md; do
    SKILL_NAME=$(basename "$(dirname "$SKILL_FILE")")
    FM=$(awk 'BEGIN{c=0} /^---/{c++; next} c==1{print} c==2{exit}' "$SKILL_FILE")
    if echo "$FM" | grep -q "user_invocable:"; then
        pass "skill $SKILL_NAME: declares user_invocable field"
    else
        fail "skill $SKILL_NAME: missing user_invocable field — plugin framework cannot determine if skill is exposed as slash command"
    fi
done

# 78. research-agent must not reference the old research-phase skill
#     research-phase was merged into self-improve in v3. The research-agent.md
#     still says "Spawned by research-phase skill" — a stale reference that
#     misleads users about which skill spawns this agent.
echo ""
echo "-- research-agent: no stale research-phase skill reference --"
RA_FILE="$PLUGIN_ROOT/agents/research-agent.md"
if [ -f "$RA_FILE" ]; then
    if grep -q "research-phase skill" "$RA_FILE"; then
        fail "research-agent: references 'research-phase skill' which no longer exists — research-phase was merged into self-improve in v3; update to reference self-improve"
    else
        pass "research-agent: no stale research-phase skill reference"
    fi
fi

echo ""
echo "-- quality-gate agent: WARN threshold checks regressions --"
QGA_FILE="$PLUGIN_ROOT/agents/quality-gate.md"
if [ -f "$QGA_FILE" ]; then
    WARN_LINE=$(grep -i "^\- WARN:" "$QGA_FILE" | head -1)
    if echo "$WARN_LINE" | grep -qiE "regression"; then
        pass "quality-gate agent: WARN threshold includes regression check"
    else
        fail "quality-gate agent: WARN threshold missing regression check — skill requires 0 regressions for WARN; agent is inconsistent"
    fi
fi

echo ""
echo "-- improvement-agent: no stale git-stash safety rule --"
IA2_FILE="$PLUGIN_ROOT/agents/improvement-agent.md"
if [ -f "$IA2_FILE" ]; then
    if grep -q "git stash" "$IA2_FILE"; then
        fail "improvement-agent: safety rule says 'git stash checkpoint' — but self-improve uses commit-hash checkpoints (git rev-parse HEAD + git reset --hard); stash is explicitly avoided as rollback strategy"
    else
        pass "improvement-agent: uses commit-hash checkpoint strategy (no git stash)"
    fi
fi

echo ""
echo "-- improvement-agent: no stale phase-skill references --"
IA_FILE="$PLUGIN_ROOT/agents/improvement-agent.md"
if [ -f "$IA_FILE" ]; then
    if grep -qE "research-phase|analysis-phase|improvement-phase|validation-phase" "$IA_FILE"; then
        fail "improvement-agent: references phase skills (research-phase, analysis-phase, improvement-phase, validation-phase) which no longer exist — all phases were merged inline into agentic-os:self-improve in v3"
    else
        pass "improvement-agent: no stale phase-skill references"
    fi
fi

echo ""
echo "-- memory schema: Single Source of Truth exists and is the only definition --"
SCHEMA_FILE="$PLUGIN_ROOT/scripts/mem-schema.sh"
HOOK_FILE="$PLUGIN_ROOT/scripts/session-start.sh"
INITCMD_FILE="$PLUGIN_ROOT/commands/init.md"
if [ ! -f "$SCHEMA_FILE" ]; then
    fail "mem-schema.sh missing — the .agent-memory/ schema must live in ONE sourceable file (scripts/mem-schema.sh)"
else
    pass "mem-schema.sh exists (single source of truth for memory schema)"

    if grep -q "create_memory_structure()" "$SCHEMA_FILE"; then
        pass "mem-schema.sh defines create_memory_structure()"
    else
        fail "mem-schema.sh: create_memory_structure() not defined — both hook and /init depend on it"
    fi

    # The hook must SOURCE the schema, not re-inline the file list (L4 drift guard)
    if [ -f "$HOOK_FILE" ]; then
        if grep -q "mem-schema.sh" "$HOOK_FILE" && grep -q "create_memory_structure" "$HOOK_FILE"; then
            pass "session-start.sh sources mem-schema.sh (no inlined duplicate schema)"
        else
            fail "session-start.sh does NOT source mem-schema.sh — re-inlining the file list reintroduces the L4 hook/command drift"
        fi
    fi

    # /init command must invoke the schema script, not hand-list files
    if [ -f "$INITCMD_FILE" ]; then
        if grep -q "mem-schema.sh" "$INITCMD_FILE"; then
            pass "commands/init.md invokes mem-schema.sh (shared schema with the hook)"
        else
            fail "commands/init.md does NOT reference mem-schema.sh — /init would drift from the hook (L4)"
        fi
    fi

    # Functional check: running the schema produces EVERY file it is responsible for
    # (full list — not a representative subset — so a dropped file is always caught).
    SCHEMA_TMP=$(mktemp -d 2>/dev/null)
    if [ -n "$SCHEMA_TMP" ]; then
        bash "$SCHEMA_FILE" "$SCHEMA_TMP/.agent-memory" >/dev/null 2>&1
        MISSING=""
        for req in identity/soul.md identity/user.md \
                   context/decisions.json context/open-tasks.json \
                   iterations/iteration-log.md iterations/errors.json \
                   patterns/patterns.md patterns/patterns.json \
                   quality/test-results.json quality/code-reviews.json quality/quality-score.json \
                   learnings/learnings.md learnings/learnings.json \
                   knowledge/notebook-registry.md working/current-session.json \
                   session-summary.md; do
            [ -f "$SCHEMA_TMP/.agent-memory/$req" ] || MISSING="$MISSING $req"
        done
        rm -rf "$SCHEMA_TMP"
        if [ -z "$MISSING" ]; then
            pass "mem-schema.sh produces all schema files (full list)"
        else
            fail "mem-schema.sh did not create:$MISSING"
        fi
    fi

    # Negative drift guard: the hook must NOT inline schema WRITES into .agent-memory
    # subfiles. The ONLY permitted inline write is project-context.md (intentionally
    # outside the SSoT — needs stack detection). Match only real file-creating writes
    # (redirect-to-file / heredoc into a memory subdir), NOT reads that merely use 2>
    # or `|| echo "0"`. Pattern: `> "$MEMORY_DIR/<schema-subdir>/...`.
    if [ -f "$HOOK_FILE" ]; then
        LEAK=$(grep -nE '(>|cat >)[[:space:]]*"\$MEMORY_DIR/(identity|iterations|patterns|quality|learnings|knowledge|working)/' "$HOOK_FILE" || true)
        if [ -z "$LEAK" ]; then
            pass "session-start.sh has no inline schema writes outside mem-schema.sh (project-context.md exempt)"
        else
            fail "session-start.sh inlines schema writes that belong in mem-schema.sh (L4 drift):
$LEAK"
        fi
    fi

    # Reference-doc drift guard (L8/L9): references/memory-structure.md documents the
    # store layout. Every memory file it names in its tree/JSON-defaults must actually
    # be produced by the SSoT — otherwise the doc silently drifts (the bug fixed
    # 2026-06-01: doc omitted learnings.json, open-tasks.json, working/). Direction is
    # "doc subset of real"; the full-list check above already guards "real subset of doc".
    REF_DOC="$PLUGIN_ROOT/references/memory-structure.md"
    REF_TMP=$(mktemp -d 2>/dev/null)
    if [ -f "$REF_DOC" ] && [ -n "$REF_TMP" ]; then
        # Materialize the schema into a fresh temp dir (the SCHEMA_TMP above is gone)
        bash "$SCHEMA_FILE" "$REF_TMP/.agent-memory" >/dev/null 2>&1
        # Extract documented memory paths: only tokens under a known .agent-memory/
        # top-level dir (so prose refs like `commands/init.md` or `memory-maintenance/
        # SKILL.md` in the source-header are not mistaken for store paths).
        # project-context.md is exempt (SSoT does not create it — written by consumers).
        DOC_MISSING=""
        DOC_PATHS=$(grep -oE '(identity|context|iterations|patterns|quality|knowledge|learnings|working|generated-skills)/[a-zA-Z0-9_.-]+\.(json|md)' "$REF_DOC" | sort -u)
        for p in $DOC_PATHS; do
            case "$p" in
                context/project-context.md) continue ;;        # consumer-written, not SSoT
                *-archive-*) continue ;;                        # archive examples, created on rotation
            esac
            [ -f "$REF_TMP/.agent-memory/$p" ] || DOC_MISSING="$DOC_MISSING $p"
        done
        rm -rf "$REF_TMP"
        if [ -z "$DOC_MISSING" ]; then
            pass "references/memory-structure.md documents only paths the SSoT produces"
        else
            fail "references/memory-structure.md names paths the SSoT does NOT create (doc drift):$DOC_MISSING"
        fi
    fi
fi

echo ""
echo "-- project-context.md: all writers honor docs-as-source-of-truth --"
# project-context.md is a CACHE of the project docs. EVERY writer (hook, /init,
# context-detective, context-keeper) must reference the docs as source of truth so the
# cache can never silently diverge from docs/. Guards against the divergence paths the
# Codex verifier flagged (2026-06-01).
PC_WRITERS_OK=true
# context-keeper must declare the source-of-truth hierarchy
if [ -f "$PLUGIN_ROOT/skills/context-keeper/SKILL.md" ]; then
    grep -q "Source-of-Truth Hierarchy" "$PLUGIN_ROOT/skills/context-keeper/SKILL.md" || { PC_WRITERS_OK=false; echo "    (context-keeper: missing Source-of-Truth Hierarchy)"; }
fi
# /init must read docs before detecting
if [ -f "$PLUGIN_ROOT/commands/init.md" ]; then
    grep -qiE "docs first|source of truth" "$PLUGIN_ROOT/commands/init.md" || { PC_WRITERS_OK=false; echo "    (init.md: missing docs-first rule)"; }
fi
# context-detective must read docs first
if [ -f "$PLUGIN_ROOT/agents/context-detective.md" ]; then
    grep -qiE "docs FIRST|source of truth" "$PLUGIN_ROOT/agents/context-detective.md" || { PC_WRITERS_OK=false; echo "    (context-detective: missing docs-first rule)"; }
fi
# hook template must carry the cache pointer line
if [ -f "$PLUGIN_ROOT/scripts/session-start.sh" ]; then
    grep -q "This file is a cache" "$PLUGIN_ROOT/scripts/session-start.sh" || { PC_WRITERS_OK=false; echo "    (session-start.sh: missing cache pointer in project-context template)"; }
fi
if [ "$PC_WRITERS_OK" = true ]; then
    pass "all project-context.md writers reference docs as source of truth"
else
    fail "a project-context.md writer does not honor docs-as-source-of-truth — cache can silently diverge from docs/"
fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
