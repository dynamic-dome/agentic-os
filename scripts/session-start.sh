#!/bin/bash
# Agentic OS — SessionStart Hook (v4)
# Auto-Init + Context Injection + Dirty-Recovery-Check. Platform: Windows (Git Bash) + Linux/Mac.
# Output: JSON with systemMessage for Claude.

# No set -euo pipefail — we want to continue even if files are missing
set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MEMORY_DIR="$PROJECT_DIR/.agent-memory"

# ============================================================
# PHASE 0: Load the schema Single Source of Truth (scripts/mem-schema.sh)
# ============================================================
# Sourced ONCE here; used for BOTH fresh init (Phase 1) and backfill (Phase 2),
# so a missing file can never reappear inline. NEVER inline the file list anywhere.
SCHEMA_SH="$(dirname "${BASH_SOURCE[0]}")/mem-schema.sh"
SCHEMA_OK=false
if [ -f "$SCHEMA_SH" ]; then
  # shellcheck source=mem-schema.sh
  source "$SCHEMA_SH" && SCHEMA_OK=true
fi
if [ "$SCHEMA_OK" != true ]; then
  # Loud failure: the schema file is the contract for the whole memory system.
  # Do not silently half-create — tell the user and still let the session start.
  echo "[Agentic OS] WARNING: scripts/mem-schema.sh missing or unreadable — memory auto-init/backfill skipped. Run /agentic-os:init to repair." >&2
fi

# ============================================================
# PHASE 1: Auto-Init (if .agent-memory/ does not exist)
# ============================================================

if [ ! -d "$MEMORY_DIR" ] && [ "$SCHEMA_OK" = true ]; then
  create_memory_structure "$MEMORY_DIR"

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

  # Full 7-section layout — matches context-keeper's structure so a later
  # context-keeper run refines this cache instead of reshaping it (no format drift).
  cat > "$MEMORY_DIR/context/project-context.md" << EOFILE
# Project Context

*Last updated: $(date +%Y-%m-%d 2>/dev/null || echo unknown)*
*Source: docs/ (PROJECT.md, ARCHITECTURE.md) once they exist. This file is a cache.*

## Project
${PROJECT_NAME} — (one-line description: to be documented)

## Tech Stack
- **Language:** ${LANG:-unknown}
- **Framework:** ${FRAMEWORK:-none detected}
- **Package Manager:** ${PKG_MGR:-none detected}

## Architecture
- (To be documented — run /agentic-os:init or context-keeper to distill from docs/)

## Key Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| (none recorded) | | |

## Constraints
- (To be documented)

## Current Status
- **Phase:** fresh initialization
- **Priority:** review project context

## Open Questions
- (none yet)
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
  # ============================================================
  # PHASE 2: Backfill — converge an existing (possibly incomplete) memory dir
  #          to the FULL schema. Reuses the SAME SSoT as init (idempotent: only
  #          absent files are created), so older/partial dirs heal completely —
  #          not just the three files that were hand-listed before (L4 fix).
  # ============================================================
  if [ "$SCHEMA_OK" = true ]; then
    create_memory_structure "$MEMORY_DIR"
  fi
  # project-context.md is outside the SSoT (needs stack detection). Backfill a stub
  # if it is missing, so bootstrap's health check never warns on a half-built dir.
  if [ ! -f "$MEMORY_DIR/context/project-context.md" ]; then
    mkdir -p "$MEMORY_DIR/context"
    printf '# Project Context\n\n## Project\n- **Name:** %s\n\n## Architecture\n- (To be documented — run /agentic-os:init for stack auto-detection)\n\n## Current Status\n- (backfilled stub)\n' "$(basename "$PROJECT_DIR")" > "$MEMORY_DIR/context/project-context.md"
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

  # User profile (first 4 preference/work-style bullets) — primes the agent to
  # NOTICE preference deltas mid-session; without this, identity growth relies
  # entirely on end-of-session recall (the weakest context point).
  if [ -f "$MEMORY_DIR/identity/user.md" ]; then
    USER_PROFILE=$(grep -E "^- " "$MEMORY_DIR/identity/user.md" 2>/dev/null | head -4 | tr '\n' ' ' || true)
    [ -n "$USER_PROFILE" ] && context="$context\nUser: $USER_PROFILE"
  fi

  # Project context (language + framework)
  if [ -f "$MEMORY_DIR/context/project-context.md" ]; then
    STACK=$(grep -E "Language:|Framework:|Package Manager:" "$MEMORY_DIR/context/project-context.md" 2>/dev/null | tr '\n' ' ' || true)
    [ -n "$STACK" ] && context="$context\nStack: $STACK"
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

# Mechanical recovery check (dirty-tracker): un-consolidated sessions.
# Only files older than 30 min count — younger dirty files are most likely a
# parallel session running RIGHT NOW, never flag those. while-read (not an
# unquoted for-loop): the FULL path includes $MEMORY_DIR, which may contain
# spaces even though the dirty-<sid>.json filename itself never does.
DIRTY_COUNT=0
if [ -d "$MEMORY_DIR/working" ]; then
  while IFS= read -r df; do
    [ -n "$df" ] || continue
    grep -q '"dirty": true' "$df" 2>/dev/null || continue
    # Tail-write downgrade: writes_since_consolidation exists only after a
    # consolidation (hook preserves the fact on re-dirty). <=5 writes since
    # = wrap-up's own post-marker writes, not a crashed session.
    WSC=$(sed -n 's/.*"writes_since_consolidation": *\([0-9][0-9]*\).*/\1/p' "$df" 2>/dev/null | head -1)
    if [ -n "$WSC" ] && [ "$WSC" -le 5 ]; then continue; fi
    DIRTY_COUNT=$((DIRTY_COUNT + 1))
  done < <(find "$MEMORY_DIR/working" -name 'dirty-*.json' -mmin +30 2>/dev/null)
fi
if [ "$DIRTY_COUNT" -gt 0 ]; then
  RECOVERY_LINE="RECOVERY: ${DIRTY_COUNT} unkonsolidierte Session(s) erkannt — wrap-up ausfuehren (Step 1.5 harvestet aus touched_files + git)"
  BRIEFING="${BRIEFING:+$BRIEFING | }$RECOVERY_LINE"
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
# Join the two optional lines with a \n separator only when BOTH are present,
# so they never run together as "Newly initialized!Next steps...".
OPT_LINES="$INIT_LINE"
if [ -n "$INIT_LINE" ] && [ -n "$BRIEF_LINE" ]; then
  OPT_LINES="${INIT_LINE}\n${BRIEF_LINE}"
elif [ -n "$BRIEF_LINE" ]; then
  OPT_LINES="$BRIEF_LINE"
fi
context="[AGENTIC OS SESSION BRIEFING] At your FIRST response in this session, begin with a compact briefing block:\n---\nAgentic OS active | Branch: ${BRANCH:-?} | ${ITER_COUNT:-0} iterations, ${ERR_COUNT:-0} errors, ${PAT_COUNT:-0} patterns\n${OPT_LINES}\n---\nThen respond normally to the user's question.\n\n$context"

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
