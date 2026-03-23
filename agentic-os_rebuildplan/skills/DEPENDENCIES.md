# Skill Dependency Graph — Agentic OS v3.1

## Session Lifecycle (Execution Order)

```
SESSION START (SessionStart hook)
  │
  ▼
  session-bootstrap
  │  ├── reads: session-summary.md
  │  ├── reads: identity/soul.md, user.md
  │  ├── reads: patterns/patterns.md
  │  ├── reads: quality/quality-score.json
  │  └── health checks on JSON files
  │
  ▼
WORK PHASE (user-driven, not auto-triggered)
  │
  │  User fixes a bug ──────► iteration-logger
  │  User makes a decision ─► context-keeper
  │  User wants review ─────► code-reviewer
  │  User runs tests ───────► test-validator
  │  User wants TDD ────────► tdd
  │  Patterns accumulate ───► pattern-extractor
  │  Pattern → reusable ───► skill-generator
  │
  ▼
SESSION END (Stop hook + explicit wrap-up)
  │
  ▼
  wrap-up
  │  ├── updates: session-summary.md
  │  ├── appends: learnings/learnings.md
  │  ├── updates: identity/user.md (if recurring feedback)
  │  └── retroactive: iteration-log.md (if unlogged iterations)
```

## Dependency Matrix

| Skill | Reads From | Writes To |
|-------|-----------|-----------|
| session-bootstrap | All .agent-memory/ files | Nothing (read-only, except corrupt JSON recovery) |
| iteration-logger | errors.json (duplicate check) | errors.json, iteration-log.md |
| pattern-extractor | errors.json, patterns.json | patterns.json, patterns.md |
| context-keeper | decisions.json, project-context.md | decisions.json, project-context.md |
| code-reviewer | project-context.md, patterns.md | code-reviews.json, quality-score.json |
| test-validator | test-results.json | test-results.json, quality-score.json |
| tdd | — | Test files, source files |
| skill-generator | patterns.json | generated-skills/<name>/SKILL.md |
| wrap-up | session-summary.md, git | session-summary.md, learnings.md, user.md |

## Agents

| Agent | Used By | Purpose |
|-------|---------|---------|
| context-detective | init command | Auto-detect project stack from manifest files |

## Key Design Decisions

- **No PostToolUse hooks.** Skills are invoked by the agent based on CLAUDE.md rules
  or by user request, not by automatic hooks after every file edit.
- **No orchestrator skill.** The agent decides when to log, review, or test based
  on CLAUDE.md work rules and its own judgment.
- **No global memory sync.** Cross-project learning is deferred until there are
  3+ active projects with enough data to make sync valuable.
- **wrap-up replaces agent-handoff.** Both session-end and context-handoff are
  handled by the same skill.
