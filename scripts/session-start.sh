#!/bin/bash
# Agentic OS — SessionStart Hook (v3)
# Auto-Init + Context Injection. Platform: Windows (Git Bash) + Linux/Mac.
# Output: JSON with systemMessage for Claude.

# No set -euo pipefail — we want to continue even if files are missing
set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MEMORY_DIR="$PROJECT_DIR/.agent-memory"

# ============================================================
# PHASE 1: Auto-Init (if .agent-memory/ does not exist)
# ============================================================

if [ ! -d "$MEMORY_DIR" ]; then
  # Create the full structure from the Single Source of Truth (scripts/mem-schema.sh).
  # NEVER inline the file list here — add new memory files in mem-schema.sh only.
  SCHEMA_SH="$(dirname "${BASH_SOURCE[0]}")/mem-schema.sh"
  if [ -f "$SCHEMA_SH" ]; then
    # shellcheck source=mem-schema.sh
    source "$SCHEMA_SH"
    create_memory_structure "$MEMORY_DIR"
  else
    # Defensive fallback: schema file missing — create the bare minimum so the
    # session can still start. This should never happen in a packaged plugin.
    mkdir -p "$MEMORY_DIR/identity" "$MEMORY_DIR/context" "$MEMORY_DIR/iterations" \
             "$MEMORY_DIR/patterns" "$MEMORY_DIR/quality" "$MEMORY_DIR/learnings" \
             "$MEMORY_DIR/generated-skills" "$MEMORY_DIR/knowledge" "$MEMORY_DIR/working"
    echo "[]" > "$MEMORY_DIR/learnings/learnings.json"
    echo "[]" > "$MEMORY_DIR/context/open-tasks.json"
  fi

  # project-context.md is hook-specific (inline stack auto-detect, no LLM/user).
  # Deliberately NOT in mem-schema.sh — /init writes it differently (LLM + confirm).
  PROJECT_NAME=$(basename "$PROJECT_DIR")
  LANG=""
  FRAMEWORK=""
  PKG_MGR=""

  [ -f "$PROJECT_DIR/package.json" ] && LANG="JavaScript/TypeScript"
  [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/requirements.txt" ] && LANG="Python"
  [ -f "$PROJECT_DIR/Cargo.toml" ] && LANG="Rust"
  [ -f "$PROJECT_DIR/go.mod" ] && LANG="Go"
  [ -f "$PROJECT_DIR/pom.xml" ] && LANG="Java"

  if [ -f "$PROJECT_DIR/package.json" ]; then
    # Framework detection from package.json
    grep -q '"next"' "$PROJECT_DIR/package.json" 2>/dev/null && FRAMEWORK="Next.js"
    grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null && [ -z "$FRAMEWORK" ] && FRAMEWORK="React"
    grep -q '"vue"' "$PROJECT_DIR/package.json" 2>/dev/null && FRAMEWORK="Vue"
    grep -q '"express"' "$PROJECT_DIR/package.json" 2>/dev/null && FRAMEWORK="Express"
    grep -q '"fastify"' "$PROJECT_DIR/package.json" 2>/dev/null && FRAMEWORK="Fastify"
  fi

  for pm_lock in "bun.lockb:Bun" "pnpm-lock.yaml:pnpm" "yarn.lock:Yarn" "package-lock.json:npm" "poetry.lock:Poetry" "Pipfile.lock:Pipenv"; do
    file="${pm_lock%%:*}"
    name="${pm_lock##*:}"
    if [ -f "$PROJECT_DIR/$file" ]; then
      PKG_MGR="$name"
      break
    fi
  done

  cat > "$MEMORY_DIR/context/project-context.md" << EOFILE
# Project Context

## Project
- **Name:** ${PROJECT_NAME}
- **Language:** ${LANG:-unknown}
- **Framework:** ${FRAMEWORK:-none detected}
- **Package Manager:** ${PKG_MGR:-none detected}

## Architecture
- (To be documented)

## Constraints
- (To be documented)

## Current Status
- Fresh initialization
EOFILE

  INIT_MSG="[Agentic OS] Memory system initialized for '${PROJECT_NAME}'. Stack: ${LANG:-?} + ${FRAMEWORK:-?}. Please review .agent-memory/context/project-context.md."
fi

# ============================================================
# PHASE 2: Load context and output as systemMessage
# ============================================================

context=""

# Git-State
if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  context="Branch: $BRANCH"

  STAGED=$(git diff --cached --stat 2>/dev/null | tail -1)
  [ -n "$STAGED" ] && context="$context | Staged: $STAGED"

  UNSTAGED=$(git diff --stat 2>/dev/null | tail -1)
  [ -n "$UNSTAGED" ] && context="$context | Unstaged: $UNSTAGED"
fi

# Load memory context
if [ -d "$MEMORY_DIR" ]; then
  # Backfill missing files for projects initialized by an older hook (or after wrap-up reset).
  # These are MANDATORY for wrap-up + bootstrap; idempotent — only created if absent.
  [ -f "$MEMORY_DIR/learnings/learnings.json" ] || { mkdir -p "$MEMORY_DIR/learnings"; echo "[]" > "$MEMORY_DIR/learnings/learnings.json"; }
  [ -f "$MEMORY_DIR/context/open-tasks.json" ] || { mkdir -p "$MEMORY_DIR/context"; echo "[]" > "$MEMORY_DIR/context/open-tasks.json"; }
  if [ ! -f "$MEMORY_DIR/working/current-session.json" ]; then
    mkdir -p "$MEMORY_DIR/working"
    WM_DATE=$(date +%Y-%m-%d 2>/dev/null || echo "unknown")
    printf '{"session_start": "%s", "errors_this_session": [], "learnings_draft": []}\n' "$WM_DATE" > "$MEMORY_DIR/working/current-session.json"
  fi

  # Session summary (first 10 lines)
  if [ -f "$MEMORY_DIR/session-summary.md" ]; then
    SUMMARY=$(head -10 "$MEMORY_DIR/session-summary.md" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' || true)
    [ -n "$SUMMARY" ] && context="$context\nLast session: $SUMMARY"
  fi

  # Soul (first 5 lines, core settings only)
  if [ -f "$MEMORY_DIR/identity/soul.md" ]; then
    SOUL=$(grep -E "^- " "$MEMORY_DIR/identity/soul.md" 2>/dev/null | head -5 | tr '\n' ' ' || true)
    [ -n "$SOUL" ] && context="$context\nIdentity: $SOUL"
  fi

  # Project context (language + framework)
  if [ -f "$MEMORY_DIR/context/project-context.md" ]; then
    STACK=$(grep -E "Language:|Framework:|Package Manager:" "$MEMORY_DIR/context/project-context.md" 2>/dev/null | tr '\n' ' ' || true)
    [ -n "$STACK" ] && context="$context\nStack: $STACK"
  fi

  # Quality warnings
  if [ -f "$MEMORY_DIR/quality/quality-score.json" ]; then
    DECLINING=$(grep -c '"declining"' "$MEMORY_DIR/quality/quality-score.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
    [ "${DECLINING:-0}" -gt 0 ] 2>/dev/null && context="$context\nWARNING: Quality scores are declining!"
  fi

  # Statistics (tr -d removes whitespace/newlines from grep -c)
  ERR_COUNT=$(grep -c '"id"' "$MEMORY_DIR/iterations/errors.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
  ITER_COUNT=$(grep -c "^## Iteration" "$MEMORY_DIR/iterations/iteration-log.md" 2>/dev/null | tr -d '[:space:]' || echo "0")
  PAT_COUNT=$(grep -c '"id"' "$MEMORY_DIR/patterns/patterns.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
  context="$context | Stats: ${ITER_COUNT} iter, ${ERR_COUNT} errors, ${PAT_COUNT} patterns"

  [ "${ERR_COUNT:-0}" -gt 15 ] 2>/dev/null && context="$context\nNote: Many errors logged — consider running pattern-extractor."

  # Env-Vars setzen
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export AGENTIC_OS_ACTIVE=true" >> "$CLAUDE_ENV_FILE"
    echo "export AGENTIC_OS_MEMORY_DIR=$MEMORY_DIR" >> "$CLAUDE_ENV_FILE"
  fi
fi

# Prepend init message if freshly initialized
if [ -n "${INIT_MSG:-}" ]; then
  context="$INIT_MSG\n\n$context"
fi

# Session briefing: open items and next steps from session-summary.md
BRIEFING=""
if [ -f "$MEMORY_DIR/session-summary.md" ]; then
  # Extract next steps
  NEXT_STEPS=$(sed -n '/## Next Steps/,/^## /{ /^## Next Steps/d; /^## /d; p; }' "$MEMORY_DIR/session-summary.md" 2>/dev/null | head -5 | tr '\n' ' ' || true)
  [ -n "$NEXT_STEPS" ] && BRIEFING="Next steps: $NEXT_STEPS"

  # Extract open items
  OPEN_ITEMS=$(sed -n '/## Open Items/,/^## /{ /^## Open Items/d; /^## /d; p; }' "$MEMORY_DIR/session-summary.md" 2>/dev/null | head -3 | tr '\n' ' ' || true)
  [ -n "$OPEN_ITEMS" ] && BRIEFING="$BRIEFING | Open: $OPEN_ITEMS"

  # Extract active warnings
  WARNINGS=$(sed -n '/## Active Warnings/,/^## /{ /^## Active Warnings/d; /^## /d; /^$/d; p; }' "$MEMORY_DIR/session-summary.md" 2>/dev/null | head -3 | tr '\n' ' ' || true)
  [ -n "$WARNINGS" ] && BRIEFING="$BRIEFING | Warnings: $WARNINGS"
fi

# Instruction to Claude: compact briefing in chat.
# Build the optional lines as plain shell statements FIRST. Embedding $(...) with
# escaped quotes inside the assigned double-quoted string left the test operands
# effectively unquoted at subshell-eval time → "[: too many arguments" whenever
# BRIEFING held pipes/spaces ("| Open: ... | Warnings: ..."). Plain statements fix it.
INIT_LINE=""
[ -n "${INIT_MSG:-}" ] && INIT_LINE="Newly initialized!"
BRIEF_LINE=""
[ -n "${BRIEFING:-}" ] && BRIEF_LINE="$BRIEFING"
context="[AGENTIC OS SESSION BRIEFING] At your FIRST response in this session, begin with a compact briefing block:\n---\nAgentic OS active | Branch: ${BRANCH:-?} | ${ITER_COUNT:-0} iterations, ${ERR_COUNT:-0} errors, ${PAT_COUNT:-0} patterns\n${INIT_LINE}${BRIEF_LINE}\n---\nThen respond normally to the user's question.\n\n$context"

# Generate JSON output (python3 for safe escaping, fallback without)
if command -v python3 > /dev/null 2>&1; then
  escaped=$(printf '%s' "$context" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
elif command -v python > /dev/null 2>&1; then
  escaped=$(printf '%s' "$context" | python -c "import sys,json; print(json.dumps(sys.stdin.read()))")
else
  # Fallback: simple escaping
  safe=$(printf '%s' "$context" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
  escaped="\"$safe\""
fi

cat << EOJSON
{
  "continue": true,
  "systemMessage": $escaped
}
EOJSON
