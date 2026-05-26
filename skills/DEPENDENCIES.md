# Skill Dependency Graph — Agentic OS v3

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
  ├── quality-gate (before commits, on request)
  │     ├── Mode 1: Code review → writes: quality/code-reviews.json, quality-score.json
  │     ├── Mode 2: Test validation → writes: quality/test-results.json, quality-score.json
  │     └── Mode 3: TDD enforcement → (no memory writes — uses test runner directly)
  │
  ├── pattern-extractor (every 5 iterations, on request)
  │     ├── reads: iterations/errors.json, iteration-log.md
  │     └── writes: patterns/patterns.json, patterns.md
  │
  ├── skill-generator (when pattern has skill_candidate=true)
  │     ├── reads: patterns/patterns.json
  │     └── writes: generated-skills/<name>/SKILL.md
  │
  ├── sync-context (manual only, on explicit request)
  │     └── reads/writes: local patterns ↔ global patterns
  │
  ├── research-pipeline (token-optimized external research)
  │     └── writes: research/<topic>-*.md
  │
  └── self-improve (scheduled/manual, all phases inline)
        ├── Phase 0: Setup (git check, baseline tests, state.json)
        ├── Phase 1: Research (local analysis, optional WebSearch/NotebookLM)
        ├── Phase 2: Analysis (pattern-extractor + direct skill analysis)
        ├── Phase 3: Improvement (TDD + git-checkpoint rollback)
        ├── Phase 4: Validation (tests + quality evaluation)
        ├── Circuit breaker (diminishing returns / rollback detection)
        ├── Meta-improve (1x per run, optional, targets self)
        ├── Schedule management (CronCreate/adaptive frequency)
        └── writes: improvements/iterations-*.md, state.json
  │
  ▼
SESSION END (SessionEnd hook — delegates to wrap-up)
  │
  ▼
  wrap-up
  │  ├── reads: iterations/iteration-log.md
  │  ├── calls: pattern-extractor (if 3+ new iterations)
  │  ├── updates: session-summary.md
  │  ├── updates: learnings/learnings.md
  │  ├── updates: identity/user.md (conditional, 3+ repeated signals)
  │  └── optional: memory maintenance (archiving, JSON integrity, pruning)
```

## Dependency Matrix

| Skill | Reads From | Writes To |
|-------|-----------|----------|
| session-bootstrap | session-summary.md, soul.md, user.md, project-context.md, patterns.md, quality-score.json, errors.json | (nothing — read-only) |
| iteration-logger | iteration-log.md, errors.json | iteration-log.md, errors.json |
| pattern-extractor | errors.json, iteration-log.md, patterns.json | patterns.json, patterns.md |
| context-keeper | project-context.md, decisions.json | project-context.md, decisions.json |
| quality-gate | project-context.md, patterns.md, test-results.json, code-reviews.json | code-reviews.json, test-results.json, quality-score.json |
| skill-generator | patterns.json | generated-skills/ |
| wrap-up | iteration-log.md, errors.json | session-summary.md, learnings.md, user.md; delegates maintenance to memory-maintenance |
| memory-maintenance | all .agent-memory/ files | archives/*, repaired JSON files, patterns.md regeneration via pattern-extractor |
| sync-context | local patterns, global patterns | local patterns, global patterns |
| research-pipeline | (external: Perplexity, NotebookLM) | research/<topic>-*.md |
| obsidian-sync | .agent-memory/ session results | ~/wiki/ session notes, entity pages, synthesis |
| wiki-query | ~/wiki/ pages (read-only) | (nothing — read-only lookup) |
| self-improve | improvements/state.json, skills/*/SKILL.md, .agent-memory/* | improvements/iterations-*.md, state.json, skills/*/SKILL.md |

## Agents

| Agent | Used By | Purpose |
|-------|---------|---------|
| context-detective | /agentic-os:init (optional) | Auto-detect project stack from manifests |
| quality-gate | pre-commit, manual, self-improve | Combined code review + test validation |
| improvement-agent | self-improve (inline iterations) | Run single iteration (research→analysis→improvement→validation) |
| research-agent | self-improve research phase (optional) | Deep web + NotebookLM research |

## Consolidated Skills (v3)

Previously 20 skills, now 10 core + 3 auxiliary:

| # | Skill | Absorbed / Note |
|---|-------|----------|
| 1 | session-bootstrap | — |
| 2 | iteration-logger | — |
| 3 | pattern-extractor | — |
| 4 | context-keeper | — |
| 5 | quality-gate | code-reviewer, test-validator, tdd |
| 6 | self-improve | loop-orchestrator, research-phase, analysis-phase, improvement-phase, validation-phase, meta-improve, schedule-manager |
| 7 | wrap-up | — (memory maintenance split out in v3.1) |
| 8 | memory-maintenance | extracted from wrap-up Step 9 in v3.1 — owns JSON integrity, archiving, pruning, reporting |
| 9 | skill-generator | — |
| 10 | sync-context | — |

Auxiliary: `research-pipeline` (external research tool), `obsidian-sync` (write-path into wiki), `wiki-query` (read-only lookup in wiki).

## Key Design Principles

1. **No circular dependencies** — DAG only
2. **No auto-triggers on code changes** — user/CLAUDE.md driven
3. **session-bootstrap is read-only** — never writes during startup
4. **wrap-up and self-improve are the only skills that call other skills/agents**
5. **sync-context is manual-only** — no auto-sync
6. **self-improve has all phases inline** — no external skill delegation for pipeline steps
7. **P9 safety: git revert over git stash pop** — stash may already be dropped
8. **Max 20% mutation per skill per iteration** — prevents scope creep
9. **Circuit breaker stops on diminishing returns** — adaptive scheduling built into self-improve
