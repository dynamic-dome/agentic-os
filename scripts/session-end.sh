#!/bin/bash
set -euo pipefail

# Agentic OS — SessionEnd Hook
# Weist Claude an, wrap-up durchzuführen inkl. Learnings, Pattern-Extract und Skill-Generation.
# Nur aktiv wenn .agent-memory/ im Projekt existiert.

MEMORY_DIR="${CLAUDE_PROJECT_DIR:-.}/.agent-memory"

# Kein .agent-memory? → Still beenden
if [ ! -d "$MEMORY_DIR" ]; then
  cat <<'EOF'
{
  "continue": true,
  "suppressOutput": true
}
EOF
  exit 0
fi

# Statistiken sammeln (tr -d für Windows-Kompatibilität)
iteration_count=$(grep -c "^## Iteration" "$MEMORY_DIR/iterations/iteration-log.md" 2>/dev/null | tr -d '[:space:]' || echo "0")
error_count=$(grep -c '"id"' "$MEMORY_DIR/iterations/errors.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
pattern_count=$(grep -c '"id"' "$MEMORY_DIR/patterns/patterns.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
skill_candidates=$(grep -c '"skill_candidate": true' "$MEMORY_DIR/patterns/patterns.json" 2>/dev/null | tr -d '[:space:]' || echo "0")

# systemMessage bauen
msg="[Agentic OS] Session wird beendet. Führe jetzt das Wrap-Up durch:\n\n"
msg="${msg}1. Aktualisiere session-summary.md (max 30 Zeilen: was wurde gemacht, offene Punkte, nächste Schritte)\n"
msg="${msg}2. Logge alle ungeloggten Iterationen zu iteration-log.md\n"
msg="${msg}3. Extrahiere Learnings nach learnings.md (nur echte Einsichten, keine trivialen Fakten)\n"

if [ "${iteration_count:-0}" -ge 3 ] 2>/dev/null || [ "${error_count:-0}" -ge 3 ] 2>/dev/null; then
  msg="${msg}4. Führe Pattern-Extract aus (agentic-os:pattern-extractor) — ${error_count} Fehler, ${iteration_count} Iterationen vorhanden\n"
fi

if [ "${skill_candidates:-0}" -gt 0 ] 2>/dev/null; then
  msg="${msg}5. Es gibt ${skill_candidates} Skill-Kandidaten — prüfe ob neue Skills generiert werden sollten (agentic-os:skill-generator)\n"
fi

msg="${msg}\nStatistiken: ${iteration_count} Iterationen, ${error_count} Fehler, ${pattern_count} Patterns, ${skill_candidates} Skill-Kandidaten"

# JSON-safe escapen
escaped_msg=$(echo -e "$msg" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"[Agentic OS] Session beendet. Bitte wrap-up durchführen.\"")

cat <<EOJSON
{
  "continue": true,
  "systemMessage": $escaped_msg
}
EOJSON
