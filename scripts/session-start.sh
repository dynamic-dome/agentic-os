#!/bin/bash
set -euo pipefail

# Agentic OS — SessionStart Hook (v2)
# Injected dynamischen Projekt-Kontext + Agent-Memory in jede Session.
# Basiert auf Context-Injection Pattern: stdout = Kontext fuer Claude.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MEMORY_DIR="$PROJECT_DIR/.agent-memory"

# --- Immer: Dynamischer Projekt-State ---
context="## Projekt-State\n"

if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  context+="- **Branch:** $BRANCH\n"

  STAGED=$(git diff --cached --stat 2>/dev/null | tail -1)
  [ -n "$STAGED" ] && context+="- **Staged:** $STAGED\n"

  UNSTAGED=$(git diff --stat 2>/dev/null | tail -1)
  [ -n "$UNSTAGED" ] && context+="- **Unstaged:** $UNSTAGED\n"

  RECENT=$(git log --oneline -3 2>/dev/null)
  [ -n "$RECENT" ] && context+="- **Letzte Commits:**\n\`\`\`\n$RECENT\n\`\`\`\n"
fi

TODO_COUNT=$(grep -rl "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.py" --include="*.js" --include="*.tsx" --include="*.jsx" "$PROJECT_DIR" 2>/dev/null | wc -l | tr -d '[:space:]')
[ "${TODO_COUNT:-0}" -gt 0 ] 2>/dev/null && context+="- **Dateien mit TODOs:** $TODO_COUNT\n"

# Package Manager erkennen
for pm_lock in "bun.lockb:Bun" "pnpm-lock.yaml:pnpm" "yarn.lock:Yarn" "package-lock.json:npm" "poetry.lock:Poetry" "Pipfile.lock:Pipenv"; do
  file="${pm_lock%%:*}"
  name="${pm_lock##*:}"
  if [ -f "$PROJECT_DIR/$file" ]; then
    context+="- **Package Manager:** $name\n"
    break
  fi
done

# --- Falls .agent-memory/ vorhanden: Agentic OS Kontext ---
if [ -d "$MEMORY_DIR" ]; then
  context+="\n## Agentic OS\n"

  # Identity / Soul
  if [ -f "$MEMORY_DIR/identity/soul.md" ]; then
    soul=$(head -20 "$MEMORY_DIR/identity/soul.md" 2>/dev/null || true)
    [ -n "$soul" ] && context+="### Identity\n$soul\n\n"
  fi

  # Letzte Session-Summary
  if [ -f "$MEMORY_DIR/session-summary.md" ]; then
    summary=$(head -30 "$MEMORY_DIR/session-summary.md" 2>/dev/null || true)
    [ -n "$summary" ] && context+="### Letzte Session\n$summary\n\n"
  fi

  # Quality Warnings
  if [ -f "$MEMORY_DIR/quality/quality-score.json" ]; then
    declining=$(grep -c '"declining"' "$MEMORY_DIR/quality/quality-score.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
    [ "${declining:-0}" -gt 0 ] 2>/dev/null && context+="### WARNUNG\nQuality Scores sind declining! Bitte pruefen.\n\n"
  fi

  # Iteration-Count fuer Empfehlung
  iteration_count=0
  if [ -f "$MEMORY_DIR/iterations/errors.json" ]; then
    iteration_count=$(grep -c '"id"' "$MEMORY_DIR/iterations/errors.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
  fi
  [ "${iteration_count:-0}" -gt 15 ] 2>/dev/null && context+="**Hinweis:** $iteration_count Fehler-Eintraege — Pattern-Extract empfohlen.\n"

  # Env-Vars setzen
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export AGENTIC_OS_ACTIVE=true" >> "$CLAUDE_ENV_FILE"
    echo "export AGENTIC_OS_MEMORY_DIR=$MEMORY_DIR" >> "$CLAUDE_ENV_FILE"
  fi

  context+="\nFuehre 'agentic-os:session-bootstrap' aus fuer ein vollstaendiges Briefing."
fi

# --- Kontext als systemMessage ausgeben ---
escaped=$(echo -e "$context" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"[Agentic OS] Session gestartet.\"")

cat <<EOJSON
{
  "continue": true,
  "systemMessage": $escaped
}
EOJSON
