# .agent-memory/ Structure Reference

Complete directory and file structure created by `/agentic-os:init`.

```
.agent-memory/
├── session-summary.md                  # Last session summary (≤30 lines)
│
├── identity/
│   ├── soul.md                         # Agent behavior, priorities, forbidden actions
│   └── user.md                         # User profile, preferences, error patterns
│
├── heartbeat/
│   ├── skill-registry.json             # Discovered skills with status
│   ├── context-matrix.json             # Token budget per context section
│   └── heartbeat-log.md               # Health check history
│
├── orchestrator/
│   ├── trigger-rules.json              # Auto-trigger configuration
│   └── orchestrator-log.md            # Orchestrator action history
│
├── iterations/
│   ├── iteration-log.md               # Chronological iteration entries
│   └── errors.json                    # Structured error records []
│
├── patterns/
│   ├── patterns.md                    # Human-readable pattern catalog
│   └── patterns.json                  # Machine-readable patterns []
│
├── context/
│   ├── project-context.md             # Tech stack, architecture, constraints
│   └── decisions.json                 # Architecture decisions []
│
├── quality/
│   ├── test-results.json              # Test run history []
│   ├── code-reviews.json              # Code review history []
│   └── quality-score.json             # Aggregated quality metrics
│
├── learnings/
│   ├── learnings.md                   # Session learnings
│   └── skill-feedback.json            # Skill effectiveness feedback []
│
├── generated-skills/                   # Auto-generated skills from patterns
│   └── <skill-name>/
│       └── SKILL.md
│
├── retrospectives/
│   ├── metrics.json                   # Aggregated long-term metrics
│   └── retro-<YYYY-MM-DD>.md         # Individual retrospective reports
│
├── evolution/
│   ├── evals/
│   │   └── <skill-name>.eval.json     # Binary eval criteria per skill
│   ├── mutations/
│   │   └── <skill-name>/
│   │       ├── mutation-log.json      # Mutation history
│   │       ├── v<n>-backup.md         # Skill backups
│   │       └── failed/               # Failed mutations as research assets
│   └── benchmarks.json               # Aggregated benchmark scores
│
└── transfer/
    ├── handoff-briefing.md            # Context for next session/agent
    ├── exportable-patterns.json       # Patterns marked for cross-project sharing
    └── agent-profiles/                # Exportable agent configurations
```

## Global Memory (~/.claude-memory/global/)

```
~/.claude-memory/global/
├── patterns.json          # Cross-project patterns (deduplicated)
├── learnings.json         # Generalizable learnings
├── projects.json          # Registry of initialized projects
└── agent-profile.json     # Accumulated user work style
```

## JSON Defaults

| File | Default Value |
|------|--------------|
| `errors.json` | `[]` |
| `patterns.json` | `[]` |
| `decisions.json` | `[]` |
| `test-results.json` | `[]` |
| `code-reviews.json` | `[]` |
| `skill-feedback.json` | `[]` |
| `benchmarks.json` | `{"skills": {}}` |
| `metrics.json` | `{"last_updated": null, "health_grade": "N/A"}` |
| `quality-score.json` | `{"last_updated": null, "test_health": {"current_score": null, "trend": "unknown"}, "code_quality": {"current_score": null, "trend": "unknown"}}` |
