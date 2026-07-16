#!/bin/bash
# Agentic OS — T-24: Bootstrap-Briefing fuer Codex-Sessions.
# Aufruf NUR via session-start.sh-Routing (Skriptpfad liegt unter /.codex/).
# Kontrakt (Nerv-Schutz, membrain/memcodexlifecycle.md §3.4): exit IMMER 0,
# stderr IMMER leer, KEIN Auto-Init, fehlender Store -> stiller Minimal-Output.
# Headless-Guard: S0-Befund c — es gibt kein zuverlaessiges Interaktiv-Signal;
# Schutz kommt aus Fail-fast, die Env-Variable bleibt als Escape-Hatch.
set +e
exec 2>/dev/null

emit_minimal() { echo '{"continue": true}'; exit 0; }

[ -n "${AGENTIC_OS_CODEX_HEADLESS:-}" ] && emit_minimal

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
MEMORY_DIR="$PROJECT_DIR/.agent-memory"
CENTRAL_HANDOFF="$HOME/AI/.agent-memory/session-summary.md"

# Kein Store -> kein Briefing, NIE Auto-Init (Spec §3.2)
[ -d "$MEMORY_DIR" ] || emit_minimal

PYBIN="python3"; command -v python3 >/dev/null 2>&1 || PYBIN="python"
command -v "$PYBIN" >/dev/null 2>&1 || emit_minimal

ctx=""

# 1) Zentraler Handoff: Top-Block, max 3 Inhaltszeilen
if [ -f "$CENTRAL_HANDOFF" ]; then
  HANDOFF=$(head -14 "$CENTRAL_HANDOFF" | grep -Ev '^(#|\*|$|---)' | head -3 | tr '\n' ' ')
  [ -n "$HANDOFF" ] && ctx="Letzter Handoff (cross-project): $HANDOFF"
fi

# 2) Open Tasks (IDs + Titel), fail-soft via python
OPEN_TASKS=$("$PYBIN" - "$MEMORY_DIR/context/open-tasks.json" << 'EOPY'
import json, sys
try:
    raw = json.load(open(sys.argv[1], encoding="utf-8"))
    tasks = raw if isinstance(raw, list) else raw.get("tasks", [])
    items = [t for t in tasks if isinstance(t, dict) and t.get("status") in ("open", "blocked")]
    print("; ".join(f"{t.get('id','?')}: {str(t.get('title',''))[:120]}" for t in items[:5]))
except Exception:
    pass
EOPY
)
[ -n "$OPEN_TASKS" ] && ctx="$ctx\nOffene Tasks: $OPEN_TASKS"

# 3) Statischer Atlas-Hinweis (Pull-Pfad aus T-14, membrain/membridge.md §3.5)
ATLAS_HINT="Vor Spezialaufgaben Atlas fragen: curl -s -X POST http://127.0.0.1:7801/search -H \"Content-Type: application/json\" -d '{\"query\": \"<thema>\", \"top_k\": 5}'"
ctx="$ctx\n$ATLAS_HINT"

ctx="[AGENTIC OS — CODEX BRIEFING]$ctx"

escaped=$(printf '%b' "$ctx" | "$PYBIN" -c "import sys,json; print(json.dumps(sys.stdin.read()))") || emit_minimal
[ -n "$escaped" ] || emit_minimal
cat << EOJSON
{
  "continue": true,
  "systemMessage": $escaped
}
EOJSON
exit 0
