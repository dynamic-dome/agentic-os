---
name: memory-maintenance
description: >
  Compacts, archives, and integrity-checks the .agent-memory/ store
  (thresholds live in scripts/memory-thresholds.sh). Use when the user asks
  for cleanup ("clean memory", "prune patterns", "memory health") or when
  wrap-up reports exceeded thresholds; never part of the normal
  end-of-session flow.
model: sonnet
effort: low
metadata:
  author: agentic-os
  version: '1.4'
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

## Step 0: Pre-Run Commit (backup light)

Maintenance mutates the store (archiving, pruning, recreating corrupt files). Snapshot
it FIRST: run the shared procedure `${CLAUDE_PLUGIN_ROOT}/references/pre-run-commit.md`
with commit message `chore(memory): pre-run snapshot vor memory-maintenance`.

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

The threshold NUMBERS are not defined here. Run the single source of truth:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/memory-thresholds.sh" .agent-memory
```

Exit 0 → nothing to archive, skip. Exit 10 → each `THRESHOLD:` line names the
file, its current count, the limit, and the action. For every flagged store file
(e.g. `iteration-log.md`, `errors.json`, `learnings/learnings.json`): keep the
newest entries within the script's limit, archive the rest. Apply the same
keep-newest/archive-rest action to `quality/code-reviews.json` and
`quality/test-results.json` if they have grown past the same order of magnitude
(legacy quality stores, not covered by the script).

Archive destination: `{filename}-archive-{YYYY-MM}.{ext}` in the same directory as the original.

If an archive file for the current month already exists, append to it instead of overwriting.

## Step 3b: Clean working/ Scratch Files

`working/` accumulates session scratch (helper scripts, temp exports) that no other
skill feels responsible for. Delete files directly in `.agent-memory/working/`
matching `*.py`, `*.tmp`, or `*.bak` that are older than the staleness window in
`memory-thresholds.sh` (its `working/` check, currently 7 days).

**Exempt (never delete):** the living session artifacts `working/current-session.json`
and `working/user-candidates.json`. Report the number of deleted files in Step 9.

**Dirty-state files (`working/dirty-*.json`):** do NOT hand-pick these — run the
deterministic collector, which encodes the full safety rule (mtime <30min protection,
consolidated markers, and markers superseded by a later wrap-up). Preview first
(dry-run, no deletion), then apply:

```bash
python "${CLAUDE_PLUGIN_ROOT}/scripts/gc_dirty_markers.py" .agent-memory           # preview
python "${CLAUDE_PLUGIN_ROOT}/scripts/gc_dirty_markers.py" .agent-memory --apply    # delete
```

It removes a marker only when it is safe: `dirty: false`/`consolidated_at` set, OR
`updated < consolidation-marker.last_wrapup` (a later wrap-up ran, so the work is in
git/native memory). It NEVER deletes a file whose mtime is within 30 min (live/parallel
session) or an un-consolidated session with no later wrap-up (real recovery evidence
that session-bootstrap reports and wrap-up consumes). Report the removed count in Step 9.

## Step 3c: Native Memory Stores Audit (read-only report)

The native Claude-Code memory stores (`~/.claude/projects/*/memory/`) live outside
`.agent-memory/` but feed every session start via MEMORY.md injection. Run the
read-only auditor:

```bash
python "${CLAUDE_PLUGIN_ROOT}/scripts/native_memory_audit.py"
```

Exit 0 → carry the report's `**Summary:**` line (active/dormant incl. frozen/
orphans/dead links/injection warnings) verbatim into the Step 9 report. Any
non-zero exit (2 = usage/path error, 1 = unexpected crash) → tool error; report
one line and continue — a failed audit must never block the maintenance itself.

This step is strictly a REPORTER: it NEVER rotates, deletes, or edits native
stores. Rotation and orphan fixes stay owner decisions; `warn`/`critical`
injection warnings are surfaced to the user, not auto-fixed.

## Step 4: Prune Stale Patterns

Read `.agent-memory/patterns/patterns.json`:

1. Find patterns where `last_seen` is older than 60 days
2. Find patterns with `confidence < 0.3`
3. Move these to `patterns-archive-{YYYY-MM}.json`
4. Update `patterns.md` to reflect the pruned catalog

**Exception:** Never prune patterns with `skill_candidate: true` — these are actively being evaluated for promotion.

## Step 4b: Decay the Global Layer (global-decay)

Only when the global store exists (`~/.claude-memory/global/`). This is the **only** place
confidence decays — never on the read path (session-bootstrap stays read-only). Source the
helper: `. scripts/global-schema.sh`.

For each entry in the global `patterns.json` / `learnings.json`:

1. `new_confidence = apply_decay(confidence, days_since(last_relevant))` — i.e. **−0.1 per
   full 90-day step without recall, floored at 0.3**. Write the decayed confidence back.
2. If the decayed `confidence <= 0.3` AND `days_since(last_relevant) > 365` →
   set `lifecycle: "archived"` (the pull-lifecycle-filter then stops serving it).
3. **Never hard-delete** — an archived entry stays in the file for audit / "what did we
   believe before?" queries, exactly like a `superseded` one. Only `lifecycle` changes.

`last_relevant` is bumped only on a genuine recall (an entry actually pulled into a local
store), never by this maintenance pass and never by a read.

## Step 5: Compact Decisions

Archive decisions with `status: "superseded"` older than 90 days. Keep all `status: "active"` decisions regardless of age.

## Step 6: Enforce Session Summary Length

If `scripts/memory-thresholds.sh` flagged `session-summary.md` (line limits live ONLY in
that script): compress back to the wrap-up target length, keeping:

- The date header
- Top 5 bullets from "What Was Done"
- All "Open Items" entries (never drop these silently)
- Top 3 "Next Steps"
- One-line stats footer

## Step 7: Compact Learnings

If `scripts/memory-thresholds.sh` flagged `learnings.md` (line limits live ONLY in that
script):

1. Keep entries from the last 12 months
2. Archive older entries to `learnings-archive-{YYYY}.md`
3. Deduplicate by normalized text (lowercase, stripped punctuation, collapsed whitespace)

## Step 8: Consistency Check

Verify cross-file integrity after maintenance:

1. **patterns.md vs patterns.json** — if `patterns.json` has entries but `patterns.md` says "No patterns" or is outdated: regenerate it by calling `pattern-extractor` with "refresh patterns"
2. **No duplicate open-tasks.json** — verify `.agent-memory/open-tasks.json` does NOT exist at root level; canonical location is `context/open-tasks.json` only. If both exist, merge into `context/` and delete the root copy.
3. **Quality staleness** — if `quality-score.json` has `last_updated: null` AND `iterations/iteration-log.md` has entries: note "Quality metrics never initialized (legacy store — no active writer since v4.0.0)"
4. **learnings.md vs learnings.json** — if `learnings.json` exists, verify `learnings.md` header contains "Auto-generated from learnings.json". If not, regenerate from JSON.
5. **soul.md anti-bloat** — if `identity/soul.md` exceeds **80 lines**, warn: "soul.md is {n} lines (cap 80) — condense; an overlong identity file dilutes its effect". Do NOT auto-edit soul.md (it is user-owned); only flag it for the user to prune.

## Step 9: Memory Report

Print a compact report to the user in the following output format:

```
Memory Maintenance:
  JSON Integrity: {n}/{total} valid ({n_repaired} repaired)
  Archived: {iterations} iterations, {errors} errors, {reviews} reviews
  Patterns pruned: {n_stale} stale, {n_low_conf} low-confidence
  Session summary: {compacted|ok} ({n} lines)
  Learnings: {compacted|ok} ({n} lines)
  Native stores: {n_active} active, {n_dormant} dormant ({n_frozen} frozen), {n_orphans} orphans, {n_dead} dead links, {n_warn} injection warnings
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
  Native stores: 17 active, 8 dormant (6 frozen), 0 orphans, 0 dead links, 1 injection warnings
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
