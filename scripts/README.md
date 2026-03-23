# Scripts

## session-start.sh (v3 — aktiv)

Einziges Shell-Skript das noch aktiv genutzt wird, da `SessionStart` nur `command`-Hooks unterstuetzt (keine Prompt-Hooks).

**Features:**
- Auto-Init: Erstellt `.agent-memory/` mit allen 14 Dateien falls nicht vorhanden
- Stack-Erkennung: Sprache, Framework, Package Manager aus Projektdateien
- Kontext-Injection: Git-Branch, Session-Summary, Identity, Quality-Warnings, Statistiken
- Env-Vars: Setzt `AGENTIC_OS_ACTIVE` und `AGENTIC_OS_MEMORY_DIR`

## session-end.sh / pre-compact.sh (DEPRECATED)

Diese Skripte wurden durch **prompt-basierte Hooks** in `hooks/hooks.json` ersetzt.
`SessionEnd`, `PreCompact` und `Stop` unterstuetzen alle Prompt-Hooks.
