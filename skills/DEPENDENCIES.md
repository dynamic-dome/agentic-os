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
        ├── delegates to: loop-orchestrator
        │     ├── spawns: improvement-agent (per iteration)
        │     │     ├── calls: research-phase (NotebookLM RAG + web fallback)
        │     │     ├── calls: analysis-phase (pattern-extractor + direct analysis)
        │     │     ├── calls: improvement-phase (TDD + git-stash safety)
        │     │     └── calls: validation-phase (tests + NotebookLM eval)
        │     ├── calls: schedule-manager (on convergence)
        │     └── calls: meta-improve (1x per run, optional)
        ├── calls: improvement-scout (legacy analysis agent)
        ├── calls: fix-reviewer (legacy validation agent)
        ├── calls: quality-gate (code checks)
        └── writes: improvements/iterations-*.md, state.json
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
| self-improve | improvements/state.json | improvements/iterations-*.md, state.json |
| loop-orchestrator | improvements/state.json, skills/*/SKILL.md | improvements/state.json |
| research-phase | .agent-memory/research-cache.json, patterns.json, session-summary.md | research-cache.json |
| analysis-phase | iteration-log.md, errors.json, skills/*/SKILL.md | (output only) |
| improvement-phase | skills/*/SKILL.md, tests/ | skills/*/SKILL.md, tests/validate-skills.sh |
| validation-phase | tests/ | improvements/iterations-*.md, state.json |
| meta-improve | improvements/state.json | improvements/state.json (metaHistory) |
| schedule-manager | improvements/state.json | (MCP scheduled tasks) |

## Agents

| Agent | Used By | Purpose |
|-------|---------|---------|
| context-detective | /agentic-os:init (optional) | Auto-detect project stack from manifests |
| quality-gate | pre-commit, manual, self-improve | Combined code review + test validation |
| improvement-scout | self-improve (legacy path) | Analyze plugin for actionable improvements |
| fix-reviewer | self-improve (legacy path) | Validate proposed fixes before implementation |
| improvement-agent | loop-orchestrator | Run single iteration (research→analysis→improvement→validation) |
| research-agent | research-phase (optional) | Deep web + NotebookLM research |

## Key Design Principles

1. **No circular dependencies** — DAG only
2. **No auto-triggers on code changes** — user/CLAUDE.md driven
3. **session-bootstrap is read-only** — never writes during startup
4. **wrap-up, self-improve, and loop-orchestrator are the only skills that call other skills/agents**
5. **sync-context is manual-only** — no auto-sync
6. **loop-orchestrator uses explicit delegation contracts** — all phase inputs/outputs documented
7. **P9 safety: git revert over git stash pop** — stash may already be dropped
8. **Max 20% mutation per skill per iteration** — prevents scope creep
9. **Circuit breaker stops on diminishing returns** — adaptive scheduling via schedule-manager
