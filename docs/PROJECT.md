---
project: agentic-os
status: active
started: 2026-03
stack: [Markdown, JSON, Bash]
repo: https://github.com/dynamic-dome/agentic-os.git
wiki_entity: "[[agentic-os]]"
---
# Agentic OS

## Einzeiler

Ein Claude-Code-Plugin, das ein selbst-verbesserndes Agent-Gedaechtnis bereitstellt — Projektwissen, Muster und Qualitaets-Trends persistieren ueber Sessions hinweg in `.agent-memory/`.

## Aktueller Stand

v3.4.0, aktiv. 13 Skills (core + quality + knowledge + self-improve), 4 Agents, 12 Slash-Commands, 5 Lifecycle-Hooks. Das `.agent-memory/`-Schema ist seit v3.2.0 in einer Single Source of Truth (`scripts/mem-schema.sh`) definiert, von Hook UND `/init` konsumiert. Cross-Project-Handoff (zentral + Status-Board) seit v3.1.8. **Global Memory Layer 4.A (v3.4.0):** der globale Store (`~/.claude-memory/global/`) ist provenance-grounded (`G-<type>-<n>`, scope, lifecycle), promotet selektiv (Gate: conf≥0.6 ∧ occ≥3 ∧ ≥2 Projekte), altert (Decay −0.1/90d, Floor 0.3) und filtert Privacy (Denylist vor Push). Pure Logik in `scripts/global-schema.sh` (16 Unit-Tests). Test-Suite gruen: 185 + 161 + 16.

## Kernfaehigkeiten

Siehe [[CAPABILITIES.md]] fuer die vollstaendige Liste.

Kurzfassung:
- Session-Lifecycle: bootstrap (read-only) → arbeiten → wrap-up (Handoff + Learnings)
- Memory-Store `.agent-memory/`: ein schreibberechtigter Skill pro Datei (DAG)
- Selbst-Verbesserung: policy-gated Multi-Iteration-Loop mit Rollback
- Cross-Project-Handoff + projektuebergreifendes Status-Board

## Offene Baustellen

- [ ] Format-Konsistenz project-context.md ueber alle drei Init-Pfade (laufend)
- [ ] Plugin laeuft aus Cache-Kopie — Repo-Edits greifen erst nach Spiegelung/Marketplace-Update
- [ ] Restliches Regel-13-Skelett pflegen, wenn sich Architektur aendert

## Abhaengigkeiten

- Claude Code CLI (Plugin-System v2)
- Bash / Git Bash (Hooks, Tests) — Windows-kompatibel gehalten
- Optional: NotebookLM CLI, Obsidian-Wiki (~/wiki/) fuer Knowledge-Skills

## Beziehungen zu anderen Projekten

- Verwandt mit: `agentic-memory` (separates Plugin, native Memory-Bridge)
- Handoff-Ebene darueber: SESSION-WORKFLOW.md (~/AI) — Cross-Project-Mechanik
