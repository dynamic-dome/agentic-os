# Agentic OS v3 — Claude Code Plugin

Self-improving agent memory system that works across any project.

## Features

- **Project Memory** (`.agent-memory/`): Per-project knowledge — iterations, patterns, decisions, quality scores
- **Global Memory** (`~/.claude-memory/global/`): Cross-project learnings, patterns, user profile
- **Session Lifecycle**: Auto-bootstrap at start, auto-log during work, auto-wrap-up at end
- **Cross-Project Sync**: Patterns learned in one project benefit all future projects
- **Self-Improvement**: Mutation engine optimizes skills via binary eval criteria

## Commands

| Command | Description |
|---------|-------------|
| `/agentic-os:init` | Bootstrap `.agent-memory/` in current project |
| `/agentic-os:sync` | Sync local ↔ global memory |
| `/agentic-os:status` | Show memory system health |

## Skills (15 across 6 layers)

| Layer | Skill | Trigger |
|-------|-------|---------|
| Identity | `soul-and-identity` | Setup, behavior feedback, new project |
| Orchestration | `heartbeat` | Session start (health check) |
| Orchestration | `agent-orchestrator` | After code changes (auto-trigger via PostToolUse hook) |
| Core | `init-memory` | Setting up memory in a new project |
| Core | `session-bootstrap` | Session start context loading |
| Core | `iteration-logger` | Logging completed work |
| Core | `pattern-extractor` | Finding recurring patterns in history |
| Core | `wrap-up` | Session end summary and sync |
| Core | `sync-context` | Cross-project pattern synchronization |
| Core | `skill-generator` | Create new skills from recurring patterns |
| Quality | `code-reviewer` | Code quality review (6 dimensions, 0-100 score) |
| Quality | `test-validator` | Test execution and health scoring |
| Quality | `retrospective` | Multi-session deep analysis |
| Evolution | `mutation-engine` | Autonomous skill optimization via binary evals |
| Transfer | `agent-handoff` | Context handoff before session/context switch |

See `skills/DEPENDENCIES.md` for the full dependency graph.

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `memory-keeper` | sonnet | Background memory maintenance |
| `context-detective` | sonnet | Auto-detect project context from repo analysis |

## Hooks

| Event | Action |
|-------|--------|
| `SessionStart` | Run heartbeat health check silently |
| `PostToolUse` (Write\|Edit) | Trigger orchestrator on code changes |
| `PreCompact` | Save context via agent-handoff before compression |
| `Stop` | Auto-log unlogged iterations, update session-summary |

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `global_memory_path` | `~/.claude-memory/global/` | Global memory location |
| `auto_heartbeat_on_start` | `true` | Auto-run heartbeat on session start |
| `auto_wrapup_on_stop` | `true` | Auto-run wrap-up on session end |
| `pattern_push_threshold` | `0.6` | Min confidence to push patterns globally |
| `pattern_pull_threshold` | `0.5` | Min confidence to pull patterns |
| `max_iterations_log_entries` | `500` | Max iteration entries before archiving |
| `agent_model` | `sonnet` | Model for background agents |
| `language` | `de` | Output language (de/en) |

## Architecture

```
Project A                    Global Store                    Project B
.agent-memory/    ──push──►  ~/.claude-memory/global/  ◄──push──  .agent-memory/
  patterns.json   ◄──pull──    patterns.json           ──pull──►  patterns.json
  learnings.md                 learnings.json                     learnings.md
  iterations/                  projects.json                      iterations/
  context/                     agent-profile.json                 context/
```

## References

- `references/memory-structure.md` — Complete `.agent-memory/` directory reference
- `references/skill-template.md` — Template for creating new skills
- `skills/DEPENDENCIES.md` — Skill dependency graph

## Known Limitations

- **Token Budget**: heartbeat uses 200k as context window estimate — may need adjustment for newer models
- **Handoff Versioning**: `handoff-briefing.md` is overwritten on each handoff without version history
- **Mutation Engine**: Worktree isolation for skill mutation testing is experimental and may not work in all environments
- **Windows Paths**: Global memory path `~/.claude-memory/global/` requires tilde expansion on Windows

## Installation

Add to your Claude Code settings:
```json
{
  "plugins": ["path/to/agentic-os-plugin"]
}
```
