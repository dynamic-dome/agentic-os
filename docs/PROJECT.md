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

v3.8.0, aktiv. 14 Skills (core + quality + knowledge + self-improve), 4 Agents, 10 Slash-Commands, 5 Lifecycle-Hooks. **v3.8.0:** self-improve `lever 6` (eval-driven acceptance gate — binäres Eval-Set pro Skill, Rollback bei EVAL-REGRESSION unabhängig vom Test-Ergebnis) + neuer 14. Skill `retrospective` (Multi-Session-Trend-Metriken/Health-Grade, read-only über den Store, in wrap-up Step 10 eingehängt). **v3.7.0:** Skill-Datenfluss-Fixes (skill-generator kanonische Pattern-Felder, obsidian-sync importance-Gate) + PreToolUse Shell-Circuit-Breaker. **v3.6.0 (Session-Bracket-Coverage):** Die Zwei-Aufruf-Klammer (bootstrap → wrap-up) ist jetzt selbstversorgend — wrap-up Step 1.5 `(session-harvest)` retro-loggt die Iterationen der Session via iteration-logger, wenn mid-session nie `/log` lief (vorher verhungerte die Kette iteration-logger → pattern-extractor → skill-generator), und Step 4.5 `(decision-scan)` delegiert erkannte Architektur-Entscheidungen an context-keeper. Bewusst on-demand bleiben: quality-gate (voll), sync-context, self-improve, research-pipeline, wiki-query (siehe DEPENDENCIES.md "Session-Bracket Coverage"). Dazu Bugfix sharepoint-pull-check.ps1 (NULL-Array bei Frontmatter-losen Handoff-Dateien). **v3.5.1:** Wrapper-Commands `/wrap-up` + `/quality-gate` entfernt — ein Command mit Skill-Namen beschattet den Skill im Skill-Tool (Invoke-Loop, L17); beide Namen treffen jetzt direkt den Skill, ein Guard-Test verbietet künftige Schatten. **Handoff-Ownership (v3.5.0):** Next Steps leben projekt-lokal in `context/open-tasks.json` (SSoT, wrap-up Step 5.5); der zentrale Handoff haelt max. 1 Block pro Projekt und verweist statt zu kopieren (nur `[cross-project]`-Punkte inline). Das `.agent-memory/`-Schema ist seit v3.2.0 in einer Single Source of Truth (`scripts/mem-schema.sh`) definiert, von Hook UND `/init` konsumiert. Cross-Project-Handoff (zentral + Status-Board) seit v3.1.8. **Global Memory Layer 4.A (v3.4.0):** der globale Store (`~/.claude-memory/global/`) ist provenance-grounded (`G-<type>-<n>`, scope, lifecycle), promotet selektiv (Gate: conf≥0.6 ∧ occ≥3 ∧ ≥2 Projekte), altert (Decay −0.1/90d, Floor 0.3) und filtert Privacy (Denylist vor Push). Pure Logik in `scripts/global-schema.sh`. **v3.4.1:** Migration coerced qualitative Confidence (`low`/`medium`/`high`) statt zu crashen. Test-Suite gruen: 185 + 165 + 19.

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
