#!/bin/bash
# Agentic OS — SessionStart Hook (v3)
# Auto-Init + Kontext-Injection. Plattform: Windows (Git Bash) + Linux/Mac.
# Ausgabe: JSON mit systemMessage fuer Claude.

# Kein set -euo pipefail — wir wollen bei fehlenden Dateien nicht abbrechen
set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MEMORY_DIR="$PROJECT_DIR/.agent-memory"

# ============================================================
# PHASE 1: Auto-Init (falls .agent-memory/ nicht existiert)
# ============================================================

if [ ! -d "$MEMORY_DIR" ]; then
  # Verzeichnisse anlegen
  mkdir -p "$MEMORY_DIR/identity"
  mkdir -p "$MEMORY_DIR/context"
  mkdir -p "$MEMORY_DIR/iterations"
  mkdir -p "$MEMORY_DIR/patterns"
  mkdir -p "$MEMORY_DIR/quality"
  mkdir -p "$MEMORY_DIR/learnings"
  mkdir -p "$MEMORY_DIR/generated-skills"

  # session-summary.md
  cat > "$MEMORY_DIR/session-summary.md" << 'EOFILE'
# Letzte Session

*Erste Session — System frisch initialisiert.*

## Naechste Schritte
1. Projektkontext pruefen
2. Erste Coding-Iteration starten
EOFILE

  # identity/soul.md
  cat > "$MEMORY_DIR/identity/soul.md" << 'EOFILE'
# Agent Identity

## Communication
- Language: de (switch to en if user writes in English)
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
    # Framework-Erkennung aus package.json
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

  # JSON-Dateien
  echo "[]" > "$MEMORY_DIR/context/decisions.json"
  echo "[]" > "$MEMORY_DIR/iterations/errors.json"
  echo "[]" > "$MEMORY_DIR/patterns/patterns.json"
  echo "[]" > "$MEMORY_DIR/quality/test-results.json"
  echo "[]" > "$MEMORY_DIR/quality/code-reviews.json"
  cat > "$MEMORY_DIR/quality/quality-score.json" << 'EOFILE'
{"last_updated": null, "test_health": {"current_score": null, "trend": "unknown"}, "code_quality": {"current_score": null, "trend": "unknown"}}
EOFILE

  # Markdown-Dateien
  printf '# Iteration Log\n\n*Noch keine Eintraege.*\n' > "$MEMORY_DIR/iterations/iteration-log.md"
  printf '# Pattern-Katalog\n\n*Noch keine Patterns erkannt.*\n' > "$MEMORY_DIR/patterns/patterns.md"
  printf '# Learnings\n\n*Noch keine Session-Learnings.*\n' > "$MEMORY_DIR/learnings/learnings.md"

  INIT_MSG="[Agentic OS] Memory-System initialisiert fuer '${PROJECT_NAME}'. Stack: ${LANG:-?} + ${FRAMEWORK:-?}. Bitte .agent-memory/context/project-context.md pruefen."
fi

# ============================================================
# PHASE 2: Kontext laden und als systemMessage ausgeben
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

# Memory-Kontext laden
if [ -d "$MEMORY_DIR" ]; then
  # Session-Summary (erste 10 Zeilen)
  if [ -f "$MEMORY_DIR/session-summary.md" ]; then
    SUMMARY=$(head -10 "$MEMORY_DIR/session-summary.md" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' || true)
    [ -n "$SUMMARY" ] && context="$context\nLetzte Session: $SUMMARY"
  fi

  # Soul (erste 5 Zeilen, nur Kern-Settings)
  if [ -f "$MEMORY_DIR/identity/soul.md" ]; then
    SOUL=$(grep -E "^- " "$MEMORY_DIR/identity/soul.md" 2>/dev/null | head -5 | tr '\n' ' ' || true)
    [ -n "$SOUL" ] && context="$context\nIdentity: $SOUL"
  fi

  # Project-Context (Sprache + Framework)
  if [ -f "$MEMORY_DIR/context/project-context.md" ]; then
    STACK=$(grep -E "Language:|Framework:|Package Manager:" "$MEMORY_DIR/context/project-context.md" 2>/dev/null | tr '\n' ' ' || true)
    [ -n "$STACK" ] && context="$context\nStack: $STACK"
  fi

  # Quality Warnings
  if [ -f "$MEMORY_DIR/quality/quality-score.json" ]; then
    DECLINING=$(grep -c '"declining"' "$MEMORY_DIR/quality/quality-score.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
    [ "${DECLINING:-0}" -gt 0 ] 2>/dev/null && context="$context\nWARNUNG: Quality Scores declining!"
  fi

  # Statistiken (tr -d entfernt Whitespace/Newlines von grep -c)
  ERR_COUNT=$(grep -c '"id"' "$MEMORY_DIR/iterations/errors.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
  ITER_COUNT=$(grep -c "^## Iteration" "$MEMORY_DIR/iterations/iteration-log.md" 2>/dev/null | tr -d '[:space:]' || echo "0")
  PAT_COUNT=$(grep -c '"id"' "$MEMORY_DIR/patterns/patterns.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
  context="$context | Stats: ${ITER_COUNT} Iter, ${ERR_COUNT} Err, ${PAT_COUNT} Pat"

  [ "${ERR_COUNT:-0}" -gt 15 ] 2>/dev/null && context="$context\nHinweis: Viele Fehler — Pattern-Extract empfohlen."

  # Env-Vars setzen
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export AGENTIC_OS_ACTIVE=true" >> "$CLAUDE_ENV_FILE"
    echo "export AGENTIC_OS_MEMORY_DIR=$MEMORY_DIR" >> "$CLAUDE_ENV_FILE"
  fi
fi

# Init-Message voranstellen falls frisch initialisiert
if [ -n "${INIT_MSG:-}" ]; then
  context="$INIT_MSG\n\n$context"
fi

# Session-Briefing: Offene Punkte und naechste Schritte aus session-summary.md
BRIEFING=""
if [ -f "$MEMORY_DIR/session-summary.md" ]; then
  # Naechste Schritte extrahieren
  NEXT_STEPS=$(sed -n '/## Naechste Schritte/,/^## /{ /^## Naechste/d; /^## /d; p; }' "$MEMORY_DIR/session-summary.md" 2>/dev/null | head -5 | tr '\n' ' ' || true)
  [ -n "$NEXT_STEPS" ] && BRIEFING="Naechste Schritte: $NEXT_STEPS"

  # Offene Punkte extrahieren
  OPEN_ITEMS=$(sed -n '/## Offene Punkte/,/^## /{ /^## Offene/d; /^## /d; p; }' "$MEMORY_DIR/session-summary.md" 2>/dev/null | head -3 | tr '\n' ' ' || true)
  [ -n "$OPEN_ITEMS" ] && BRIEFING="$BRIEFING | Offen: $OPEN_ITEMS"

  # Aktive Warnungen
  WARNINGS=$(sed -n '/## Aktive Warnungen/,/^## /{ /^## Aktive/d; /^## /d; /^$/d; p; }' "$MEMORY_DIR/session-summary.md" 2>/dev/null | head -3 | tr '\n' ' ' || true)
  [ -n "$WARNINGS" ] && BRIEFING="$BRIEFING | Warnungen: $WARNINGS"
fi

# Anweisung an Claude: Kompaktes Briefing im Chat
context="[AGENTIC OS SESSION BRIEFING] Bei deiner ERSTEN Antwort in dieser Session, beginne mit einem kompakten Briefing-Block:\n---\nAgentic OS aktiv | Branch: ${BRANCH:-?} | ${ITER_COUNT:-0} Iterationen, ${ERR_COUNT:-0} Fehler, ${PAT_COUNT:-0} Patterns\n$([ -n \"${INIT_MSG:-}\" ] && echo 'Neu initialisiert!' || echo '')$([ -n \"$BRIEFING\" ] && echo \"$BRIEFING\" || echo '')\n---\nDanach antworte normal auf die User-Frage.\n\n$context"

# JSON-Output erzeugen (python3 fuer sicheres Escaping, Fallback ohne)
if command -v python3 > /dev/null 2>&1; then
  escaped=$(printf '%s' "$context" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
elif command -v python > /dev/null 2>&1; then
  escaped=$(printf '%s' "$context" | python -c "import sys,json; print(json.dumps(sys.stdin.read()))")
else
  # Fallback: einfaches Escaping
  safe=$(printf '%s' "$context" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
  escaped="\"$safe\""
fi

cat << EOJSON
{
  "continue": true,
  "systemMessage": $escaped
}
EOJSON
