#!/bin/bash
set -euo pipefail

# Agentic OS — PreCompact Hook
# Re-injected kritischen Kontext BEVOR die Context-Komprimierung startet.
# Ohne diesen Hook gehen Projekt-Regeln und Session-State bei langen Sessions verloren.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MEMORY_DIR="$PROJECT_DIR/.agent-memory"

context="## KONTEXT-WIEDERHERSTELLUNG (Pre-Compact)\n\n"

# Git State
if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  context+="**Branch:** $BRANCH\n"
fi

# Agent-Memory Summary
if [ -d "$MEMORY_DIR" ] && [ -f "$MEMORY_DIR/session-summary.md" ]; then
  summary=$(head -15 "$MEMORY_DIR/session-summary.md" 2>/dev/null || true)
  [ -n "$summary" ] && context+="### Session-Kontext\n$summary\n\n"
fi

# Identity
if [ -d "$MEMORY_DIR" ] && [ -f "$MEMORY_DIR/identity/soul.md" ]; then
  soul=$(head -10 "$MEMORY_DIR/identity/soul.md" 2>/dev/null || true)
  [ -n "$soul" ] && context+="### Identity\n$soul\n\n"
fi

context+="---\nKontext wurde komprimiert. Bei Bedarf relevante Dateien neu lesen."

escaped=$(echo -e "$context" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"[Agentic OS] Kontext wiederhergestellt.\"")

cat <<EOJSON
{
  "continue": true,
  "systemMessage": $escaped
}
EOJSON
