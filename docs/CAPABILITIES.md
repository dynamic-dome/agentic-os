# Faehigkeiten — Agentic OS

## Tools & Integrationen

| Tool / Feature | Status | Seit | Beschreibung |
|----------------|--------|------|--------------|
| Memory-Store (`.agent-memory/`) | aktiv | 2026-03 | Persistentes Agent-Gedaechtnis, ein Schreiber pro Datei (DAG) |
| Schema SSoT (`mem-schema.sh`) | aktiv | 2026-06-01 | Eine Definition der Store-Struktur, von Hook + /init genutzt |
| Cross-Project-Handoff | aktiv | 2026-06-01 | Zentraler gestapelter Handoff (prepend) + Status-Board |
| PreToolUse Shell-Circuit-Breaker | aktiv | 2026-06-13 | Blockiert bekannte destruktive `Bash`-Kommandos vor Ausfuehrung deterministisch mit Exit-Code 2 |
| Self-Improve-Loop | aktiv | 2026-03 | Policy-gated Multi-Iteration mit Rollback + Circuit-Breaker |
| Threshold-SSoT (`memory-thresholds.sh`) | aktiv | 2026-07 | Eine Definition aller Skalierungs-Schwellen; exit 10 bei Ueberschreitung (bootstrap, wrap-up, maintenance) |
| Salience-Ranking (`learnings_top.py`) | aktiv | 2026-07 | Deterministisches Learnings-Ranking fuer den Bootstrap-Fallback statt Full-Read |
| Identity-Growth (Queues + Gates) | aktiv | 2026-07 | wrap-up Step 6 (Producer, Pflicht-Statuszeile) + bootstrap Step 6.5 ([j/n]-Gates) |
| Knowledge-Skill obsidian-sync | aktiv | 2026-03 | Write-Path ins Obsidian-Wiki |
| Quality-Gate | entfernt | v4.0.0 | Skill + Agent entfernt — Review/TDD via User-Level-Skills + Test-Suite |
| research-pipeline / wiki-query / retrospective | entfernt | v4.0.0 | User-Level-Tools bzw. Report ohne Konsumenten |

Status-Werte: `aktiv`, `experimentell`, `geplant`, `deprecated`, `entfernt`

## Profile / Modi

- **Standalone:** nur `.agent-memory/`, ohne Wiki/NotebookLM.
- **Wiki-verbunden:** `config.json` mit `sync_enabled` → obsidian-sync + Wiki-ADR-Writeback aktiv.

## Skills (5)

Core: session-bootstrap, wrap-up, context-keeper. Analysis: pattern-extractor (inkl. Skill-Candidate-Generation). Knowledge: obsidian-sync.

Zu Commands mit Skript-Kern gemacht in v5.0.0: memory-maintenance → maintain, iteration-logger → log, sync-context → sync-context. Archiviert in v5.0.0 (`_archived/`): self-improve. Entfernt in v4.0.0: retrospective, research-pipeline, wiki-query, quality-gate, skill-generator (gefaltet in pattern-extractor).

## Agents (1)

context-detective. (improvement-agent, research-agent entfernt 4.15.0; quality-gate v4.0.0.)

## Commands (6)

init, status, memory-audit, maintain, log, sync-context. (rollback, auto-commit archiviert v5.0.0; log, patterns, research, sync, run-loop entfernt in v4.0.0 — `log` kehrt als echter Command mit Skript-Kern zurueck, nicht als Wrapper.)

## Einschraenkungen

- Trigger-Phrasen in SKILL.md-Frontmatter MUESSEN Englisch sein (Tests erzwingen das).
- `session-bootstrap` ist strikt read-only.
- `PreToolUse` schuetzt nur Shell/Bash-Aufrufe; andere Tool-Gates bleiben Aufgabe der Claude-Code-Berechtigungen.
- Laufende Instanz aus Cache-Kopie — Repo-Edits nicht sofort wirksam.
- `project-context.md` ist Cache der Docs, nicht autoritativ (Docs = Source of Truth).
