# Agentic OS v4 — Claude Code Plugin

Self-improving agent memory system that works across any project.

## Features

- **Project Memory** (`.agent-memory/`): Per-project knowledge — iterations, patterns, decisions, learnings
- **Identity Growth**: wrap-up harvests user/agent traits into gated candidate queues (`user.md`, `soul-candidates.md`); bootstrap surfaces them via explicit `[j/n]` gates — mandatory status line, no silent starvation
- **Session Lifecycle**: Auto-bootstrap at start, user-driven during work, wrap-up at end (the two-skill bracket is the supported minimal workflow)
- **Lean Hook Surface**: 7 hooks (SessionStart, PreToolUse, PostToolUse, UserPromptSubmit, PreCompact, SessionEnd, SubagentStop); the only per-edit hook is the mechanical fail-soft dirty-tracker (no LLM, bookkeeping only)
- **Wiki / Knowledge Layer**: `obsidian-sync` writes session results into the Obsidian wiki
- **Optional Cross-Project Sync**: Manual pattern sharing via `sync-context` skill

## Commands

| Command | Description |
|---------|-------------|
| `/agentic-os:init` | Bootstrap `.agent-memory/` in current project |
| `/agentic-os:status` | Show memory system health |
| `/agentic-os:rollback` | Roll back the last self-improve commit |
| `/agentic-os:auto-commit` | Stage + commit current changes (used by self-improve) |
| `/agentic-os:memory-audit` | Read-only drift/provenance/staleness report over `.agent-memory/` |

## Skills (9)

| # | Skill | Layer | Purpose |
|---|-------|-------|---------|
| 1 | `session-bootstrap` | core | Restores context at session start, health checks, briefing, identity gates |
| 2 | `iteration-logger` | core | Logs features/bugfixes/refactors with duplicate detection |
| 3 | `pattern-extractor` | core | Extracts recurring patterns; generates skills from confirmed skill candidates |
| 4 | `context-keeper` | core | Maintains project context and architecture decisions |
| 5 | `wrap-up` | core | Session end: summary, learnings, identity growth, handoff |
| 6 | `sync-context` | core | Manual cross-project pattern sync (optional) |
| 7 | `memory-maintenance` | core | Compaction, archiving, integrity checks for `.agent-memory/` |
| 8 | `self-improve` | self-improve | 4-iteration improvement loop with circuit breaker, rollback, NotebookLM research |
| 9 | `obsidian-sync` | knowledge | Writes session results into the Obsidian wiki (sessions, entities, patterns) |

Removed in v4.0.0 (never exercised or externally duplicated): `quality-gate`,
`retrospective`, `research-pipeline`, `wiki-query`, `skill-generator` (folded into
pattern-extractor). See `skills/DEPENDENCIES.md` for the dependency graph.

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `context-detective` | sonnet | Auto-detect project context from repo analysis |

## Hooks (6)

| Event | Timeout | Type | Action |
|-------|---------|------|--------|
| `SessionStart` | 15s | command | Auto-init `.agent-memory/`, inject briefing + soul/user identity extract, dirty-recovery check |
| `PreToolUse` | 5s | command | Deterministic shell circuit breaker for dangerous `Bash` commands; blocks with exit code 2 |
| `PostToolUse` | 5s | command | Dirty-state tracker: records un-consolidated work per session in `working/dirty-<sid>.json` (fail-soft, mechanical) |
| `UserPromptSubmit` | 10s | prompt | Advisory-only context hint (short) |
| `PreCompact` | 15s | prompt | Emit survival summary before context compaction |
| `SessionEnd` | 15s | prompt | Task guard, delegate to wrap-up, identity + wiki-note verify |

## Memory Structure

```
.agent-memory/
├── session-summary.md
├── identity/          soul.md, user.md, soul-candidates.md, user-changelog.json
├── context/           project-context.md, decisions.json, open-tasks.json
├── iterations/        iteration-log.md, errors.json
├── patterns/          patterns.md, patterns.json
├── learnings/         learnings.md, learnings.json
├── working/           current-session.json, user-candidates.json
└── generated-skills/
```

Scaling thresholds live ONLY in `scripts/memory-thresholds.sh` (exit 10 = exceeded) —
shared by wrap-up, session-bootstrap, and memory-maintenance.

## Long-Term Memory Routine

After each substantial task or session, run `wrap-up` to consolidate the work into
the central `.agent-memory/` knowledge base. The routine preserves durable facts
instead of leaving them only in chat: `iteration-logger` records distinct work
iterations in `.agent-memory/iterations/iteration-log.md`, `wrap-up` extracts
genuine reusable learnings into `.agent-memory/learnings/learnings.json`,
`context-keeper` records durable decisions in
`.agent-memory/context/decisions.json`, open next steps stay in
`.agent-memory/context/open-tasks.json`, and the handoff snapshot is refreshed in
`.agent-memory/session-summary.md`.

## Session Lifecycle

```
Start:  SessionStart hook reads context silently (15s, command)
Work:   User-driven — log iterations, record decisions
        PreToolUse (5s) blocks destructive Bash commands with exit code 2
        UserPromptSubmit (10s) injects context-hints, advisory-only
        PreCompact (15s) emits survival summary if context fills
End:    SessionEnd hook (15s) delegates to wrap-up (incl. identity growth)
```

No LLM-triggering per-edit overhead. The single per-edit hook (dirty-tracker) is pure
mechanical bookkeeping (<50ms, fail-soft, exit 0 always) so crashed sessions become
recoverable. Skills are invoked by the user or via CLAUDE.md rules.

## Design Principles

1. **Lean hook surface** — 7 hooks, total budget ≤ 70s per session plus only-on-shell PreToolUse checks and the mechanical per-edit dirty-tracker
2. **User-driven** — no LLM auto-triggers on every edit; per-edit work is limited to mechanical dirty-state bookkeeping
3. **Read-only bootstrap** — `session-bootstrap` never writes (single exception: the user-confirmed `[j/n]` identity gates)
4. **Append-only decisions** — `decisions.json` is never deleted, only superseded
5. **Genuine learnings only** — no trivial facts in the knowledge base
6. **Identity growth is visible** — wrap-up must emit its `Identity:` status line every run

## References

- `references/memory-structure.md` — Complete `.agent-memory/` directory reference
- `references/skill-template.md` — Template for creating new skills
- `skills/wrap-up/references/handoff-template.md` — Central handoff template + prepend algorithm (SSoT)
- `skills/DEPENDENCIES.md` — Skill dependency graph

## Installation

Add to your Claude Code settings:
```json
{
  "plugins": ["path/to/agentic-os-plugin"]
}
```
