---
name: iteration-logger
description: >
  Logs every coding iteration (feature, bugfix, refactor) to the memory system.
  Captures what was done, what errors occurred, and what was learned.
  Trigger phrases: "log iteration", "log this fix", "iteration done",
  "document what I did".

metadata:
  author: agentic-os
  version: '3.0'
  layer: system
---

# Iteration Logger

## When to Use

After completing a feature, bugfix, refactor, or any meaningful code change.

## What to Log

### iteration-log.md Entry

```markdown
## Iteration #{n} — {date} {time}

**Type:** feature | bugfix | refactor | config | docs | test
**Summary:** One-line description
**Files changed:** file1.py, file2.py
**Tests:** passed | failed | skipped | not applicable
**Confidence:** 1-5 (how confident the change is correct)

### Details
- What was done
- Why this approach was chosen

### Learnings
- What was learned (if anything non-obvious)
```

### errors.json Entry (if errors occurred)

```json
{
  "id": "E{n}",
  "date": "2026-03-19",
  "iteration": 42,
  "type": "runtime | test | build | config | logic",
  "description": "What went wrong",
  "root_cause": "Why it went wrong",
  "fix": "How it was fixed",
  "prevention": "How to prevent it in future",
  "severity": "critical | major | minor"
}
```

## Cross-Project Push

After logging, check if the error/learning is generalizable:
- If `prevention` applies beyond this project → tag for global sync
- If same error pattern occurred before (check errors.json history) → escalate to pattern

## Instructions

1. Read current `iteration-log.md` to determine next iteration number
2. Append new entry to `iteration-log.md`
3. If errors occurred, append to `errors.json`
4. If iteration count is a multiple of `trigger-rules.json`.`pattern_check_interval`, suggest running pattern extraction
5. Update `quality-score.json` if test results changed
6. **Log Rotation:** If `iteration-log.md` exceeds 500 entries (configurable via plugin setting `max_iterations_log_entries`), archive older entries to `iteration-log-archive-<YYYY-MM>.md`. If `errors.json` exceeds 200 entries (configurable via `max_error_log_entries`), archive older entries to `errors-archive-<YYYY-MM>.json`.
