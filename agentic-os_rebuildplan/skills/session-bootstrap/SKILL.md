---
name: session-bootstrap
description: >
  Bootstraps full project context at the start of every coding session by reading
  all knowledge files from .agent-memory/. Performs basic health checks, validates
  JSON integrity, and produces a compact briefing with project status, active
  patterns, warnings, and recommended next steps. Also handles first-time
  initialization referral. Use this skill at the start of any new session, after
  context-window resets, or when switching between agents. Trigger phrases:
  "session starten", "kontext laden", "bootstrap", "projekt-briefing",
  "wo waren wir", "was wissen wir", "context restore", "neue session",
  "session start", "begin work", "health check", "system check".
metadata:
  author: agentic-os
  version: '3.1'
  part-of: agentic-os
  layer: orchestration
---

# Session Bootstrap

## Purpose

Load all persistent knowledge from `.agent-memory/` and produce a briefing that
lets the agent work productively from the first prompt. This skill reads
knowledge files, performs basic health checks, and identifies issues — it never
modifies files during bootstrap (except for corrupt JSON recovery).

Replaces the former heartbeat + session-bootstrap two-skill chain with a single,
faster entry point.

## When to Trigger

- Start of every new coding session
- After context-window reset or long pause
- User asks "Wo waren wir?" / "Was wissen wir?" / "Projektstand?"
- Manually for health checks: "system check", "health check"

## Directory Layout (read-only during bootstrap)

```
.agent-memory/
├── session-summary.md
├── identity/
│   ├── soul.md
│   └── user.md
├── context/
│   ├── project-context.md
│   └── decisions.json
├── iterations/
│   ├── iteration-log.md
│   └── errors.json
├── patterns/
│   ├── patterns.md
│   └── patterns.json
├── quality/
│   ├── test-results.json
│   ├── code-reviews.json
│   └── quality-score.json
├── learnings/
│   └── learnings.md
└── generated-skills/
```

## Instructions

### Step 1: Check if .agent-memory/ exists

If `.agent-memory/` does not exist → suggest running `/agentic-os:init` and stop.
Do not attempt to create the structure during bootstrap.

### Step 2: Load identity files

Read in this order. Skip any file that does not exist.

1. **identity/soul.md** — Agent behavior, priorities, guard rails. Apply these
   settings for the remainder of the session.
2. **identity/user.md** — User preferences, work style. Adapt communication
   accordingly.

### Step 3: Load project context

3. **context/project-context.md** — Tech stack, architecture, constraints, module status.
4. **session-summary.md** — Summary from previous session end.

### Step 4: Load patterns and warnings

5. **patterns/patterns.md** — Known patterns and anti-patterns.
   Focus on `confidence: high` patterns.
6. **iterations/errors.json** — Load only the last 20 entries (tail, not full load).
   If the file has more than 200 entries, warn that archiving is recommended.
7. **context/decisions.json** — Filter to `"status": "active"` entries only.

### Step 5: Load quality state

8. **quality/quality-score.json** — Current test health and code quality scores.

### Step 6: Health checks

Run these checks and collect warnings:

**6.1 JSON integrity**
Validate that all JSON files parse correctly:
- `errors.json`, `patterns.json`, `decisions.json`
- `test-results.json`, `code-reviews.json`, `quality-score.json`

If a file is corrupt: rename to `<file>.corrupt.bak`, create fresh with
default value (`[]` or `{}`), and add a warning.

**6.2 Scaling guards**
- `errors.json` > 200 entries → warn, recommend archiving
- `decisions.json` > 50 active entries → warn, recommend reviewing
- `patterns.json` > 30 patterns → warn, recommend consolidating

**6.3 Quality alerts**
- Test health score declining → warn
- Code quality score < 60 → warn
- Unresolved critical findings in code-reviews.json → warn

### Step 7: Produce briefing

Output format (adapt content, keep structure compact):

```
SESSION BRIEFING — <project name>
<date and time>
---

PROJECT STATUS
  <1-2 sentences from project-context.md>
  Active modules: <list with status>

TECH STACK
  <compact list of core technologies>

LAST SESSION
  <summary from session-summary.md, or "No previous summary found">
  Open items: <from session-summary.md>

ACTIVE WARNINGS
  <high-confidence patterns (confidence: high, occurrences >= 3)>
  <quality alerts from Step 6.3>
  <scaling warnings from Step 6.2>
  <last 3 unresolved errors from errors.json>

STATISTICS
  Total iterations: <n>
  Recognized patterns: <n>
  Generated skills: <n>
  Quality: Test <score>/100 | Code <score>/100

AVAILABLE GENERATED SKILLS
  <list of skill names from generated-skills/>

---
```

### Step 8: Recommend next steps

Based on the briefing, output 2-3 concrete recommendations:

```
RECOMMENDED NEXT STEPS
  1. <based on open items from last session>
  2. <based on pattern warnings or quality alerts>
  3. <based on project status>

  Ready? Or should I first <specific action>?
```

## Initialization Referral

If `.agent-memory/` does not exist:

```
.agent-memory/ not found.
Run /agentic-os:init to set up the memory system.
```

Do not create the directory structure from within bootstrap — that's the
init command's job.

## Error Handling

- Missing files: skip and note in briefing ("No previous summary found")
- Corrupt JSON: recover (rename + recreate), warn user
- Empty errors.json/patterns.json: normal for new projects, no warning needed
- Missing identity files: warn and suggest running init

## Scaling Guard Thresholds

| File | Threshold | Action |
|------|-----------|--------|
| `errors.json` | > 200 entries | Recommend archiving to `iterations/archive/` |
| `decisions.json` | > 50 active | Recommend reviewing for superseded decisions |
| `patterns.json` | > 30 patterns | Recommend consolidating low-confidence patterns |
