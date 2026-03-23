# .agent-memory/ Structure Reference

Complete directory and file structure created by `/agentic-os:init`.

```
.agent-memory/
├── session-summary.md                  # Last session summary (≤30 lines)
│
├── identity/
│   ├── soul.md                         # Agent behavior, priorities, guard rails
│   └── user.md                         # User profile, preferences, error patterns
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
│   └── learnings.md                   # Session learnings (append-only)
│
└── generated-skills/                   # Auto-generated skills from patterns
    └── <skill-name>/
        └── SKILL.md
```

## JSON Defaults

| File | Default Value |
|------|--------------|
| `errors.json` | `[]` |
| `patterns.json` | `[]` |
| `decisions.json` | `[]` |
| `test-results.json` | `[]` |
| `code-reviews.json` | `[]` |
| `quality-score.json` | `{"last_updated": null, "test_health": {"score": null, "trend": "unknown"}, "code_quality": {"score": null, "trend": "unknown"}}` |

## File Ownership

Each file has exactly one skill that writes to it (except session-summary.md):

| File | Written By | Notes |
|------|-----------|-------|
| `soul.md` | init command | Manual edits welcome |
| `user.md` | wrap-up | Recurring feedback section |
| `errors.json` | iteration-logger | Append-only |
| `iteration-log.md` | iteration-logger, wrap-up (retroactive) | Append-only |
| `patterns.json` | pattern-extractor | Create/update |
| `patterns.md` | pattern-extractor | Overwrite |
| `project-context.md` | context-keeper, init command | In-place update |
| `decisions.json` | context-keeper | Append-only |
| `test-results.json` | test-validator | Append |
| `code-reviews.json` | code-reviewer | Append |
| `quality-score.json` | code-reviewer, test-validator | Overwrite |
| `learnings.md` | wrap-up | Append-only |
| `session-summary.md` | wrap-up, Stop hook | Overwrite (snapshot) |
