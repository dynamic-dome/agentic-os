# Agentic OS v2 — Claude Code Plugin

Self-improving agent memory system that works across any project.

## Features

- **Project Memory** (`.agent-memory/`): Per-project knowledge — iterations, patterns, decisions, quality scores
- **Session Lifecycle**: Auto-bootstrap at start, user-driven during work, auto-wrap-up at end
- **Minimal Overhead**: 2 hooks, 45s total per session, no per-edit triggers
- **Optional Cross-Project Sync**: Manual pattern sharing via sync-context skill

## Commands

| Command | Description |
|---------|-------------|
| `/agentic-os:init` | Bootstrap `.agent-memory/` in current project |
| `/agentic-os:status` | Show memory system health |

## Skills (10)

| # | Skill | Layer | Purpose |
|---|-------|-------|---------|
| 1 | `session-bootstrap` | core | Restores context at session start, health checks, briefing |
| 2 | `iteration-logger` | core | Logs features/bugfixes/refactors with duplicate detection |
| 3 | `pattern-extractor` | core | Extracts recurring patterns from iteration history |
| 4 | `context-keeper` | core | Maintains project context and architecture decisions |
| 5 | `wrap-up` | core | Session end: summary, learnings, handoff context |
| 6 | `skill-generator` | core | Generates new skills from confirmed patterns |
| 7 | `sync-context` | core | Manual cross-project pattern sync (optional) |
| 8 | `code-reviewer` | quality | 6-dimension code quality review (0-100 score) |
| 9 | `test-validator` | quality | Test execution, health scoring, regression detection |
| 10 | `tdd` | quality | Red-Green-Refactor cycle enforcement |

See `skills/DEPENDENCIES.md` for the full dependency graph.

## Agent

| Agent | Model | Role |
|-------|-------|------|
| `context-detective` | sonnet | Auto-detect project context from repo analysis |

## Hooks

| Event | Timeout | Action |
|-------|---------|--------|
| `SessionStart` | 15s | Read session-summary + soul.md, report warnings only |
| `Stop` | 30s | Update session-summary, log unlogged iterations |

## Memory Structure

```
.agent-memory/
├── session-summary.md
├── identity/          soul.md, user.md
├── context/           project-context.md, decisions.json
├── iterations/        iteration-log.md, errors.json
├── patterns/          patterns.md, patterns.json
├── quality/           test-results.json, code-reviews.json, quality-score.json
├── learnings/         learnings.md
└── generated-skills/
```

## Session Lifecycle

```
Start:  SessionStart hook reads context silently (15s)
Work:   User-driven — log iterations, record decisions, review code
End:    Stop hook updates session-summary (30s)
```

No per-edit overhead. No auto-triggers on code changes. Skills are invoked by the user or via CLAUDE.md rules.

## Design Principles

1. **Minimal overhead** — 2 hooks, 45s total per session
2. **User-driven** — no auto-triggers on every edit
3. **Read-only bootstrap** — session-bootstrap never writes
4. **Append-only decisions** — decisions.json is never deleted, only superseded
5. **Genuine learnings only** — no trivial facts in the knowledge base

## References

- `references/memory-structure.md` — Complete `.agent-memory/` directory reference
- `references/skill-template.md` — Template for creating new skills
- `skills/DEPENDENCIES.md` — Skill dependency graph

## Installation

Add to your Claude Code settings:
```json
{
  "plugins": ["path/to/agentic-os-plugin"]
}
```
