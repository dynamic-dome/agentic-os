---
name: wrap-up
description: >
  End-of-session routine for the agentic OS. Updates session-summary.md with
  completed work, open items, and next steps. Collects learnings, updates
  user.md with recurring feedback patterns, and optionally creates a git commit.
  Also handles context handoff before context compression. Use at the end of
  every coding session or when the user says "session beenden", "wrap up",
  "session zusammenfassen", "was haben wir geschafft", "save session",
  "feierabend", "session end", "kontext sichern", "handoff". Also trigger
  when the user signals they're done ("ich hoer auf", "das wars fuer heute",
  "letzte aenderung") or before context compression.
metadata:
  author: agentic-os
  version: '3.1'
  part-of: agentic-os
  layer: core
---

# Session Wrap-Up

## Purpose

Capture what happened in a session so the next session can pick up seamlessly.
This is the write counterpart to session-bootstrap's read. A good wrapup means
the next session starts productive from the first prompt instead of spending
10 minutes reconstructing context.

Also serves as context handoff before compression (replaces the former
agent-handoff skill).

## When to Trigger

- User says "session beenden", "wrap up", "feierabend", "das wars"
- End of a long coding session
- Before context compression (PreCompact)
- Before switching to a different project or agent
- User asks "was haben wir heute geschafft?"
- User says "kontext sichern" or "handoff"

## Pre-flight Check

1. Verify `.agent-memory/` exists. If not: warn and suggest running `/agentic-os:init`.
2. Check for uncommitted git changes (if git is available).

## Step 1: Gather Session Data

Collect from the current session (conversation context + file system):

| Data | Source | Fallback |
|------|--------|----------|
| Changes made | `git diff --stat` or conversation | Ask user |
| Bugs fixed | Iteration log entries from this session | Conversation |
| Decisions made | decisions.json entries from today | Conversation |
| Tests status | Last test run output | Ask user |
| Open items | Unfinished work, TODOs in code | Ask user |

If git is available, use it as primary source:

```bash
# Changes since session start (rough: last 4 hours)
git log --oneline --since="4 hours ago"
git diff --stat HEAD~5..HEAD  # adjust based on commit count
```

Don't rely on exact timing — use git log to find the session boundary and
work from there. If git is not available, reconstruct from conversation history.

## Step 2: Write session-summary.md

Overwrite `.agent-memory/session-summary.md` — this is a snapshot for the
next session, not an append log:

```markdown
# Last Session

*Date: <date and time>*
*Agent: <Claude Code / Cowork / other>*
*Duration: <approximate, from first to last activity>*

## Completed
- <what was done, concrete and specific>
- <reference commit hashes if available>

## In Progress
- <started but not finished>
- <current state and what's left>

## Bugs Fixed
- <short description> (see iterations/<id>)

## Decisions Made
- <short description> (see context/decisions.json#<id>)

## Test Status
- <green/red/not run, which tests>

## Quality State
- Test Health: <score>/100 (from quality-score.json, if available)
- Code Quality: <score>/100 (from quality-score.json, if available)

## Active Warnings
- <high-confidence pattern warnings from patterns.json>
- <unresolved critical errors>

## Open Items
- <what needs attention next>

## Recommended Next Steps
1. <most important>
2. <second priority>
3. <if applicable>
```

Keep it scannable — under 30 lines. The next session's bootstrap reads this
first, so front-load the most actionable information.

## Step 3: Update Learnings

If the session produced insights worth remembering (not every session does),
append to `.agent-memory/learnings/learnings.md`:

```markdown
## <date> — <topic>

**Context**: <what was being worked on>
**Insight**: <what was learned>
**Action**: <what to do differently / what to keep doing>

---
```

Only log genuine insights — things that change future behavior. "pytest
needs -v flag" is not a learning. "Our test fixtures assume UTC but the
app uses local time, causing flaky tests on CI" is.

## Step 4: Update User Profile (if applicable)

Check if the session revealed recurring patterns about the user. Only update
`identity/user.md` when there's a clear, repeated signal (≥3 occurrences of
the same type of correction):

- Repeated corrections ("I told you not to...") → add to "Recurring Feedback"
- Frequent error patterns → add to "Common Error Patterns"
- New preferences discovered → update relevant section

A single correction is not a pattern — wait for repetition.

**Format for recurring feedback entries:**

```markdown
## Recurring Feedback
- **<date>**: <pattern> — <what the user corrected/preferred>
```

## Step 5: Check for Unlogged Iterations

Scan the conversation for bug fixes or implementation cycles that weren't
logged to `iterations/`. If found, log them now using the iteration-logger
format (compact version — full detail isn't needed for retroactive logging).

This is a safety net, not a replacement for logging during work.

## Step 6: Git Commit (optional)

If there are uncommitted changes and git is available:

1. Show the user what would be committed: `git status` + `git diff --stat`
2. Suggest a commit message using conventional commit format
3. Only commit with explicit user approval
4. If the user pre-approved commits or says "ja, commit alles", proceed
   without further confirmation

## Step 7: Confirmation

```
SESSION WRAPPED UP
  Summary: session-summary.md updated
  Learnings: <n new entries / no new entries>
  User profile: <updated / no changes>
  Unlogged iterations: <n retroactively logged / none>
  Git: <committed <hash> / uncommitted changes remain / no git>

  Next session: read session-summary.md for context
```

## What NOT to Do

These files are managed by other skills — wrap-up must not modify them:
- `errors.json` — managed by iteration-logger
- `patterns.json` / `patterns.md` — managed by pattern-extractor
- `decisions.json` — managed by context-keeper
- `quality-score.json` — managed by code-reviewer / test-validator

The only files wrap-up writes to:
- `session-summary.md` (overwrite)
- `learnings/learnings.md` (append)
- `identity/user.md` (targeted edit, only recurring feedback section)
- `iterations/iteration-log.md` (append, only for retroactive logging)
