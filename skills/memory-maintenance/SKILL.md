---
name: memory-maintenance
description: |
  Periodically compacts, archives, and integrity-checks the `.agent-memory/`
  store — JSON validation, threshold-based archiving, stale-pattern pruning,
  session-summary length enforcement, and consistency checks. Runs on demand
  or when wrap-up detects exceeded thresholds. Never part of the normal
  end-of-session flow.
  Trigger phrases: "clean memory", "memory cleanup", "memory maintenance",
  "archive old data", "prune patterns", "memory health", "compact memory",
  "memory report", "integrity check memory", "Speicher aufraeumen",
  "Memory-Wartung", "Memory pruning".
user_invocable: true
metadata:
  author: agentic-os
  version: '1.0'
  part-of: agentic-os
  layer: core
  extracted-from: wrap-up
---

# Memory Maintenance

Compacts and verifies the `.agent-memory/` store. Runs only when thresholds are exceeded or the user explicitly requests it.

## When to Use

- User says "clean memory", "memory cleanup", "prune patterns", "memory maintenance"
- `wrap-up` detected that one or more thresholds in Step 3 below are exceeded
  (in that case, `wrap-up` invokes this skill directly — the user does not have to)
- Before a long session: reset the working memory for a clean run
- Not part of the normal end-of-session flow. If nothing is exceeded and nobody asked, skip.

## What This Skill Does NOT Do

- Does NOT extract learnings (that's `wrap-up` Step 3)
- Does NOT update `session-summary.md` content (that's `wrap-up` Step 5)
- Does NOT modify `errors.json` beyond archiving (that's `iteration-logger`'s domain)
- Does NOT modify `patterns.json` rules (that's `pattern-extractor`'s domain) — it only archives stale entries
- Does NOT modify `decisions.json` status (that's `context-keeper`'s domain) — it only archives superseded entries

## Preconditions

- `.agent-memory/` directory exists (if not: suggest `/agentic-os:init`)
- No active self-improve loop. Read `improvements/state.json` in the plugin root;
  if `status == "running"`, abort with: "Self-improve loop is active — maintenance deferred."

## Step 1: Assess Memory Health

Read and measure all memory files:

```
.agent-memory/iterations/iteration-log.md    → count ## headings
.agent-memory/iterations/errors.json         → count array entries
.agent-memory/patterns/patterns.json         → count array entries
.agent-memory/quality/code-reviews.json      → count array entries
.agent-memory/quality/test-results.json      → count array entries
.agent-memory/context/decisions.json         → count array entries
.agent-memory/session-summary.md             → count lines
.agent-memory/learnings/learnings.md         → count lines
```

Record counts for Step 8 (report).

## Step 2: JSON Integrity Check

For each JSON file listed above:

1. Attempt to parse it
2. If parse fails: rename to `{file}.corrupt.bak`, create fresh with default (`[]` or `{}`), warn user with the file path and the parse error message
3. If parse succeeds: check structural issues specific to the file type (e.g. required fields on recent entries)

Track repair count for Step 8.

## Step 3: Archive Old Data

Thresholds:

- `iteration-log.md` > 100 entries: keep newest 100, archive rest
- `errors.json` > 50 entries: keep newest 50, archive rest
- `learnings/learnings.json` > 100 entries: keep newest 100, archive rest
- `code-reviews.json` > 100 entries: keep newest 100, archive rest
- `test-results.json` > 100 entries: keep newest 100, archive rest

Archive destination: `{filename}-archive-{YYYY-MM}.{ext}` in the same directory as the original.

If an archive file for the current month already exists, append to it instead of overwriting.

## Step 4: Prune Stale Patterns

Read `.agent-memory/patterns/patterns.json`:

1. Find patterns where `last_seen` is older than 60 days
2. Find patterns with `confidence < 0.3`
3. Move these to `patterns-archive-{YYYY-MM}.json`
4. Update `patterns.md` to reflect the pruned catalog

**Exception:** Never prune patterns with `skill_candidate: true` — these are actively being evaluated for promotion.

## Step 5: Compact Decisions

Archive decisions with `status: "superseded"` older than 90 days. Keep all `status: "active"` decisions regardless of age.

## Step 6: Enforce Session Summary Length

If `.agent-memory/session-summary.md` exceeds 30 lines: compress to 30 lines, keeping:

- The date header
- Top 5 bullets from "What Was Done"
- All "Open Items" entries (never drop these silently)
- Top 3 "Next Steps"
- One-line stats footer

## Step 7: Compact Learnings

If `.agent-memory/learnings/learnings.md` exceeds 200 lines:

1. Keep entries from the last 12 months
2. Archive older entries to `learnings-archive-{YYYY}.md`
3. Deduplicate by normalized text (lowercase, stripped punctuation, collapsed whitespace)

## Step 8: Consistency Check

Verify cross-file integrity after maintenance:

1. **patterns.md vs patterns.json** — if `patterns.json` has entries but `patterns.md` says "No patterns" or is outdated: regenerate it by calling `pattern-extractor` with "refresh patterns"
2. **No duplicate open-tasks.json** — verify `.agent-memory/open-tasks.json` does NOT exist at root level; canonical location is `context/open-tasks.json` only. If both exist, merge into `context/` and delete the root copy.
3. **Quality staleness** — if `quality-score.json` has `last_updated: null` AND `iterations/iteration-log.md` has entries: warn "Quality metrics never initialized — consider running quality-gate"
4. **learnings.md vs learnings.json** — if `learnings.json` exists, verify `learnings.md` header contains "Auto-generated from learnings.json". If not, regenerate from JSON.

## Step 9: Memory Report

Print a compact report to the user in the following output format:

```
Memory Maintenance:
  JSON Integrity: {n}/{total} valid ({n_repaired} repaired)
  Archived: {iterations} iterations, {errors} errors, {reviews} reviews
  Patterns pruned: {n_stale} stale, {n_low_conf} low-confidence
  Session summary: {compacted|ok} ({n} lines)
  Learnings: {compacted|ok} ({n} lines)
  Consistency: {n_issues} issues found, {n_fixed} fixed
```

Example output from a healthy run (nothing to archive):

```
Memory Maintenance:
  JSON Integrity: 8/8 valid (0 repaired)
  Archived: 0 iterations, 0 errors, 0 reviews
  Patterns pruned: 0 stale, 0 low-confidence
  Session summary: ok (24 lines)
  Learnings: ok (87 lines)
  Consistency: 0 issues found, 0 fixed
```

Stop after the report. Do NOT suggest a commit — memory files should not be committed (they are in `.gitignore`).

## Error Handling

- If `.agent-memory/` doesn't exist: print "Memory system not initialized — run `/agentic-os:init` first" and exit
- If any JSON file has a parse error and `{file}.corrupt.bak` already exists: rename to `{file}.corrupt-{YYYYMMDDHHMMSS}.bak` to preserve the earlier corruption snapshot
- If a self-improve loop is active (see Preconditions): exit with deferral message; do not partially run
- If disk write fails during archive creation: abort the current step, do NOT modify the source file, report which step failed

## What NOT to Do

- Do NOT modify identity files (`soul.md`, `user.md`)
- Do NOT prune patterns with `skill_candidate: true`
- Do NOT delete archive files (they are history)
- Do NOT run during an active self-improve loop
- Do NOT commit changes from this skill (memory files should not be in git)
- Do NOT combine with wrap-up into one call — they are separate skills for a reason
