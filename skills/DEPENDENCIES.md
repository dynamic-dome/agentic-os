# Skill Dependency Graph — Agentic OS v3

## Session Lifecycle (Execution Order)

```
SESSION START
  │
  ▼
  heartbeat ──────────► soul-and-identity (read mode)
  │                     session-bootstrap
  │                       ├── reads: session-summary.md
  │                       ├── reads: patterns.md
  │                       └── calls: sync-context (pull)
  │
  ▼
WORK PHASE (repeating)
  │
  PostToolUse (Write|Edit)
  │
  ▼
  agent-orchestrator
  │  ├── code-changed ──► code-reviewer
  │  │                    test-validator
  │  ├── error-fixed ───► iteration-logger
  │  ├── decision-made ► (context logging)
  │  ├── pattern-threshold ► pattern-extractor
  │  └── skill-candidate ► skill-generator
  │
  ▼
SESSION END (Stop hook)
  │
  ▼
  wrap-up
  │  ├── calls: pattern-extractor
  │  ├── updates: soul-and-identity (user.md)
  │  ├── calls: sync-context (push)
  │  └── updates: session-summary.md
  │
  ▼
PreCompact (if triggered)
  │
  ▼
  agent-handoff
```

## Dependency Matrix

| Skill | Depends On | Depended By |
|-------|-----------|-------------|
| heartbeat | soul-and-identity, session-bootstrap | (entry point) |
| session-bootstrap | sync-context | heartbeat |
| soul-and-identity | — | heartbeat, wrap-up, agent-handoff |
| agent-orchestrator | trigger-rules.json | (PostToolUse hook) |
| code-reviewer | project-context.md, patterns.md | agent-orchestrator |
| test-validator | — | agent-orchestrator |
| iteration-logger | — | agent-orchestrator, wrap-up |
| pattern-extractor | errors.json, iteration-log.md | agent-orchestrator, wrap-up |
| skill-generator | patterns.json | pattern-extractor (via orchestrator) |
| sync-context | patterns.json, global memory | session-bootstrap, wrap-up |
| wrap-up | pattern-extractor, sync-context, soul-and-identity | Stop hook |
| agent-handoff | session-summary.md, quality-score.json | PreCompact hook |
| retrospective | all quality/*.json, iterations/*.json | (manual/periodic) |
| mutation-engine | evals/*.json, benchmarks.json | (manual/periodic) |
| init-memory | — | /agentic-os:init command |

## Agents

| Agent | Used By | Depends On |
|-------|---------|-----------|
| context-detective | init command | project manifests |
| memory-keeper | background tasks | .agent-memory/* |

## Circular Dependency Note

`heartbeat → session-bootstrap → sync-context` and `wrap-up → sync-context` form a DAG, not a cycle.
The potential concern is `sync-context` pulling patterns that reference `session-bootstrap`, but this is data-level, not execution-level.
