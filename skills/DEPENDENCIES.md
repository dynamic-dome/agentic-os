# Skill Dependency Graph — Agentic OS v3

> Reflects v3.4.0. The local store schema is owned by `scripts/mem-schema.sh`
> (see `references/memory-structure.md`); the **global** layer's pure logic
> (provenance, promotion gate, decay, privacy denylist) lives in `scripts/global-schema.sh`
> (4.A). When this graph disagrees with a skill's own SKILL.md, the SKILL.md wins.

## Session Lifecycle (Execution Order)

```
SESSION START (SessionStart hook → session-bootstrap)
  │
  ▼
  session-bootstrap (READ-ONLY)
  │  ├── cross-project (read-only): ~/AI/.agent-memory/session-summary.md,
  │  │     ~/AI/cross-project-status.md, ~/AI/SESSION-WORKFLOW.md (conditional)
  │  ├── local: session-summary.md, identity/soul.md, identity/user.md,
  │  │     context/project-context.md, patterns/patterns.md,
  │  │     learnings/learnings.json (salience), quality/quality-score.json,
  │  │     iterations/errors.json (tail 3), working/current-session.json
  │  └── wiki (optional, if config.json sync_enabled): entity + entrypoints (≤5 pages)
  │
  ▼
WORK PHASE (user-driven, no auto-triggers on code changes)
  │
  ├── iteration-logger (after fixes/features)
  │     ├── reads: errors.json, iteration-log.md, working/current-session.json
  │     ├── writes: iteration-log.md, errors.json, working/current-session.json
  │     ├── rotates: *-archive-{YYYY-MM} when over threshold
  │     └── suggests (no invoke): pattern-extractor every 5th iteration
  │
  ├── context-keeper (on architecture/stack decisions)
  │     ├── reads: docs/PROJECT.md+ARCHITECTURE.md+CAPABILITIES.md (SoT, Step 1.5),
  │     │     context/project-context.md, context/decisions.json, config.json
  │     ├── writes: context/project-context.md (cache), context/decisions.json
  │     └── writes (optional, Step 3.5 if sync_enabled): ~/wiki/wiki/entities/<id>.md
  │
  ├── quality-gate (before commits, on request)
  │     ├── reads: project-context.md, patterns.md, quality/*.json
  │     └── writes: code-reviews.json, test-results.json, quality-score.json
  │
  ├── pattern-extractor (every ~5 iterations, on request, "refresh" mode)
  │     ├── reads: errors.json, iteration-log.md, patterns.json
  │     └── writes: patterns.json, patterns.md
  │
  ├── skill-generator (when pattern has skill_candidate=true, conf≥0.5 occ≥2)
  │     ├── reads: patterns.json, errors.json
  │     └── writes: generated-skills/<name>/SKILL.md, patterns.json (back-ref);
  │           optional ~/.claude/skills/<name>/ (global install, on consent)
  │
  ├── sync-context (MANUAL ONLY, explicit request)
  │     └── reads/writes: ~/.claude-memory/global/{patterns,learnings,projects}.json ↔ local
  │
  ├── research-pipeline (token-optimized external research)
  │     └── writes: research/<topic>-*.md  (external: Perplexity, NotebookLM CLI)
  │
  ├── wiki-query (mid-session lookup, READ-ONLY by default)
  │     ├── reads: config.json, ~/wiki/ pages
  │     └── writes: ~/wiki/wiki/queries/ (only on explicit user consent)
  │
  └── self-improve (scheduled/manual, all pipeline phases inline)
        ├── reads: improvements/state.json, skills/*/SKILL.md (Glob),
        │     patterns.json, iteration-log.md, errors.json, ARCHITECTURE.md
        ├── invokes: pattern-extractor (Phase 2.1, via Skill tool)
        ├── writes: skills/*/SKILL.md (Edit), research/research-cache.json,
        │     improvements/iterations-*.md, improvements/state.json
        ├── commits: git tags self-improve-<cluster>-<iter>-<ts>
        └── policy: single-cluster, no-self-mod, rollback-tagged, circuit breaker
  │
  ▼
SESSION END (SessionEnd hook → wrap-up)
  │
  ▼
  wrap-up (MANUAL-ONLY — no hook auto-triggers it)
  │  ├── reads: iteration-log.md, errors.json, test-results.json,
  │  │     code-reviews.json, learnings.json, working/current-session.json
  │  ├── writes: session-summary.md, learnings.json + learnings.md,
  │  │     identity/user.md (conditional), working/current-session.json (reset)
  │  ├── Step 4   → invokes pattern-extractor (if 3+ new iterations)
  │  ├── Step 7.5 → invokes obsidian-sync (conditional: sync_enabled + threshold)
  │  ├── Step 7.6 → writes cross-project: ~/AI/.agent-memory/session-summary.md
  │  │     (prepend handoff), ~/AI/cross-project-status.md, Sharepoint (optional)
  │  └── Step 9   → invokes memory-maintenance (only on explicit request / threshold)
```

## Dependency Matrix

| Skill | Reads From | Writes To | Invokes |
|-------|-----------|-----------|---------|
| session-bootstrap | local: session-summary.md, soul.md, user.md, soul-candidates.md, project-context.md, patterns.md, learnings.json, quality-score.json, errors.json (tail), working/current-session.json, config.json · cross-project: ~/AI/.agent-memory/session-summary.md, cross-project-status.md, SESSION-WORKFLOW.md · wiki (optional): entity + entrypoints | (read-only) EXCEPT the user-confirmed soul.md write in Step 6.5 → soul.md, user-changelog.json, soul-candidates.md (only on explicit `j`). 4.A staleness-wrap is DISPLAY-ONLY (>90d → `[STALE? …]`), never a write. | — |
| iteration-logger | errors.json, iteration-log.md, working/current-session.json | iteration-log.md, errors.json, working/current-session.json, *-archive-{YYYY-MM} | — (suggests pattern-extractor) |
| pattern-extractor | errors.json, iteration-log.md, patterns.json | patterns.json, patterns.md | — |
| context-keeper | docs/PROJECT.md+ARCHITECTURE.md+CAPABILITIES.md (SoT), project-context.md, decisions.json, config.json | project-context.md (cache), decisions.json, ~/wiki/wiki/entities/<id>.md (optional) | — |
| quality-gate | project-context.md, patterns.md, test-results.json, code-reviews.json, quality-score.json | code-reviews.json, test-results.json, quality-score.json | — (pattern-extractor/context-keeper are in `depends-on` metadata but NOT invoked by the body) |
| skill-generator | patterns.json, errors.json | generated-skills/<name>/SKILL.md, patterns.json, ~/.claude/skills/ (optional) | — |
| wrap-up | iteration-log.md, errors.json, test-results.json, code-reviews.json, learnings.json, working/current-session.json, user-candidates.json | session-summary.md, learnings.json, learnings.md, user.md, user-candidates.json (queue), user-changelog.json (audit), soul-candidates.md (propose), working/current-session.json; cross-project handoff + status-board + Sharepoint | pattern-extractor (3+ iters), obsidian-sync (Step 7.5), memory-maintenance (on request) |
| memory-maintenance | all .agent-memory/ files, improvements/state.json (precondition); 4.A Step 4b: global store + scripts/global-schema.sh (apply_decay) | archives/*, repaired JSON, compacted session-summary.md + learnings.md; 4.A: decayed confidence + lifecycle:archived in ~/.claude-memory/global/* (never hard-delete) | pattern-extractor (patterns.md refresh) |
| sync-context | local patterns/learnings, ~/.claude-memory/global/*; 4.A: scripts/global-schema.sh (is_denied, compute_scope, passes_promotion_gate) + scripts/mem-schema.sh (MEM_GLOBAL_DENY_TAGS) | local + ~/.claude-memory/global/{patterns,learnings,projects}.json with 4.A provenance schema (G-<type>-<n>, scope, valid_from, lifecycle); privacy-filter before gate; promotion gate; pull serves only lifecycle:active | — |
| research-pipeline | (external: Perplexity, NotebookLM) | research/<topic>-*.md | — (external notebooklm CLI) |
| obsidian-sync | config.json, session-summary.md, iteration-log.md, learnings.json/.md, patterns.json/.md, decisions.json, ~/wiki/{index.md,log.md,entities,synthesis} | ~/wiki/wiki/queries/*.md, ~/wiki/{index.md,log.md}, entity + synthesis (append), **patterns.json (promotion_status only)** | — |
| wiki-query | config.json, ~/wiki/ pages (read-only) | ~/wiki/wiki/queries/ (only on explicit consent) | — |
| self-improve | improvements/state.json, skills/*/SKILL.md, patterns.json, iteration-log.md, errors.json | skills/*/SKILL.md, research/research-cache.json, improvements/iterations-*.md, state.json | pattern-extractor (Phase 2.1) |

## Agents

| Agent | Used By | Reads / Writes | Purpose |
|-------|---------|----------------|---------|
| context-detective | /agentic-os:init (optional) | reads manifests + docs/ (docs-first); writes project-context.md | Auto-detect project stack |
| improvement-agent | self-improve (one per iteration) | invokes the self-improve skill; returns structured result | Run a single improvement iteration |
| quality-gate (agent) | quality-gate skill, self-improve, manual | reads git diff; writes quality/*.json | Combined review + test validation (execution helper; distinct from the skill) |
| research-agent | self-improve research phase (optional) | WebSearch/WebFetch; writes nothing (returns JSON) | Deep web + NotebookLM research |

## Consolidated Skills (v3)

13 active skills, grouped by layer (see `references/skill-template.md` Layer Guide):

| Layer | Skills | Note |
|-------|--------|------|
| core | session-bootstrap, iteration-logger, pattern-extractor, context-keeper, wrap-up, skill-generator, sync-context, memory-maintenance | memory-maintenance split out of wrap-up in v3.1 |
| quality | quality-gate | absorbed code-reviewer + test-validator + tdd |
| knowledge | research-pipeline, wiki-query, obsidian-sync | external research + wiki read/write |
| self-improve | self-improve | absorbed loop-orchestrator, research/analysis/improvement/validation phases, meta-improve, schedule-manager |

Removed agents (2026-04-30): `improvement-scout`, `fix-reviewer` → use `improvement-agent` + `self-improve`.

## Key Design Principles

1. **No circular dependencies** — DAG only.
2. **No auto-triggers on code changes** — user/CLAUDE.md driven (the only hook-driven skills are session-bootstrap on start and wrap-up on end).
3. **session-bootstrap is read-only** — never writes during startup, with ONE exception: the user-confirmed soul.md candidate gate (Step 6.5) writes soul.md + user-changelog.json + soul-candidates.md, but only on an explicit `j` from the user (never autonomously).
4. **Skills that invoke other skills:** `wrap-up` (pattern-extractor, obsidian-sync, memory-maintenance), `self-improve` (pattern-extractor), `memory-maintenance` (pattern-extractor). All other skills are leaf nodes. (`quality-gate` lists pattern-extractor/context-keeper in its `depends-on` metadata, but its body does not invoke them — legacy, like self-improve's metadata.)
5. **sync-context is manual-only** — no auto-sync.
6. **self-improve has all pipeline phases inline** — only pattern-extractor is delegated; `iteration-logger`/`quality-gate` in its `depends-on` metadata are legacy and not invoked by the body.
7. **P9 safety: git revert over git stash pop** — stash may already be dropped.
8. **Max 20% mutation per skill per iteration** — prevents scope creep.
9. **Circuit breaker stops on diminishing returns** — adaptive scheduling built into self-improve.
10. **docs/ is the source of truth for project-context.md** — context-keeper (and context-detective, /init) read docs first; project-context.md is a cache (Regel 13 / L9).
