---
name: iteration-logger
description: >
  Logs a coding iteration (feature, bugfix, refactor) with errors, tags, and
  learnings to .agent-memory/iterations/; tracks recurrences. Use after
  completing a unit of work ("log iteration", "log this fix"), or when
  wrap-up harvests unlogged work at session end.
model: sonnet
effort: low
metadata:
  author: agentic-os
  version: '3.1'
  part-of: agentic-os
  layer: core
---

# Iteration Logger

Log every meaningful coding iteration to `.agent-memory/iterations/`.

## When to Use

- After completing a feature, bugfix, refactor, or config change
- After fixing an error (especially multi-attempt fixes)
- When the Stop hook detects unlogged work
- User says "log this" or similar trigger phrases

**NOT at session end.** Since T-015 `wrap-up` Step 1.5 harvests iterations into its
own write plan instead of invoking this skill — loading a skill body triggered a
full prefix-cache rewrite in 41% of measured cases (L34/D-010), and wrap-up already
holds the session context this skill would re-derive. This skill is the entry point
for logging *during* a session, not for the wrap-up.

## The Write Path (write-path)

`scripts/apply_wrapup.py` is the single writer for `iteration-log.md`,
`errors.json` and `working/current-session.json`. Do not write them by hand — the
script owns id continuation, the recurrence rule, the markdown shape and the
working-memory bookkeeping, so both entry points produce byte-identical results:

```bash
python "${CLAUDE_PLUGIN_ROOT}/scripts/apply_wrapup.py" .agent-memory --session-id <sid> <<'PLAN'
{"date": "YYYY-MM-DD", "iterations": [ { ...one object per iteration... } ]}
PLAN
```

Field schema: `skills/wrap-up/references/wrapup-schemas.md` §Write plan
(`iterations`). Steps 1–4 below define WHAT goes into that object; the script
decides how it lands on disk. Use `--dry-run` to preview the tally.

## Step 1: Analyze the Iteration

Before logging, gather:

1. **Type**: `feature` | `bugfix` | `refactor` | `config` | `docs` | `test`
2. **Files changed**: List all modified files (use `git diff --name-only` if available)
3. **Summary**: One-line description of what was done
4. **Approach**: Why this approach was chosen over alternatives
5. **Failed approaches**: What was tried and didn't work (critical for learning)
6. **Confidence**: 1-5 scale (how confident the change is correct)
7. **Test status**: passed | failed | skipped | not applicable

### Counting Rule

Count **distinct approaches**, not individual edits. If you tried 3 different fixes before finding the right one, that's `attempts: 3` — not the number of file saves.

### Tag Guidelines

Tags enable pattern clustering. Use consistent lowercase tags:

- **Language/framework**: `python`, `react`, `opencv`, `fastapi`
- **Domain**: `auth`, `database`, `api`, `ui`, `config`
- **Error type**: `import-error`, `type-error`, `race-condition`, `null-pointer`
- **Pattern**: `circular-import`, `missing-dependency`, `wrong-path`

Always include at least 2 tags. Reuse existing tags from previous iterations when applicable — check `errors.json` for tag conventions already in use.

## Step 2: Duplicate Detection

Before creating a new entry, check for recurrence:

1. Read the last 20 entries from `errors.json`
2. Compare: same `category` AND >= 2 overlapping `tags`
3. If match found:
   - **Increment** `occurrences` on the existing entry
   - **Append** to its `recurrence_dates` array
   - **Update** `last_seen` timestamp
   - Do NOT create a new entry
   - Note the recurrence in `iteration-log.md` as `(Recurrence of E{id})`

4. If no match: create new entry (Step 3)

## Step 3: Write errors.json Entry

Only if errors occurred during the iteration.

```json
{
  "id": "E{n}",
  "date": "YYYY-MM-DD",
  "iteration": 42,
  "category": "runtime | test | build | config | logic | import | type",
  "tags": ["python", "import-error", "circular-import"],
  "trigger": "What action triggered the error",
  "problem": "What went wrong (observable symptoms)",
  "root_cause": "Why it went wrong (underlying cause)",
  "fix": "How it was fixed (specific changes)",
  "failed_approaches": [
    "Approach 1: description — why it failed"
  ],
  "prevention": "How to prevent this in future",
  "severity": "critical | major | minor",
  "attempts": 2,
  "confidence": 4,
  "occurrences": 1,
  "recurrence_dates": [],
  "last_seen": "YYYY-MM-DD"
}
```

**Required fields**: category, tags, problem, root_cause, fix, severity
**Optional fields**: trigger, failed_approaches, prevention, attempts, confidence

Put these into the iteration's `errors` array — do NOT set `id`, `date`,
`occurrences`, `recurrence_dates` or `last_seen`. The script assigns the id in the
format already on disk (`err-00n`, not the `E{n}` older versions of this file
claimed) and applies the Step-2 recurrence rule itself: a match increments the
existing entry instead of appending a new one.

## Step 4: iteration-log.md Entry

The script renders the block; supply the content fields (`type`, `title`, `tags`,
`files_changed`, `summary`, `confidence`, `tests`, `learnings`, `commits`). The
rendered shape is:

```markdown
## {YYYY-MM-DD} — {type}: {title}
- **Type:** feature | bugfix | refactor | config | docs | test
- **Tags:** python, import-error
- **Files changed:** file1.py, file2.py
- **Summary:** One-line description
- **Confidence:** 3/5
- **Tests:** passed | failed | skipped | not applicable
- **Errors:** err-00n | (Recurrence of err-00n)
```

Do not re-derive this format from surrounding entries and do not hand-write the
block — that is exactly how the log drifted away from its documented template for
months. An identical header on a re-run is skipped, so applying the same plan
twice is safe.

## Step 4b: Working Memory

`working/current-session.json` is updated by the same call: new error ids land in
`errors_this_session`. Non-obvious insights belong in the iteration's `learnings`
field — wrap-up later promotes them to `learnings.json` or discards them.

## Step 5: Confirm and Suggest

Output a brief confirmation:

```
Iteration #{n} logged: {type} — {summary}
  Files: {count} | Errors: {count} | Confidence: {n}/5
  Tags: {tags}
```

Then check:
- If iteration count is a multiple of 5 → suggest running pattern-extractor
- If same error occurred 3+ times → flag as anti-pattern candidate
- If confidence <= 2 → suggest code review

## Log Rotation

Rotation/archiving of `iteration-log.md` and `errors.json` is `memory-maintenance`'s job — this skill only appends.
The rotation thresholds live in `scripts/memory-thresholds.sh` (single source of truth).

## What NOT to Do

- Do NOT write `iteration-log.md`, `errors.json` or `current-session.json` with
  Write/Edit — they go through `apply_wrapup.py` (see The Write Path)
- Do NOT push to global memory (that's wrap-up's job)
- Do NOT modify patterns.json (that's `scripts/extract_patterns.py`)
- Do NOT modify decisions.json (that's context-keeper's job)
- Do NOT count individual file saves as separate attempts
- Do NOT log trivial changes (typo fixes, whitespace) unless part of a larger iteration
