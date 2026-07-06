# Project Context

*Last updated: 2026-07-06 (Refresh auf v4.0.1)*
*Source: docs/ (PROJECT.md, ARCHITECTURE.md, CAPABILITIES.md) + CLAUDE.md + Git-Ground-Truth. This file is a cache — docs win on drift.*

## Project
agentic-os — Claude-Code-Plugin fuer selbst-verbesserndes Agent-Gedaechtnis (`.agent-memory/`).

## Tech Stack
- **Language:** Markdown (skills/agents/commands), JSON (config/state), Bash (hooks/tests/SSoT-Skripte), Python (learnings_top.py)
- **Framework:** Claude Code Plugin System v2
- **Package Manager:** none (keine Runtime-Deps); Tests via `bash tests/run-all.sh`
- **Repository:** https://github.com/dynamic-dome/agentic-os.git

## Architecture
- Memory-Store `.agent-memory/` mit Schema-SSoT (`scripts/mem-schema.sh`, Hook + /init) und DAG-Schreibordnung: genau ein schreibberechtigter Skill pro Store-Datei
- **v4.0.0-Konsolidierung:** 9 Skills (core: session-bootstrap, iteration-logger, pattern-extractor inkl. Skill-Generation, context-keeper, wrap-up, sync-context, memory-maintenance; knowledge: obsidian-sync; self-improve), 3 Agents (context-detective, improvement-agent, research-agent), 5 Commands (init, status, rollback, auto-commit, memory-audit), 6 Hooks (inkl. PreToolUse Shell-Circuit-Breaker)
- **Identity-Growth gehaertet (v4.0.0):** wrap-up Step 6 = einziger Producer (Harvest-Checkliste, Full-Queue-Re-Review, Pflicht-Statuszeile `Identity: ...`, Eskalationspfad user→soul); bootstrap Step 6.5 = Consumer ([j/n]-Gates, Starvation-Warnung); user.md-Injektion im SessionStart
- **Threshold-SSoT** `scripts/memory-thresholds.sh` (alle Skalierungs-Schwellen, exit 10; konsumiert von bootstrap/wrap-up/maintenance) + **Salience-Ranking** `scripts/learnings_top.py` (Bootstrap-Fallback ohne Full-Read)
- Session-Bracket-Coverage (v3.6.0): bootstrap+wrap-up = selbstversorgende Zwei-Aufruf-Klammer (Step 1.5 session-harvest, Step 4.5 decision-scan)
- Handoff-Ownership (v3.5.0): open-tasks.json = projekt-lokale SSoT fuer Next Steps; zentraler Handoff max 1 Block/Projekt (Template-SSoT: `skills/wrap-up/references/handoff-template.md`)
- Global Memory Layer 4.A (v3.4.0): `~/.claude-memory/global/` provenance-grounded, Promotion-Gate (conf≥0.6 ∧ occ≥3 ∧ ≥2 Projekte), Decay, Privacy-Denylist (`scripts/global-schema.sh`)

## Key Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| Claude Code CLI | Plugin v2 | Laufzeitumgebung |
| Bash / Git Bash | — | Hooks + Tests (Windows-kompatibel) |
| Optional: NotebookLM CLI, Obsidian-Wiki | — | Knowledge-Skills (obsidian-sync, research-agent) |

## Constraints
- Trigger-Phrasen in SKILL.md-Frontmatter MUESSEN Englisch sein (Tests erzwingen)
- session-bootstrap strikt read-only (einzige Ausnahme: user-bestaetigter soul.md-Merge, Step 6.5a)
- `.agent-memory/` von Git-Commits ausgeschlossen; decisions.json append-only
- Kein Command darf einen Skill-Namen tragen (L17-Guard-Test)
- Laufende Instanz aus versionierter Cache-Kopie — Repo-Edits erst nach Marketplace-Update + Restart wirksam (L5)
- Self-improve policy-gated: single-cluster, no-self-mod, max 20% Mutation/Skill, git-revert statt stash-pop

## Current Status
- **Phase:** aktiv, **v4.0.1** (Verifier-Fixrunde 238c78e + Bump 319b1b2; Restart vollzogen 2026-07-06 — laufende Instanz nachweislich aus Cache 4.0.1, T-005 done)
- **Priority:** T-006 (save-session/session-summary-Deprecation, Owner-Entscheid) + T-007 (Identity-Pipeline 2-3 Sessions beobachten — Erfolgskriterium des v4.0.0-Kernfixes)
- Tests gruen (v4.0.x): 146 (validate-plugin) + 126 (validate-skills) + 19 (global-schema) + 17 (circuit-breaker) + contract

## Open Questions
- Docs-Drift: docs/PROJECT.md "Aktueller Stand" nennt noch v4.0.0 — 4.0.1-Fixrunde dort nachziehen (Regel-13-Pflege)
- Format-Konsistenz project-context.md ueber alle drei Init-Pfade (laufend)
- Promotion-Gate global: FERTIG + live, wartet auf echte Evidenz (Pattern ≥3x in ≥2 Projekten), nicht auf einen Schalt-Akt (L16)
- Vertagt: Eywa-Provenance/Decay-Engine erst sinnvoll bei 2. Projekt-Sync
