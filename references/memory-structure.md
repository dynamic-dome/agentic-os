# .agent-memory/ Structure Reference

Complete directory and file structure created by `/agentic-os:init`.

```
.agent-memory/
├── session-summary.md                  # Last session summary (max 30 lines)
│
├── identity/
│   ├── soul.md                         # Agent behavior, priorities, guard rails
│   └── user.md                         # User profile, preferences, corrections
│
├── context/
│   ├── project-context.md              # Tech stack, architecture, constraints
│   └── decisions.json                  # Architecture decisions (append-only)
│
├── iterations/
│   ├── iteration-log.md                # Chronological iteration entries
│   └── errors.json                     # Structured error records
│
├── patterns/
│   ├── patterns.md                     # Human-readable pattern catalog
│   └── patterns.json                   # Machine-readable patterns
│
├── quality/
│   ├── test-results.json               # Test run history
│   ├── code-reviews.json               # Code review history
│   └── quality-score.json              # Aggregated quality metrics
│
├── knowledge/
│   └── notebook-registry.md            # NotebookLM KB registry (topics, keywords)
│
├── learnings/
│   └── learnings.md                    # Session learnings (genuine insights only)
│
└── generated-skills/                    # Auto-generated skills from patterns
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
| `quality-score.json` | `{"last_updated": null, "test_health": {"current_score": null, "trend": "unknown"}, "code_quality": {"current_score": null, "trend": "unknown"}}` |

## Log Rotation Thresholds

| File | Threshold | Action |
|------|-----------|--------|
| `iteration-log.md` | 500 entries | Archive to `iteration-log-archive-{YYYY-MM}.md` |
| `errors.json` | 200 entries | Archive to `errors-archive-{YYYY-MM}.json` |
| `code-reviews.json` | 100 entries | Archive to `code-reviews-archive-{YYYY-MM}.json` |
| `test-results.json` | 100 entries | Archive to `test-results-archive-{YYYY-MM}.json` |
