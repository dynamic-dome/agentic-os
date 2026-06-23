# Faehigkeiten — Agentic OS

## Tools & Integrationen

| Tool / Feature | Status | Seit | Beschreibung |
|----------------|--------|------|--------------|
| Memory-Store (`.agent-memory/`) | aktiv | 2026-03 | Persistentes Agent-Gedaechtnis, ein Schreiber pro Datei (DAG) |
| Schema SSoT (`mem-schema.sh`) | aktiv | 2026-06-01 | Eine Definition der Store-Struktur, von Hook + /init genutzt |
| Cross-Project-Handoff | aktiv | 2026-06-01 | Zentraler gestapelter Handoff (prepend) + Status-Board |
| PreToolUse Shell-Circuit-Breaker | aktiv | 2026-06-13 | Blockiert bekannte destruktive `Bash`-Kommandos vor Ausfuehrung deterministisch mit Exit-Code 2 |
| Self-Improve-Loop | aktiv | 2026-03 | Policy-gated Multi-Iteration mit Rollback + Circuit-Breaker |
| Quality-Gate | aktiv | 2026-03 | Code-Review + Test-Validation + TDD in einem Skill |
| Knowledge-Skills | aktiv | 2026-03 | research-pipeline, wiki-query, obsidian-sync |

Status-Werte: `aktiv`, `experimentell`, `geplant`, `deprecated`, `entfernt`

## Profile / Modi

- **Standalone:** nur `.agent-memory/`, ohne Wiki/NotebookLM.
- **Wiki-verbunden:** `config.json` mit `sync_enabled` → obsidian-sync + wiki-query + Wiki-ADR-Writeback aktiv.

## Skills (14)

Core: session-bootstrap, iteration-logger, pattern-extractor, context-keeper, wrap-up, skill-generator, sync-context, memory-maintenance.
Quality: quality-gate, retrospective. Self-improve: self-improve. Knowledge: research-pipeline, wiki-query, obsidian-sync.

## Agents (4)

context-detective, improvement-agent, quality-gate, research-agent.

## Einschraenkungen

- Trigger-Phrasen in SKILL.md-Frontmatter MUESSEN Englisch sein (Tests erzwingen das).
- `session-bootstrap` ist strikt read-only.
- `PreToolUse` schuetzt nur Shell/Bash-Aufrufe; andere Tool-Gates bleiben Aufgabe der Claude-Code-Berechtigungen.
- Laufende Instanz aus Cache-Kopie — Repo-Edits nicht sofort wirksam.
- `project-context.md` ist Cache der Docs, nicht autoritativ (Docs = Source of Truth).
