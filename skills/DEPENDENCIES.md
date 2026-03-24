# Skill Dependency Graph — Agentic OS v2

## Session Lifecycle (Execution Order)

```
SESSION START (SessionStart hook)
  │
  ▼
  session-bootstrap (read-only)
  │  ├── reads: session-summary.md
  │  ├── reads: identity/soul.md, identity/user.md
  │  ├── reads: context/project-context.md
  │  ├── reads: patterns/patterns.md
  │  └── reads: quality/quality-score.json
  │
  ▼
WORK PHASE (user-driven, no auto-triggers)
  │
  ├── iteration-logger (after fixes/features)
  │     └── writes: iterations/iteration-log.md, errors.json
  │
  ├── context-keeper (on architecture decisions)
  │     └── writes: context/project-context.md, decisions.json
  │
  ├── code-reviewer (before commits, on request)
  │     └── writes: quality/code-reviews.json, quality-score.json
  │
  ├── test-validator (before commits, on request)
  │     └── writes: quality/test-results.json, quality-score.json
  │
  ├── pattern-extractor (every 5 iterations, on request)
  │     ├── reads: iterations/errors.json, iteration-log.md
  │     └── writes: patterns/patterns.json, patterns.md
  │
  ├── skill-generator (when pattern has skill_candidate=true)
  │     ├── reads: patterns/patterns.json
  │     └── writes: generated-skills/<name>/SKILL.md
  │
  ├── tdd (on feature/bugfix work)
  │     └── (no memory writes — uses test runner directly)
  │
  ├── sync-context (manual only, on explicit request)
  │     └── reads/writes: local patterns ↔ global patterns
  │
  └── self-improve (scheduled/manual, orchestrates improvement loop)
        ├── calls: improvement-scout (analysis)
        ├── calls: fix-reviewer (validation)
        ├── calls: quality-gate (code checks)
        └── writes: improvements/iterations-{batch}.md, state.json
  │
  ▼
SESSION END (Stop hook)
  │
  ▼
  wrap-up
  │  ├── reads: iterations/iteration-log.md
  │  ├── calls: pattern-extractor (if 3+ new iterations)
  │  ├── updates: session-summary.md
  │  ├── updates: learnings/learnings.md
  │  └── updates: identity/user.md (conditional, 3+ repeated signals)
```

## Dependency Matrix

| Skill | Reads From | Writes To |
|-------|-----------|----------|
| session-bootstrap | session-summary.md, soul.md, user.md, project-context.md, patterns.md, quality-score.json, errors.json | (nothing — read-only) |
| iteration-logger | iteration-log.md, errors.json | iteration-log.md, errors.json |
| pattern-extractor | errors.json, iteration-log.md, patterns.json | patterns.json, patterns.md |
| context-keeper | project-context.md, decisions.json | project-context.md, decisions.json |
| code-reviewer | project-context.md, patterns.md | code-reviews.json, quality-score.json |
| test-validator | test-results.json | test-results.json, quality-score.json |
| skill-generator | patterns.json | generated-skills/ |
| wrap-up | iteration-log.md, errors.json | session-summary.md, learnings.md, user.md |
| sync-context | local patterns, global patterns | local patterns, global patterns |
| tdd | — | — |
| self-improve | improvements/state.json, DEPENDENCIES.md | improvements/iterations-{batch}.md, state.json |

## Agents

| Agent | Used By | Purpose |
|-------|---------|---------|
| context-detective | /agentic-os:init | Auto-detect project stack from manifests |
| quality-gate | pre-commit, manual, self-improve | Combined code review + test validation |
| improvement-scout | self-improve | Analyze plugin for actionable improvements |
| fix-reviewer | self-improve | Validate proposed fixes before implementation |

## Key Design Principles

1. **No circular dependencies** — DAG only
2. **No auto-triggers on code changes** — user/CLAUDE.md driven
3. **session-bootstrap is read-only** — never writes during startup
4. **wrap-up and self-improve are the only skills that call other skills/agents**
5. **sync-context is manual-only** — no auto-sync
6. **self-improve calls agents, not skills** — avoids skill-level circular deps
