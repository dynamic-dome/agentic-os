# Skill Dependency Graph — Agentic OS v4

> Reflects v4.0.0. The local store schema is owned by `scripts/mem-schema.sh`
> (see `references/memory-structure.md`); the **global** layer's pure logic
> (provenance, promotion gate, decay, privacy denylist) lives in `scripts/global-schema.sh`.
> All scaling/archiving threshold NUMBERS live in `scripts/memory-thresholds.sh`
> (threshold SSoT — read by session-bootstrap Step 3, wrap-up Step 9, memory-maintenance Step 3).
> When this graph disagrees with a skill's own SKILL.md, the SKILL.md wins.

## Session Lifecycle (Execution Order)

```
SESSION START (SessionStart hook → session-bootstrap)
  │
  ▼
  session-bootstrap (READ-ONLY, one gated exception below)
  │  ├── cross-project (read-only): ~/AI/.agent-memory/session-summary.md,
  │  │     ~/AI/cross-project-status.md, ~/AI/SESSION-WORKFLOW.md (conditional)
  │  ├── local: session-summary.md, identity/soul.md, identity/user.md,
  │  │     context/project-context.md, patterns/patterns.md,
  │  │     quality/quality-score.json (legacy), iterations/errors.json (tail 3),
  │  │     working/current-session.json, context/open-tasks.json (SSoT for next steps)
  │  ├── learnings: RAG via Atlas MCP, fallback scripts/learnings_top.py
  │  │     (deterministic salience ranking — never full-reads learnings.json)
  │  ├── health: bash scripts/memory-thresholds.sh (exit 10 → THRESHOLD lines in briefing)
  │  ├── wiki (optional, if config.json sync_enabled): entity + entrypoints (≤5 pages)
  │  └── Step 6.5 IDENTITY GATES (consumer side of wrap-up Step 6):
  │        (a) soul-candidates.md → "[j/n]" gate — soul.md write ONLY on explicit `j`
  │        (b) user-candidates.json fallback promotion gate — also only on explicit `j`
  │        (c) starvation warning (read-only) when the identity pipeline is stale
  │
  ▼
WORK PHASE (user-driven, no auto-triggers on code changes)
  │
  ├── iteration-logger (after fixes/features)
  │     ├── reads: errors.json, iteration-log.md, working/current-session.json
  │     ├── writes: iteration-log.md, errors.json, working/current-session.json
  │     │     (append-only; rotation is memory-maintenance's job, thresholds in memory-thresholds.sh)
  │     └── suggests (no invoke): pattern-extractor every 5th iteration
  │
  ├── context-keeper (on architecture/stack decisions)
  │     ├── reads: docs/PROJECT.md+ARCHITECTURE.md+CAPABILITIES.md (SoT, Step 1.5),
  │     │     context/project-context.md, context/decisions.json, config.json
  │     ├── writes: context/project-context.md (cache), context/decisions.json
  │     └── writes (optional, Step 3.5 if sync_enabled): ~/wiki/wiki/entities/<id>.md
  │
  ├── pattern-extractor (every ~5 iterations, on request, "refresh" mode)
  │     ├── reads: errors.json, iteration-log.md, patterns.json
  │     ├── writes: patterns.json, patterns.md
  │     └── Step 6.5 SKILL CANDIDATE GENERATION (former skill-generator, folded in v4.0.0):
  │           pattern with skill_candidate=true, conf≥0.7, occ≥3 →
  │           writes generated-skills/<name>/SKILL.md + back-ref in patterns.json
  │
  ├── sync-context (MANUAL ONLY, explicit request)
  │     └── reads/writes: ~/.claude-memory/global/{patterns,learnings,projects}.json ↔ local
  │           (privacy pre-filter → promotion gate → provenance schema; pull serves lifecycle:active only)
  │
  ├── obsidian-sync (wiki write-path; also mid-session on request)
  │     └── see matrix — session notes, entity updates, synthesis, promotion_status
  │
  └── self-improve (scheduled/manual, all pipeline phases inline)
        ├── reads: improvements/state.json, skills/*/SKILL.md (Glob),
        │     patterns.json, iteration-log.md, errors.json, ARCHITECTURE.md
        ├── invokes: pattern-extractor (Phase 2.1, via Skill tool)
        ├── writes: skills/*/SKILL.md (Edit), research/research-cache.json,
        │     improvements/iterations-{batch_start:03d}-{batch_end:03d}.md,
        │     improvements/state.json, improvements/evals/*.eval.json (lever 6)
        ├── commits: git tags self-improve-<cluster>-<iter>-<ts>
        └── policy: single-cluster, no-self-mod, rollback-tagged, circuit breaker
  │
  ▼
SESSION END (SessionEnd hook → wrap-up)
  │
  ▼
  wrap-up (MANUAL-ONLY — the hook only *suggests* it)
  │  ├── reads: iteration-log.md, errors.json, learnings.json,
  │  │     working/current-session.json, working/user-candidates.json,
  │  │     context/open-tasks.json, skills/wrap-up/references/handoff-template.md
  │  ├── writes: session-summary.md, learnings.json + learnings.md,
  │  │     context/open-tasks.json (Step 5.5, SSoT for next steps),
  │  │     working/current-session.json (reset)
  │  ├── Step 1.5 → invokes iteration-logger (session-harvest: retro-logs the
  │  │     session's iterations when none were logged today)
  │  ├── Step 4   → invokes pattern-extractor (if 3+ new iterations)
  │  ├── Step 4.5 → invokes context-keeper (decision-scan: decisions of record)
  │  ├── Step 6   → IDENTITY GROWTH — the ONLY producer of identity observations:
  │  │     checklist harvest → working/user-candidates.json (queue) →
  │  │     FULL queue re-review (queue-re-review) → identity/user.md promotion
  │  │     (changelog-before-write) → identity/soul-candidates.md (direct +
  │  │     escalation-path; NEVER writes soul.md) → MANDATORY status line
  │  │     (identity-visible). Consumed by bootstrap Step 6.5 gates.
  │  ├── Step 7.5 → invokes obsidian-sync (gates: sync_enabled + substantiality;
  │  │     always reports — wiki-sync-visible)
  │  ├── Step 7.6 → writes cross-project: ~/AI/.agent-memory/session-summary.md
  │  │     (prepend handoff), ~/AI/cross-project-status.md, Sharepoint (optional)
  │  │     — templates + dedup rules in skills/wrap-up/references/handoff-template.md
  │  └── Step 9   → runs scripts/memory-thresholds.sh; exit 10 or explicit request
  │        → invokes memory-maintenance
```

## Dependency Matrix

| Skill | Reads From | Writes To | Invokes |
|-------|-----------|-----------|---------|
| session-bootstrap | local: session-summary.md, soul.md, user.md, soul-candidates.md, user-candidates.json, project-context.md, patterns.md, quality-score.json (legacy), errors.json (tail), working/current-session.json, context/open-tasks.json (SSoT for next steps), config.json · learnings via Atlas-RAG or `scripts/learnings_top.py` · health via `scripts/memory-thresholds.sh` · cross-project: ~/AI/.agent-memory/session-summary.md, cross-project-status.md, SESSION-WORKFLOW.md · wiki (optional): entity + entrypoints | (read-only) EXCEPT the user-confirmed identity gates in Step 6.5 → soul.md + user.md, user-changelog.json, soul-candidates.md / user-candidates.json (only on explicit `j`). Staleness display (`[STALE? …]`) is DISPLAY-ONLY, never a write. | — |
| iteration-logger | errors.json, iteration-log.md, working/current-session.json | iteration-log.md, errors.json, working/current-session.json (append-only — rotation belongs to memory-maintenance) | — (suggests pattern-extractor) |
| pattern-extractor | errors.json, iteration-log.md, patterns.json | patterns.json (sole creator/schema owner; authorized field-GAIN exceptions: obsidian-sync → promotion metadata, implementing/validating main session → implemented_by/validated_by + dates per Step 6.6), patterns.md, generated-skills/<name>/SKILL.md (Step 6.5 skill-candidate generation, former skill-generator), context/open-tasks.json (Step 6.6 delta-draft tasks; decisions route via context-keeper, never written directly) | context-keeper (Step 6.6 architecture-level delta drafts) |
| context-keeper | docs/PROJECT.md+ARCHITECTURE.md+CAPABILITIES.md (SoT), project-context.md, decisions.json, config.json | project-context.md (cache), decisions.json, ~/wiki/wiki/entities/<id>.md (optional) | — |
| wrap-up | iteration-log.md, errors.json, learnings.json, working/current-session.json, working/user-candidates.json, context/open-tasks.json, skills/wrap-up/references/handoff-template.md | session-summary.md, learnings.json + learnings.md, user.md (via queue promotion, changelog first), user-candidates.json (queue), user-changelog.json (audit), soul-candidates.md (propose — never soul.md), working/current-session.json (reset), context/open-tasks.json (Step 5.5 SSoT); cross-project handoff (max 1 block per project, next steps as pointer + `[cross-project]` only) + status-board + Sharepoint | iteration-logger (Step 1.5 session-harvest), pattern-extractor (Step 4, 3+ iters), context-keeper (Step 4.5 decision-scan), obsidian-sync (Step 7.5), memory-maintenance (Step 9, threshold-script exit 10 or explicit request) |
| memory-maintenance | all .agent-memory/ files, scripts/memory-thresholds.sh (threshold SSoT), improvements/state.json (precondition); Step 4b: global store + scripts/global-schema.sh (apply_decay) | archives/*, repaired JSON, compacted session-summary.md + learnings.md, working/ scratch cleanup (Step 3b — deletes stale *.py/*.tmp/*.bak, exempts current-session.json + user-candidates.json); global: decayed confidence + lifecycle:archived in ~/.claude-memory/global/* (never hard-delete) | pattern-extractor (patterns.md refresh) |
| sync-context | local patterns/learnings, ~/.claude-memory/global/*; scripts/global-schema.sh (is_denied, compute_scope, passes_promotion_gate) + scripts/mem-schema.sh (MEM_GLOBAL_DENY_TAGS) | local + ~/.claude-memory/global/{patterns,learnings,projects}.json with provenance schema (G-<type>-<n>, scope, valid_from, lifecycle); privacy-filter before gate; promotion gate; pull serves only lifecycle:active | — |
| obsidian-sync | config.json, session-summary.md, iteration-log.md, learnings.json/.md, patterns.json/.md, decisions.json, ~/wiki/{index.md,log.md,entities,synthesis} | ~/wiki/wiki/queries/*.md, ~/wiki/{index.md,log.md}, entity + synthesis (append), patterns.json (promotion_status + promotion_scope only) | — |
| self-improve | improvements/state.json, skills/*/SKILL.md, patterns.json, iteration-log.md, errors.json | skills/*/SKILL.md, research/research-cache.json, improvements/iterations-{batch_start:03d}-{batch_end:03d}.md, state.json, improvements/evals/*.eval.json (lever 6) | pattern-extractor (Phase 2.1) |

## Agents

| Agent | Used By | Reads / Writes | Purpose |
|-------|---------|----------------|---------|
| context-detective | /agentic-os:init (optional) | reads manifests + docs/ (docs-first); writes project-context.md | Auto-detect project stack |
| improvement-agent | self-improve (one per iteration) | invokes the self-improve skill; returns structured result | Run a single improvement iteration |
| research-agent | self-improve research phase (optional) | WebSearch/WebFetch; writes nothing (returns JSON) | Deep web + NotebookLM research |

## Skills (v4.0.0)

9 active skills, grouped by layer (see `references/skill-template.md` Layer Guide):

| Layer | Skills | Note |
|-------|--------|------|
| core | session-bootstrap, iteration-logger, pattern-extractor, context-keeper, wrap-up, sync-context, memory-maintenance | pattern-extractor absorbed skill-generator (Step 6.5) in v4.0.0 |
| knowledge | obsidian-sync | write-path to the Obsidian wiki |
| self-improve | self-improve | all pipeline phases inline, policy-gated |

### Removed in v4.0.0 (with reason)

- **retrospective** — trend metrics never drove a decision; the read-only report duplicated what /memory-audit + patterns.md already surface.
- **research-pipeline** — external research is better served by user-level skills (Perplexity/NotebookLM CLI); the plugin wrapper added indirection, not value.
- **wiki-query** — a plain wiki lookup needs no skill; the wiki MCP / direct Read covers it without a trigger-phrase surface.
- **quality-gate** (skill + agent) — review/test/TDD enforcement moved to user-level skills and the test suite itself; the in-plugin score pipeline had no consumer.
- **skill-generator** — not deleted but FOLDED into pattern-extractor Step 6.5 (single writer of patterns.json generates the skills its candidates describe).
- Wrapper commands **/log, /patterns, /research, /sync, /run-loop** — thin wrappers around directly-invocable skills (and shadow-risk, L17); 5 commands remain (init, status, rollback, auto-commit, memory-audit).

Removed agents (2026-04-30): `improvement-scout`, `fix-reviewer` → use `improvement-agent` + `self-improve`.

## Key Design Principles

1. **No circular dependencies** — DAG only.
2. **No auto-triggers on code changes** — user/CLAUDE.md driven (the only hook-driven skills are session-bootstrap on start and wrap-up on end).
3. **session-bootstrap is read-only** — never writes during startup, with ONE exception: the user-confirmed identity gates (Step 6.5) write soul.md/user.md + user-changelog.json + the queues, but only on an explicit `j` from the user (never autonomously).
4. **Skills that invoke other skills:** `wrap-up` (iteration-logger via session-harvest, pattern-extractor, context-keeper via decision-scan, obsidian-sync, memory-maintenance via the threshold script), `self-improve` (pattern-extractor), `memory-maintenance` (pattern-extractor). All other skills are leaf nodes.
5. **sync-context is manual-only** — no auto-sync.
6. **self-improve has all pipeline phases inline** — only pattern-extractor is delegated.
7. **P9 safety: git revert over git stash pop** — stash may already be dropped.
8. **Max 20% mutation per skill per iteration** — prevents scope creep.
9. **Circuit breaker stops on diminishing returns** — adaptive scheduling built into self-improve.
10. **docs/ is the source of truth for project-context.md** — context-keeper (and context-detective, /init) read docs first; project-context.md is a cache (Regel 13 / L9).
11. **Thresholds live in ONE script** — `scripts/memory-thresholds.sh` is the only place scaling numbers exist; skills reference it, never restate the numbers.
12. **Identity growth is producer/consumer split** — wrap-up Step 6 is the only PRODUCER of identity observations (queues + promotions + mandatory status line); session-bootstrap Step 6.5 is the CONSUMER (gates + starvation check). Nothing else touches identity files.

## Session-Bracket Coverage

The supported minimal workflow is the **two-call bracket**: `session-bootstrap` at start,
`wrap-up` at end, nothing in between. This table states what that bracket covers and what
stays deliberately on-demand:

| Covered by the bracket (automatic) | How |
|---|---|
| Context restore, health checks, salience learnings, wiki context, Sharepoint pull | bootstrap (learnings_top.py / Atlas-RAG, memory-thresholds.sh) |
| Auto-init, PreCompact survival, SessionEnd task guard, intent hints | hooks |
| Iteration logging | wrap-up Step 1.5 session-harvest → iteration-logger |
| Pattern extraction (incl. skill-candidate generation) | wrap-up Step 4 (3+ iterations, fed by harvest) → pattern-extractor |
| Decisions of record | wrap-up Step 4.5 decision-scan → context-keeper |
| Identity growth (user.md, soul candidates) + gates | wrap-up Step 6 (producer) + bootstrap Step 6.5 (consumer) |
| Learnings, open-tasks SSoT | wrap-up Steps 3-5.5 |
| Wiki sync, central handoff, status board, maintenance trigger | wrap-up Steps 7-9 (handoff-template.md, memory-thresholds.sh) |

| Deliberately on-demand (NOT in the bracket) | Why |
|---|---|
| sync-context | Design Principle 5: manual-only, no auto cross-project sync |
| self-improve | policy-gated (see Self-Improve Policy); never runs implicitly |
| obsidian-sync (manual mid-session) | reactive; the bracket already covers the end-of-session sync |
| memory-maintenance (full run) | threshold-gated via memory-thresholds.sh; not part of every wrap-up |
| /memory-audit, /rollback, /status | inspection/recovery commands |
