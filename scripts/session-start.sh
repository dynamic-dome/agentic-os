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
  # Create directories
  mkdir -p "$MEMORY_DIR/identity"
  mkdir -p "$MEMORY_DIR/context"
  mkdir -p "$MEMORY_DIR/iterations"
  mkdir -p "$MEMORY_DIR/patterns"
  mkdir -p "$MEMORY_DIR/quality"
  mkdir -p "$MEMORY_DIR/learnings"
  mkdir -p "$MEMORY_DIR/generated-skills"
  mkdir -p "$MEMORY_DIR/knowledge"

  # session-summary.md
  cat > "$MEMORY_DIR/session-summary.md" << 'EOFILE'
# Last Session

*First session — system freshly initialized.*

## Next Steps
1. Review project context
2. Start first coding iteration
EOFILE

  # identity/soul.md
  cat > "$MEMORY_DIR/identity/soul.md" << 'EOFILE'
# Agent Identity

## Communication
- Language: en (switch to de if user writes in German)
- Brevity: 3/5 (balanced)
- Proactivity: 3/5

## Guard Rails
- Confirm before deleting files
- Justify new dependencies
- For multi-file changes: write a brief plan first
- No architecture decisions without discussion

## Priorities
1. Correctness over speed
2. Simplicity over cleverness
3. Working code over perfect code
EOFILE

  # identity/user.md
  TODAY=$(date +%Y-%m-%d 2>/dev/null || echo "unknown")
  cat > "$MEMORY_DIR/identity/user.md" << EOFILE
# User Profile

*Initialized: ${TODAY}*

## Preferences
- (Will be populated through observed patterns)

## Work Style
- (Will be populated through session observations)

## Known Corrections
- (Recorded when user corrects agent behavior 3+ times)
EOFILE

  # context/project-context.md — Auto-Detect
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

  # JSON files
  echo "[]" > "$MEMORY_DIR/context/decisions.json"
  echo "[]" > "$MEMORY_DIR/iterations/errors.json"
  echo "[]" > "$MEMORY_DIR/patterns/patterns.json"
  echo "[]" > "$MEMORY_DIR/quality/test-results.json"
  echo "[]" > "$MEMORY_DIR/quality/code-reviews.json"
  cat > "$MEMORY_DIR/quality/quality-score.json" << 'EOFILE'
{"last_updated": null, "test_health": {"current_score": null, "trend": "unknown"}, "code_quality": {"current_score": null, "trend": "unknown"}}
EOFILE

  # Markdown files
  printf '# Iteration Log\n\n*No entries yet.*\n' > "$MEMORY_DIR/iterations/iteration-log.md"
  printf '# Pattern Catalog\n\n*No patterns detected yet.*\n' > "$MEMORY_DIR/patterns/patterns.md"
  printf '# Learnings\n\n*No session learnings yet.*\n' > "$MEMORY_DIR/learnings/learnings.md"

  # knowledge/notebook-registry.md
  printf '# NotebookLM Knowledge Base Registry\n\n*No notebooks registered yet. Add entries here as you create NotebookLM knowledge bases.*\n\n## Active Notebooks\n\n(none)\n\n## When to consult NotebookLM\n- For expert knowledge on topics covered by a notebook\n- When best practices or reference material is needed\n- When uncertain about the right approach\n' > "$MEMORY_DIR/knowledge/notebook-registry.md"

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

# Instruction to Claude: compact briefing in chat
context="[AGENTIC OS SESSION BRIEFING] At your FIRST response in this session, begin with a compact briefing block:\n---\nAgentic OS active | Branch: ${BRANCH:-?} | ${ITER_COUNT:-0} iterations, ${ERR_COUNT:-0} errors, ${PAT_COUNT:-0} patterns\n$([ -n \"${INIT_MSG:-}\" ] && echo 'Newly initialized!' || echo '')$([ -n \"$BRIEFING\" ] && echo \"$BRIEFING\" || echo '')\n---\nThen respond normally to the user's question.\n\n$context"

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
