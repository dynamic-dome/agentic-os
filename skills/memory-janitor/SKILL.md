---
name: memory-janitor
description: >
  Automatic memory hygiene: archives old iterations, validates JSON integrity,
  removes stale patterns, enforces size limits, and compacts session summaries.
  Run periodically, at session end, or when memory files grow large.
  Trigger phrases: "clean memory", "memory cleanup", "archive old data",
  "memory health", "compact memory", "prune patterns", "memory maintenance".
user_invocable: true
metadata:
  author: agentic-os
  version: '1.0'
  part-of: agentic-os
  layer: maintenance
---

# Memory Janitor

Keeps `.agent-memory/` healthy and compact for long-term autonomous operation.

## When to Use

- Periodically (every 10+ iterations or weekly)
- When session-bootstrap reports scaling warnings
- When iteration-log.md exceeds 500 entries
- When errors.json exceeds 200 entries
- User says "clean memory", "memory maintenance"
- Optionally triggered by Stop hook when size thresholds are exceeded

## Step 1: Assess Memory Health

Read and measure all memory files:

```
Files to check:
  .agent-memory/iterations/iteration-log.md    → count ## headings
  .agent-memory/iterations/errors.json         → count array entries
  .agent-memory/patterns/patterns.json         → count array entries
  .agent-memory/quality/code-reviews.json      → count array entries
  .agent-memory/quality/test-results.json      → count array entries
  .agent-memory/context/decisions.json         → count array entries
  .agent-memory/session-summary.md             → count lines
  .agent-memory/learnings/learnings.md         → count lines
```

## Step 2: JSON Integrity Check

For each JSON file:
1. Attempt to parse it
2. If parse fails: rename to `{file}.corrupt.bak`, create fresh with default (`[]` or `{}`), warn user
3. If parse succeeds: check for structural issues (e.g. missing required fields in entries)

## Step 3: Archive Old Iterations

**Thresholds:**
- `iteration-log.md` > 500 entries → archive
- `errors.json` > 200 entries → archive
- `code-reviews.json` > 100 entries → archive

**Archive process:**
1. Read the file
2. Keep the newest N entries (500/200/100 respectively)
3. Write older entries to `{filename}-archive-{YYYY-MM}.{ext}` in the same directory
4. Overwrite the original with only the recent entries

Example:
```bash
# errors.json has 250 entries
# → Keep newest 200 in errors.json
# → Write oldest 50 to errors-archive-2026-03.json
```

## Step 4: Prune Stale Patterns

Read `.agent-memory/patterns/patterns.json`:

1. Find patterns where `last_seen` is older than 90 days
2. Find patterns with `confidence < 0.3`
3. Move these to `patterns-archive-{YYYY-MM}.json`
4. Remove them from `patterns.json`
5. Update `patterns.md` to reflect the pruned catalog

**Exception:** Never prune patterns with `skill_candidate: true` — these are valuable even if old.

## Step 5: Compact Decisions

Read `.agent-memory/context/decisions.json`:

1. Find decisions with `status: "superseded"` older than 90 days
2. Archive them to `decisions-archive-{YYYY-MM}.json`
3. Keep all `status: "active"` decisions regardless of age

## Step 6: Enforce Session Summary Length

Read `.agent-memory/session-summary.md`:
- If longer than 30 lines: compress to 30 lines
- Keep: date, what was done (max 5 bullets), open items (all), next steps (max 3)
- Remove: verbose descriptions, old handoff context from previous sessions

## Step 7: Compact Learnings

Read `.agent-memory/learnings/learnings.md`:
- If longer than 200 lines: keep only the last 12 months of entries
- Archive older entries to `learnings-archive-{YYYY}.md`
- Deduplicate: if two learnings say essentially the same thing, keep the newer one

## Step 8: Report

```
Memory Janitor Report:
  JSON Integrity: {n}/{total} valid ({n} repaired)
  Iterations archived: {n} entries → iteration-log-archive-{date}.md
  Errors archived: {n} entries → errors-archive-{date}.json
  Patterns pruned: {n} stale, {n} low-confidence
  Decisions archived: {n} superseded
  Session summary: {compacted|ok} ({n} lines)
  Learnings: {compacted|ok} ({n} lines)

  Current sizes:
  iteration-log.md:  {n} entries
  errors.json:       {n} entries
  patterns.json:     {n} entries
  code-reviews.json: {n} entries
  decisions.json:    {n} active
```

## What NOT to Do

- Do NOT delete open-tasks.json entries (that's the Task Persistence Guard's domain)
- Do NOT modify identity files (soul.md, user.md)
- Do NOT prune skill_candidate patterns
- Do NOT archive active decisions
- Do NOT run during an active self-improve loop (check state.json status first)
- Do NOT archive if no threshold is exceeded (report "all within limits" and exit)
