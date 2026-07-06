# Project Context

*Last updated: 2026-06-12*
*Source: docs/ (PROJECT.md) + .claude-plugin/plugin.json + CLAUDE.md. This file is a cache — docs win on drift.*

## Project
agentic-os — Claude-Code-Plugin fuer selbst-verbesserndes Agent-Gedaechtnis (`.agent-memory/`).

## Tech Stack
- **Language:** Markdown (skills/agents/commands), JSON (config/state), Bash (hooks/tests)
- **Framework:** Claude Code Plugin System v2
- **Package Manager:** none (keine Runtime-Deps)
- **Repository:** https://github.com/dynamic-dome/agentic-os.git

## Architecture
- Memory-Store `.agent-memory/` mit Schema-SSoT (`scripts/mem-schema.sh`), seit v3.2.0 von Hook + /init konsumiert
- 13 Skills (core/quality/knowledge/self-improve), 4 Agents, 10 Commands, 5 Lifecycle-Hooks (v3.5.1: /wrap-up + /quality-gate Wrapper geloescht — Command darf keinen Skill-Namen beschatten, L17-Guard-Test)
- Session-Bracket-Coverage (v3.6.0, D-001): bootstrap+wrap-up = unterstuetzter Minimal-Workflow; wrap-up Step 1.5 (session-harvest → iteration-logger) + Step 4.5 (decision-scan → context-keeper); bewusst on-demand: quality-gate, sync-context, self-improve, research/wiki-query
- Handoff-Ownership (v3.5.0): open-tasks.json = projekt-lokale SSoT fuer Next Steps; zentraler Handoff max 1 Block/Projekt + Pointer statt Kopie
- DAG-Schreibordnung: ein schreibberechtigter Skill pro Store-Datei
- Cross-Project-Handoff (zentral, gestapelt/prepend) + Status-Board (seit v3.1.8)
- Memory Growth Engine (v3.3.0): user.md-Kandidaten-Queue + soul.md Stufe-B-[j/n]-Gate
- Global Memory Layer 4.A (v3.4.0): globaler Store `~/.claude-memory/global/` provenance-grounded (`G-<type>-<n>`, scope, lifecycle), Promotion-Gate (conf≥0.6 ∧ occ≥3 ∧ ≥2 Projekte), Decay (−0.1/90d, Floor 0.3), Privacy-Denylist vor Push; pure Logik in `scripts/global-schema.sh` (16 Unit-Tests)

## Key Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| Claude Code CLI | Plugin v2 | Laufzeitumgebung |
| Bash / Git Bash | — | Hooks + Tests (Windows-kompatibel) |

## Constraints
- Trigger-Phrasen in SKILL.md-Frontmatter MUESSEN Englisch sein (Tests erzwingen)
- session-bootstrap strikt read-only
- `.agent-memory/` von Git-Commits ausgeschlossen; decisions.json append-only
- Laufende Instanz aus Cache-Kopie — Repo-Edits erst nach Spiegelung/Update wirksam

## Current Status
- **Phase:** aktiv, v3.6.0 (released + deployt 2026-06-12; laufende Instanz noch 3.5.1-Cache bis Restart)
- **Priority:** v3.6.0 (Session-Bracket-Coverage, D-001) gebaut + deployt; v3.5.x live verifiziert; Promotion-Gate FERTIG + live aktiv (2026-06-04 ground-truth)
- Tests gruen: 185/185 (validate-plugin) + 165/165 (validate-skills) + 19/19 (test-global-schema)

## Open Questions
- Plugin laeuft aus Cache-Kopie — kuenftige Repo-Edits greifen erst nach Spiegelung/Marketplace-Update + Restart (L5). Aktueller Stand v3.4.0 ist geladen.
- Format-Konsistenz project-context.md ueber alle drei Init-Pfade (laufend)
- Restliches Regel-13-Skelett bei Architektur-Aenderungen pflegen
- Promotion-Gate ist FERTIG + live (2026-06-04 verifiziert): es "wartet" NICHT auf einen Schalt-Akt, sondern auf echte Evidenz (Pattern real >=3x in >=2 Projekten) aus normaler Projektarbeit. G-010/011 manuell zu promoten hieße occurrences fälschen → abgelehnt (L16).
- Vertagt: Eywa-Provenance/Decay-Engine erst sinnvoll bei 2. Projekt-Sync
