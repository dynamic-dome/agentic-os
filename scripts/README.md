# Scripts

## pre-tool-use-circuit-breaker.sh (aktiv)

Deterministischer `PreToolUse`-Command-Hook fuer Bash-Tool-Aufrufe. Das Skript
liest das Hook-JSON ueber stdin, prueft gefaehrliche Shell-Muster und blockiert
vor Ausfuehrung mit Exit-Code `2`.

**Blockiert u.a.:**
- rekursive Force-Deletes (`rm -rf`, `Remove-Item -Recurse -Force`, `rmdir /s /q`)
- destruktive Git-Aktionen (`git reset --hard`, `git clean -fd/-xdf`, Force-Push)
- globale Rechte-/Ownership-Aenderungen (`chmod 777`, `chown -R`)
- Format-/Blockdevice-Schreiboperationen und Download-to-Shell-Pipes

## session-start.sh (v3 — aktiv)

Shell-Skript fuer den `SessionStart`-Command-Hook.

**Features:**
- Auto-Init: Erstellt `.agent-memory/` mit allen 14 Dateien falls nicht vorhanden
- Stack-Erkennung: Sprache, Framework, Package Manager aus Projektdateien
- Kontext-Injection: Git-Branch, Session-Summary, Identity, Quality-Warnings, Statistiken
- Env-Vars: Setzt `AGENTIC_OS_ACTIVE` und `AGENTIC_OS_MEMORY_DIR`

## session-end.sh / pre-compact.sh (DEPRECATED)

Diese Skripte wurden durch **prompt-basierte Hooks** in `hooks/hooks.json` ersetzt.
`SessionEnd`, `PreCompact` und `Stop` unterstuetzen alle Prompt-Hooks.
