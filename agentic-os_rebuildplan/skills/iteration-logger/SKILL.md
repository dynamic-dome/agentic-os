---
name: iteration-logger
description: >
  Logs every prompt-to-fix iteration of a coding agent. Captures error context,
  root cause, solution, failed approaches, and takeaways in structured form
  (JSON + Markdown). Use after every completed debugging or implementation
  iteration, especially when a fix required multiple attempts. Trigger phrases:
  "log iteration", "fehler notieren", "iteration protokollieren", "log this fix",
  "was haben wir gerade gelernt", "save this lesson", "document this fix",
  "iteration done", "Fortschritt festhalten".
metadata:
  author: agentic-os
  version: '3.1'
  part-of: agentic-os
  layer: core
---

# Iteration Logger

## Purpose

Create a structured, searchable record of every problem→fix cycle. This data
feeds into `pattern-extractor` for automated pattern recognition. Quality of
downstream analysis depends entirely on quality of logging — be precise,
not verbose.

## When to Trigger

- A bug was found and fixed
- An implementation succeeded after trial-and-error
- A prompt required multiple attempts to produce the right result
- User explicitly says "log iteration" / "fehler notieren" / "iteration protokollieren"

## Directory Layout

```
.agent-memory/
└── iterations/
    ├── iteration-log.md      # Chronological narrative (human-readable)
    └── errors.json           # Structured error database (machine-queryable)
```

Create both files if they do not exist (`errors.json` as `[]`, `iteration-log.md` as empty).

## Instructions

### Step 1: Analyze the iteration

Identify the following from the just-completed iteration:

| Field | What to capture | Source |
|-------|----------------|--------|
| trigger | What started the iteration | User prompt, error message, test failure |
| problem | What exactly went wrong | Error message, incorrect behavior, performance issue |
| root_cause | Why it happened | The actual underlying reason |
| solution | What was changed | Code diff, config change, architecture decision |
| failed_approaches | What was tried and did not work | List of rejected approaches with reason |
| attempts | How many distinct approaches were tried | Count: 1 (direct fix) to N (trial-and-error) |
| category | Classification | One of: `syntax`, `logic`, `config`, `dependency`, `architecture`, `performance`, `testing`, `environment` |
| severity | Impact level | `critical` (blocks all work), `major` (blocks feature), `minor` (inconvenience) |

**Counting attempts**: Count each *distinct approach*, not each code edit. If you
tried "change import order", then "add TYPE_CHECKING guard", then "lazy import" —
that is 3 attempts, even if each involved multiple edits.

### Step 2: Duplicate check (BEFORE writing)

Read existing `errors.json` and check for duplicates:

- Same `category` AND overlapping `tags` (≥2 shared tags)?
- If match found:
  - Do NOT create a new entry
  - Add a `recurrence` entry to the existing record (see schema below)
  - Update `iteration-log.md` with a short note referencing the original
  - If the problem now has 3+ occurrences → recommend running `pattern-extractor`

Only if no duplicate is found → proceed to Step 3.

### Step 3: Write to errors.json

Append a new entry:

```json
{
  "id": "<YYYY-MM-DD-HHMM>-<short-slug>",
  "timestamp": "<ISO 8601>",
  "category": "<syntax|logic|config|dependency|architecture|performance|testing|environment>",
  "severity": "<critical|major|minor>",
  "trigger": "<what started the iteration>",
  "problem": "<problem description, 1-2 sentences>",
  "root_cause": "<root cause analysis, 1-2 sentences>",
  "solution": "<what was changed, 1-2 sentences>",
  "attempts": "<number of distinct approaches tried>",
  "failed_approaches": [
    "<approach 1: what was tried and why it failed>"
  ],
  "files_changed": ["<affected files>"],
  "tags": ["<relevant tags for clustering>"],
  "reusable_pattern": "<if a reusable pattern was recognized, describe it; otherwise null>",
  "recurrence": []
}
```

**Recurrence sub-schema** (appended to existing entries on duplicate):

```json
{
  "date": "<ISO 8601>",
  "context": "<brief description of this occurrence>",
  "same_fix": "<true|false — was the same solution applied?>"
}
```

### Step 4: Write to iteration-log.md

Append a new entry:

```markdown
## [<date> <time>] <short title>

**Category:** <category> | **Severity:** <severity> | **Attempts:** <n>

**Problem:** <one-liner>

**Root Cause:** <one-liner>

**Solution:** <what was changed, compact>

**Failed Approaches:**
- <approach 1: what and why it failed>

**Takeaway:** <one sentence: what should the agent do differently next time?>

---
```

### Step 5: Output confirmation

```
Iteration logged: "<short title>"
  Category: <cat> | Severity: <sev> | Attempts: <n>
  Takeaway: <one sentence>
  [Duplicate of #<id> — occurrence #<n>]
  [Pattern threshold reached (3x) — run pattern-extractor]
```

## Tag Guidelines

Use consistent, lowercase tags for reliable clustering downstream:

- Language/runtime: `python`, `node`, `rust`
- Domain: `import`, `async`, `database`, `auth`, `api`
- Problem type: `circular-dependency`, `race-condition`, `type-error`, `encoding`
- Tool: `pytest`, `docker`, `venv`, `git`

Reuse existing tags from `errors.json` where possible. Check existing entries
before inventing new tags.

## Scaling

- When `errors.json` exceeds 200 entries, recommend archiving:
  Move entries older than 90 days to `iterations/archive/errors-<YYYY-Q>.json`
- Keep `iteration-log.md` as append-only. If it exceeds 500 lines, start a new
  file: `iteration-log-<YYYY-MM>.md` and update the current one.

## Example

Input context: Agent spent 20 minutes debugging an import error.

```json
{
  "id": "2026-03-17-0830-circular-import",
  "timestamp": "2026-03-17T08:30:00+01:00",
  "category": "dependency",
  "severity": "major",
  "trigger": "ImportError: cannot import name 'Config' from 'app.core'",
  "problem": "Circular import between app.core.config and app.core.database",
  "root_cause": "database.py imports Config at module level, Config imports DB_URL from database",
  "solution": "Lazy import in database.py: Config is imported inside the function, not at module level",
  "attempts": 4,
  "failed_approaches": [
    "Changed import order in __init__.py — did not resolve cycle",
    "Added TYPE_CHECKING guard — only helps type hints, not runtime",
    "Extracted shared constants.py — too much refactoring for the gain"
  ],
  "files_changed": ["app/core/database.py"],
  "tags": ["python", "circular-dependency", "lazy-import", "import"],
  "reusable_pattern": "For circular imports in Python: use lazy import inside the function instead of module-level import",
  "recurrence": []
}
```
