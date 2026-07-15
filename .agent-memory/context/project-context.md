# Project Context

*Last updated: 2026-07-15 (v4.7.0 Modell-Routing; docs/PROJECT.md hinkt nach — siehe Open Questions)*
*Source: docs/ (PROJECT.md, ARCHITECTURE.md, CAPABILITIES.md) + CLAUDE.md + Git-Ground-Truth. This file is a cache — docs win on drift.*

## Project
agentic-os — Claude-Code-Plugin fuer selbst-verbesserndes Agent-Gedaechtnis (`.agent-memory/`).

## Tech Stack
- **Language:** Markdown (skills/agents/commands), JSON (config/state), Bash (hooks/tests/SSoT-Skripte inkl. model-routing.sh + cost-trace.sh), Python (learnings_top.py, posttooluse-dirty-tracker.py, preprocess_state.py)
- **Framework:** Claude Code Plugin System v2
- **Package Manager:** none (keine Runtime-Deps); Tests via `bash tests/run-all.sh`
- **Repository:** https://github.com/dynamic-dome/agentic-os.git

## Architecture
Seit v4.7.0: kosten-/tokenbewusstes Modell-Routing — Routine-Skills (wrap-up, session-bootstrap, memory-maintenance, iteration-logger, sync-context, obsidian-sync) laufen per model:/effort:-Frontmatter auf sonnet (Klassen-SSoT scripts/model-routing.sh, D-004/D-005); Stufe-0-Preflight preprocess_state.py, Eskalation via working/escalations-<sid>.json, Kostentrace metrics/cost-trace.jsonl.

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
