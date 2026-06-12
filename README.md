# Agentic OS v3 — Claude Code Plugin

Self-improving agent memory system that works across any project.

## Features

- **Project Memory** (`.agent-memory/`): Per-project knowledge — iterations, patterns, decisions, quality scores
- **Session Lifecycle**: Auto-bootstrap at start, user-driven during work, auto-wrap-up at end
- **Lean Hook Surface**: 6 hooks with one deterministic `PreToolUse` Bash circuit breaker plus 5 lifecycle hooks
- **Wiki / Knowledge Layer**: `wiki-query` + `obsidian-sync` skills bridge into Obsidian / NotebookLM stores
- **Optional Cross-Project Sync**: Manual pattern sharing via `sync-context` skill

## Commands

| Command | Description |
|---------|-------------|
| `/agentic-os:init` | Bootstrap `.agent-memory/` in current project |
| `/agentic-os:status` | Show memory system health |
| `/agentic-os:run-loop` | Run the self-improvement loop manually |
| `/agentic-os:rollback` | Roll back the last self-improve commit |
| `/agentic-os:auto-commit` | Stage + commit current changes (used by self-improve) |

## Skills (13)

| # | Skill | Layer | Purpose |
|---|-------|-------|---------|
| 1 | `session-bootstrap` | core | Restores context at session start, health checks, briefing |
| 2 | `iteration-logger` | core | Logs features/bugfixes/refactors with duplicate detection |
| 3 | `pattern-extractor` | core | Extracts recurring patterns from iteration history |
| 4 | `context-keeper` | core | Maintains project context and architecture decisions |
| 5 | `wrap-up` | core | Session end: summary, learnings, handoff context |
| 6 | `skill-generator` | core | Generates new skills from confirmed patterns |
| 7 | `sync-context` | core | Manual cross-project pattern sync (optional) |
| 8 | `memory-maintenance` | core | Compaction, archiving, integrity checks for `.agent-memory/` |
| 9 | `quality-gate` | quality | Combined code review + test validation + TDD enforcement (0–100 score) |
| 10 | `self-improve` | self-improve | 4-iteration improvement loop with circuit breaker, rollback, NotebookLM research |
| 11 | `research-pipeline` | knowledge | Token-optimized research via Perplexity → NotebookLM → Claude |
| 12 | `wiki-query` | knowledge | Mid-session lookup in the Obsidian wiki with authority-aware retrieval |
| 13 | `obsidian-sync` | knowledge | Writes session results into the Obsidian wiki (sessions, entities, patterns) |

See `skills/DEPENDENCIES.md` for the full dependency graph and consolidated skill structure.

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `context-detective` | sonnet | Auto-detect project context from repo analysis |
| `improvement-agent` | sonnet | Executes a single self-improvement iteration end-to-end |
| `quality-gate` | sonnet | Runs the quality-gate as a parallelizable subagent |
| `research-agent` | sonnet | Combines NotebookLM + web search for skill-improvement research |

(`improvement-scout` and `fix-reviewer` were deprecated and removed in 2026-04 — use `improvement-agent` and the inline validation phase of `self-improve` instead.)

## Hooks (6)

| Event | Timeout | Type | Action |
|-------|---------|------|--------|
| `PreToolUse` | 5s | command | Block dangerous Bash commands before execution with exit code `2` |
| `SessionStart` | 15s | command | Auto-init `.agent-memory/`, inject session-summary briefing |
| `UserPromptSubmit` | 10s | prompt | Advisory-only context hint |
| `PreCompact` | 15s | prompt | Emit survival summary before context compaction |
| `SessionEnd` | 15s | prompt | Task guard, delegate to wrap-up |
| `SubagentStop` | 10s | prompt | Suggest commit after `quality-gate`/`improvement-agent` runs |

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
Guard:  PreToolUse blocks dangerous Bash commands before execution (5s, command, exit 2)
Start:  SessionStart hook reads context silently (15s, command)
Work:   User-driven — log iterations, record decisions, review code
        UserPromptSubmit (10s) injects context-hints, advisory-only
        SubagentStop (10s) suggests commit after quality runs
        PreCompact (15s) emits survival summary if context fills
End:    SessionEnd hook (15s) delegates to wrap-up
```

No per-edit overhead. The only per-tool hook is a deterministic Bash safety circuit breaker. Skills are invoked by the user or via CLAUDE.md rules.

## Shell Circuit Breaker

`PreToolUse` runs `scripts/pre-tool-use-circuit-breaker.sh` for Bash tool calls. It reads the Claude Code hook JSON from stdin and exits `2` when a command matches a dangerous shell pattern, which prevents the tool call from running. Safe commands exit `0` without output.

Blocked classes include recursive force deletes (`rm -rf`, PowerShell `Remove-Item -Recurse -Force`, `rmdir /s /q`), destructive Git history/worktree operations (`git reset --hard`, `git clean -fd/-xdf`, forced pushes), broad permission/ownership changes (`chmod 777`, `chown -R`), filesystem formatting, raw block-device writes, and download-to-shell pipes.

## Design Principles

1. **Lean hook surface** — 1 deterministic safety gate + 5 lifecycle hooks
2. **User-driven** — no auto-triggers on every edit
3. **Read-only bootstrap** — `session-bootstrap` never writes
4. **Append-only decisions** — `decisions.json` is never deleted, only superseded
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
