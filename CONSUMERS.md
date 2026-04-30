# CONSUMERS — agentic-os

Plugins, die Skills aus diesem Plugin (`agentic-os`) extern aufrufen oder konsumieren.
**Bei Breaking Changes diese Konsumenten warnen** — die hier gelisteten Skill-Namen und
Outputs sind effektive Public-API der Plugin-Memory-Schicht.

> Stand 2026-04-30. Pflege-Hinweis: bei jeder Aenderung an Skills, die hier gelistet
> sind (Frontmatter, Trigger, Output-Format, gelesene/geschriebene Memory-Dateien),
> diese Tabelle als Pflichtchecks durchgehen.

## Konsumenten

### `dome-loop` — Discover-Phase

| Aspekt | Wert |
|---|---|
| Aufgerufener Skill | `agentic-os:research-pipeline` |
| Wo aufgerufen | `dome-loop/skills/dome-loop/SKILL.md` Phase D + `dome-loop/docs/ARCHITECTURE.md` |
| Kopplung | **weich** (Konsument hat dokumentierten manuellen Fallback) |
| Erwartetes Verhalten | Token-optimierte Pipeline Perplexity → NotebookLM → Claude, Output passt in `research-brief.md` |
| Fallback wenn nicht installiert | manuelles Paste der Perplexity-Antwort |
| Bei Breaking Change warnen? | JA — Output-Format aenderung wuerde dome-loop-Templates brechen |

### `devil-advocate-swarms` — Research-Workflow

| Aspekt | Wert |
|---|---|
| Aufgerufener Skill | `agentic-os:research-pipeline` (via Alias `devil-advocate-swarms:research-pipeline`, Option-2-Redirect) |
| Wo aufgerufen | `devil-advocate-swarms/CLAUDE.md` "Research-Workflow (Standard)"-Sektion |
| Kopplung | **weich** (Alias matcht nicht ohne explizite Skill-Invokation, fallback ist canonical-Aufruf) |
| Bei Breaking Change warnen? | JA |

### `multi-model-orchestrator` (Repo `inception-sandbox/`) — Research-Workflow

| Aspekt | Wert |
|---|---|
| Aufgerufener Skill | `agentic-os:research-pipeline` (via Alias `multi-model-orchestrator:research-pipeline`, Option-2-Redirect) |
| Wo aufgerufen | `inception-sandbox/CLAUDE.md` "Research-Workflow (Standard)"-Sektion |
| Kopplung | **weich** (Alias matcht nicht ohne explizite Skill-Invokation) |
| Bei Breaking Change warnen? | JA |

### `crazy-professor` — Session-Output Konsumption (`--from-session` Flag)

| Aspekt | Wert |
|---|---|
| Konsumierte Datei | `.agent-memory/session-summary.md` (Output von `agentic-os:wrap-up`) |
| Wo konsumiert | `crazy-professor/skills/crazy-professor/SKILL.md` (`--from-session`-Flag-Logik) |
| Kopplung | **weich** (read-only File-Konsumption, optional via Flag, robust gegen fehlende Datei) |
| Erwartetes Format | Markdown mit Sektion "Was wurde getan" oder gleichwertigen Abschnitten — crazy-professor liest das als Themen-Pool fuer Provokationen |
| Bei Breaking Change warnen? | JA — wenn `wrap-up` das Format der `session-summary.md` strukturell aendert (z.B. JSON statt MD oder andere Pflicht-Sektionen), crazy-professor `--from-session` gleichfalls anpassen |

### `agent-orchestrator-plugin` — Quality Gate (Phase 4)

| Aspekt | Wert |
|---|---|
| Aufgerufener Skill | `agentic-os:quality-gate` (Binary-Acceptance-Variante) |
| Wo aufgerufen | `agent-orchestrator-plugin/skills/agent-orchestrator/SKILL.md` Phase 4 |
| Kopplung | **weich** (Fallback: inline Self-Critique mit Plateau-Kriterium) |
| Bei Breaking Change warnen? | JA — Acceptance-Format-Änderungen (binary vs score) würden Phase-4 brechen |

### `dome-loop` — Evaluate-Phase

| Aspekt | Wert |
|---|---|
| Aufgerufener Skill | `agentic-os:quality-gate` (alternativ `devil-advocate-swarms:swarm`) |
| Wo aufgerufen | `dome-loop/skills/dome-loop/SKILL.md` Phase E + `docs/ARCHITECTURE.md` |
| Kopplung | **weich** |

## Skills, die KEINE externen Konsumenten haben

- `skills/session-bootstrap/`, `skills/iteration-logger/`, `skills/pattern-extractor/`, `skills/context-keeper/`, `skills/skill-generator/`, `skills/sync-context/`, `skills/memory-maintenance/`, `skills/wiki-query/`, `skills/obsidian-sync/`, `skills/self-improve/` — Plugin-internal, frei iterierbar

## Aenderungs-Checkliste bei Breaking Changes

Wenn die folgenden Aspekte geaendert werden, vor dem Commit eine Issue/PR-Note in den Repos
der Konsumenten oeffnen:

1. Frontmatter-Trigger (z.B. `agentic-os:research-pipeline` bekommt neue Sub-Trigger oder
   verliert "research" als Match-Phrase) → Konsumenten-Aliase muessen ggf. nachziehen
2. Output-Format (`.agent-memory/session-summary.md`-Schema, `quality/code-reviews.json`-Schema, `research/<topic>-<date>.md`-Struktur)
3. Skill-Name selbst (Re-Naming bricht alle Konsumenten — bewusster Major-Bump)
4. NotebookLM-Pflicht-Wechsel (User-CLAUDE.md mandates notebooklm-py CLI; ein Wechsel zur Plugin-MCP-Variante würde Konsumenten zwingen, ihre eigenen Erwartungen anzupassen)

## Pflichtfelder, die Konsumenten lesen

| Skill | Output-Datei | Was Konsumenten dort erwarten |
|---|---|---|
| `wrap-up` | `.agent-memory/session-summary.md` | Markdown mit klar erkennbaren "Was wurde getan"-Abschnitten — von crazy-professor `--from-session` gelesen |
| `research-pipeline` | `research/<topic>-<date>.md` | Markdown mit den Sektionen Question/Findings/Sources/Open Questions — von dome-loop in `research-brief.md` gemappt |
| `quality-gate` | `.agent-memory/quality/code-reviews.json` | JSON mit `score`, `dimensions`, `issues` — von agent-orchestrator Phase 4 binary-mapped |

## Verwandte Dokumente

- `inception-sandbox/CONSUMERS.md` (komplementaer fuer multi-model-orchestrator)
- `wiki/concepts/skill-alias-pattern.md`
- `wiki/todos/2026-04-30-cross-plugin-contract-callouts.md` (Quelle dieser Datei)
