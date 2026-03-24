---
name: iteration-logger
description: |
  Logs completed coding work — bug fixes, features, refactors, config changes —
  to the memory system. Use after finishing any meaningful coding task to capture
  what was done, what errors occurred, and what was learned. Especially valuable
  after multi-step debugging sessions or when a fix required several attempts.
  Includes duplicate detection and recurrence tracking to spot repeated problems.
  Trigger phrases: "log iteration", "log this fix", "iteration done",
  "document what I did", "track progress", "record what I did",
  "I just fixed a bug", "feature is done", "we should log this".

  <example>
  Context: User just fixed a bug after multiple attempts
  user: "log this fix"
  assistant: "Iteration #12 logged: bugfix — fixed circular import in auth module"
  <commentary>
  User completed a debugging cycle, trigger iteration-logger to record the fix.
  </commentary>
  </example>

  <example>
  Context: User finished implementing a new feature
  user: "done with the API endpoint, log it"
  assistant: "Iteration #13 logged: feature — added /api/users endpoint"
  <commentary>
  Feature completed, trigger iteration-logger to capture what was built.
  </commentary>
  </example>
user_invocable: true
---

# Iteration Logger

Log every meaningful coding iteration to `.agent-memory/iterations/`.

## When to Use

- After completing a feature, bugfix, refactor, or config change
- After fixing an error (especially multi-attempt fixes)
- When the Stop hook detects unlogged work
- User says "log this" or similar trigger phrases

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

**Required fields**: id, date, category, tags, problem, root_cause, fix, severity
**Optional fields**: trigger, failed_approaches, prevention, attempts, confidence

Read `errors.json` first to determine the next `id` number. Append to the array.

## Step 4: Write iteration-log.md Entry

```markdown
## Iteration #{n} — {YYYY-MM-DD} {HH:MM}

**Type:** feature | bugfix | refactor | config | docs | test
**Summary:** One-line description
**Files changed:** file1.py, file2.py
**Tests:** passed | failed | skipped | not applicable
**Confidence:** 3/5
**Tags:** python, import-error

### Details
- What was done and why

### Learnings
- Non-obvious insight (skip if nothing new was learned)

### Errors
- E{n}: Brief error reference (if applicable)
```

Read `iteration-log.md` first to determine the next iteration number.

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

- `iteration-log.md` > 500 entries → archive older entries to `iteration-log-archive-{YYYY-MM}.md`
- `errors.json` > 200 entries → archive older entries to `errors-archive-{YYYY-MM}.json`

Thresholds are configurable via plugin settings (`max_iterations_log_entries`, `max_error_log_entries`).

## What NOT to Do

- Do NOT push to global memory (that's wrap-up's job)
- Do NOT modify patterns.json (that's pattern-extractor's job)
- Do NOT modify decisions.json (that's context-keeper's job)
- Do NOT count individual file saves as separate attempts
- Do NOT log trivial changes (typo fixes, whitespace) unless part of a larger iteration
