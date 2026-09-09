# CONSUMERS — agentic-os

Wer ausserhalb dieses Repos Skills, Commands, Skripte oder das Store-Layout von
`agentic-os` benutzt. **Bei Breaking Changes diese Konsumenten pruefen.**

> Stand 2026-09-09 (V7-Hygiene, Gesamtanalyse F8). Ermittelt per Grep ueber
> `~/Desktop/Claude-Plugins-Skills/*` und `~/AI/*`; die Tabelle von 2026-04-30
> listete `research-pipeline` und `quality-gate`, beide seit 4.0.0 entfernt.

## Aktive Konsumenten

| Konsument | Nutzt | Kopplung |
|---|---|---|
| `agentic-workflow-suite/hooks/workflow-wrap-up.py` | `agentic-os:wrap-up` (Empfehlung/Aufruf am Session-Ende) | Skill-Name |
| `agentic-memory/skills/memory-bootstrap/SKILL.md` | `agentic-os:session-start` (Hook-Briefing) | Hook-Name + Briefing-Format |
| `crazy-professor` | schreibt `<projekt>/.agent-memory/lab/crazy-professor/`, liest `session-summary.md` | Store-Layout |
| `~/AI/membrain` (`scripts/`, `eval/`, mem*-Dokumente) | `apply_wrapup.py`, `bridge_projection.py`, `memory_index_projection.py`, `review_sweep.py`, `measure_session_cost.py` als CLI | Skript-CLI + Exit-Codes |
| `agent-memory-atlas` (Daemon, `codex_native`-Adapter) | liest `learnings.json`, `decisions.json`, `open-tasks.json`, `patterns.json` aller Stores | JSON-Schema der Stores |
| Codex (jedes Projekt) | `AGENTS.md`-Managed-Block aus `bridge_projection.py` | Block-Marker `bridge:agentic-os` |
| Claude Auto-Memory (jedes Projekt) | `MEMORY.md`-Managed-Block aus `memory_index_projection.py` | Block-Marker `bridge:claude-native` |

## Haengende Referenzen (Owner-TODO in den jeweiligen Plugins)

- `dome-loop/commands/dome-discover.md`, `dome-evaluate.md` und `devil-advocate-swarms`
  (`CLAUDE.md`, `README.md`, `skills/research-pipeline/SKILL.md`) referenzieren
  `agentic-os:research-pipeline` — seit 4.0.0 nicht mehr vorhanden.

## Effektive Public-API

Skills `session-bootstrap`, `wrap-up`, `context-keeper`, `pattern-extractor`, `obsidian-sync`;
Commands `maintain`, `log`, `sync-context`, `init`, `status`, `memory-audit`; die Skript-CLIs
oben; das Store-Schema in `scripts/mem-schema.sh`; die beiden Managed-Block-Marker.
Aenderungen daran → CHANGELOG + VERSIONING (MAJOR bei Entfall).
