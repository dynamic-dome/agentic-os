# Agentic OS v3.1 — Claude Code Plugin

Persistent agent memory system for project work. Bootstraps `.agent-memory/` to track iterations, decisions, quality metrics, and learned patterns. 10 skills across 3 layers, invoked on-demand by the agent based on work context, not auto-triggered.

## Architecture: 3 Layers, 10 Skills

**Orchestration Layer** (session lifecycle)
- `session-bootstrap`: Load session context from `.agent-memory/` at start
- `wrap-up`: Update session summary and learnings at end

**Core Layer** (work logging and pattern learning)
- `iteration-logger`: Log completed code work (bugs, features, refactors)
- `context-keeper`: Track project decisions in append-only decisions.json
- `pattern-extractor`: Identify recurring patterns from iteration history
- `skill-generator`: Create reusable skills from validated patterns

**Quality Layer** (review and validation)
- `code-reviewer`: Review code against patterns; update quality-score.json
- `test-validator`: Run tests and log results; update quality metrics
- `tdd`: Test-driven development workflow (red → green → refactor)

## Hooks: 2 Events

| Hook | Behavior |
|------|----------|
| `SessionStart` | Load `.agent-memory/session-summary.md` and identity silently. Only report warnings (declining scores, unresolved patterns, thresholds exceeded). |
| `Stop` | If meaningful work was done: update session-summary.md (overwrite, ~30 lines) and backlog unlogged iterations to iteration-log.md. |

## Commands

| Command | Purpose |
|---------|---------|
| `/agentic-os:init` | Bootstrap `.agent-memory/` structure in current project |
| `/agentic-os:status` | Show current memory state and quality metrics |

## Setup

Install as a Claude Code plugin:
```bash
# In Claude Code settings, add this plugin path
plugins: ["path/to/agentic-os"]
```

On first run, use `/agentic-os:init` to create `.agent-memory/` structure.

## .agent-memory/ Directory Structure

```
.agent-memory/
├── session-summary.md          # Current session state, open items, next steps
├── iteration-log.md            # Append-only log of code work (bugs, features, refactors)
├── identity/
│   ├── soul.md                 # Agent behavior rules and identity
│   └── user.md                 # User profile and preferences
├── patterns/
│   ├── patterns.json           # Detected patterns with confidence scores
│   └── patterns.md             # Human-readable pattern summary
├── context/
│   ├── project-context.md      # Project stack, file layout, conventions
│   └── decisions.json          # Append-only decision log
└── quality/
    ├── quality-score.json      # Overall and per-dimension scores (0-100)
    ├── code-reviews.json       # Code review results
    └── test-results.json       # Test execution history
```

## Key Design Decisions

- **No auto-triggers**: Skills are invoked by agent judgment or user request, not by PostToolUse hooks. Avoids redundant runs and respects agent autonomy.
- **Append-only decisions.json**: Decisions are never overwritten. Preserves project history and reasoning.
- **File ownership per skill**: Each skill owns specific files (e.g., iteration-logger writes iteration-log.md; context-keeper writes decisions.json). Prevents conflicts.
- **Quality scoring**: Code and test results feed a unified 0-100 quality score; drives pattern confidence and skill prioritization.
- **Session-driven wrap-up**: One skill (wrap-up) handles both session-end summarization and retroactive iteration logging. Replaces agent-handoff complexity.

See `skills/DEPENDENCIES.md` for full skill dependency graph and execution order.
