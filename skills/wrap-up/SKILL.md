---
name: wrap-up
description: |
  Wraps up a coding session — summarizes what was done, extracts learnings,
  updates the session summary, suggests a git commit, and optionally runs
  memory maintenance (archiving, JSON integrity, pruning). Use when you are
  done working for now, when context is getting long and needs a handoff,
  or before switching to a different project. Ensures no progress is lost
  and the next session can pick up seamlessly.
  Trigger phrases: "wrap up", "end session", "session end", "save session",
  "close session", "finish for today", "summarize session",
  "save context", "session handoff", "agent handoff",
  "I'm done for today", "that's it for today", "give me a summary",
  "clean memory", "memory cleanup", "archive old data",
  "memory health", "compact memory", "prune patterns", "memory maintenance".

  <example>
  Context: User is done for the day
  user: "done for today, wrap up"
  assistant: "Session Wrap-Up: 5 iterations completed, 2 bugs fixed. Session summary updated."
  <commentary>
  User ends session, trigger wrap-up to save context for next session.
  </commentary>
  </example>
user_invocable: true
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: core
---

# Session Wrap-Up

End-of-session sequence. Summarizes work, extracts learnings, prepares for next session. Optionally runs memory maintenance.

## When to Use

- At the end of every coding session
- When context window is getting long (pre-compression)
- User says "wrap up", "end session", etc.
- When memory needs maintenance: "clean memory", "memory cleanup", "prune patterns"
- Note: this skill is manual-only — no hook triggers it automatically

## Step 1: Gather Session Data

Collect from the current session:

1. **Iteration log**: Read `.agent-memory/iterations/iteration-log.md` — find entries from today's date
2. **Git changes**: Run `git diff --stat` and `git log --oneline -5` (if git available)
3. **Test status**: Read `.agent-memory/quality/test-results.json` — latest entry
4. **Code quality**: Read `.agent-memory/quality/code-reviews.json` — latest entry
5. **Errors this session**: Read `.agent-memory/iterations/errors.json` — entries from today

If iteration-log.md is empty or has no entries from today: note "No iterations in this session" and proceed to Step 5 (skip Steps 2-4).

## Step 2: Summarize Work Done

Create a structured summary from gathered data:

- Count: iterations completed, errors encountered, tests run
- List: files changed (from git diff or iteration log)
- Note: any quality score changes (improved/declined/stable)

## Step 3: Extract Learnings

Review today's iterations for genuine insights. A learning is worth recording if:

- It would prevent a future mistake
- It reveals something non-obvious about the codebase
- It documents a decision rationale that isn't in the code

**Do NOT log trivial facts** like "file X exists" or "function Y takes 2 arguments".

Append real learnings to `.agent-memory/learnings/learnings.md`:

```markdown
## {date}

- {insight with context}
```

## Step 4: Run Pattern Extraction

If 3+ new iterations were logged this session, trigger pattern-extractor:
- This is a lightweight call — just analyzing the new data
- If fewer than 3 new iterations, skip (not enough new data)

## Step 5: Update session-summary.md

Overwrite `.agent-memory/session-summary.md` with:

```markdown
# Last Session

*Date: {YYYY-MM-DD HH:MM}*
*Agent: Claude Code*

## What Was Done
- {bullet points of completed work, max 10 items}

## Open Items
- {anything left unfinished}
- {blockers encountered}

## Next Steps
1. {highest priority next action}
2. {second priority}
3. {third priority}

## Statistics
- Iterations: {n}
- Errors: {n}
- New Patterns: {n}
- Test Health: {score}/100
- Code Quality: {score}/100

## Active Warnings
- {high-confidence patterns, if any}
- {declining quality trends, if any}
```

**Keep it under 30 lines.**

## Step 6: Update user.md (Conditional)

Only update `.agent-memory/identity/user.md` if a clear, repeated signal was observed:
- User corrected the same behavior 3+ times
- User confirmed a non-obvious approach
- User expressed frustration with a specific style

**Do NOT update user.md for one-off corrections.**

## Step 7: Optional NotebookLM Sync

If a NotebookLM notebook exists for this project (check `.agent-memory/knowledge/notebook-registry.md`), optionally sync session learnings:
1. Use the `notebooklm` user-skill (Python API)
2. Only sync if 3+ meaningful learnings were extracted in Step 3
3. Skip if NotebookLM CLI is not installed

## Step 8: Suggest Git Commit (Optional)

If there are uncommitted changes:
1. Run `git status`
2. Suggest a conventional commit message (feat/fix/refactor/test/chore)
3. **Show the user** what would be committed
4. **Wait for confirmation** — never commit without explicit approval

---

# Step 9: Memory Maintenance (Optional)

Runs automatically if memory thresholds are exceeded, or when user explicitly requests "clean memory", "memory maintenance", etc. Skip entirely if no thresholds are exceeded and user didn't request it.

## Step 9.1: Assess Memory Health

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

## Step 9.2: JSON Integrity Check

For each JSON file:
1. Attempt to parse it
2. If parse fails: rename to `{file}.corrupt.bak`, create fresh with default (`[]` or `{}`), warn user
3. If parse succeeds: check for structural issues

## Step 9.3: Archive Old Data

**Thresholds:**
- `iteration-log.md` > 500 entries: keep newest 500, archive rest
- `errors.json` > 200 entries: keep newest 200, archive rest
- `code-reviews.json` > 100 entries: keep newest 100, archive rest
- `test-results.json` > 100 entries: keep newest 100, archive rest

Archive to `{filename}-archive-{YYYY-MM}.{ext}` in the same directory.

## Step 9.4: Prune Stale Patterns

Read `.agent-memory/patterns/patterns.json`:
1. Find patterns where `last_seen` is older than 90 days
2. Find patterns with `confidence < 0.3`
3. Move these to `patterns-archive-{YYYY-MM}.json`
4. Update `patterns.md` to reflect the pruned catalog

**Exception:** Never prune patterns with `skill_candidate: true`.

## Step 9.5: Compact Decisions

Archive decisions with `status: "superseded"` older than 90 days. Keep all `status: "active"` decisions.

## Step 9.6: Enforce Session Summary Length

If `.agent-memory/session-summary.md` exceeds 30 lines: compress to 30 lines, keeping date, top 5 bullets, all open items, top 3 next steps.

## Step 9.7: Compact Learnings

If `.agent-memory/learnings/learnings.md` exceeds 200 lines: keep last 12 months, archive older entries, deduplicate.

## Step 9.8: Memory Report

```
Memory Maintenance:
  JSON Integrity: {n}/{total} valid ({n} repaired)
  Archived: {n} iterations, {n} errors, {n} reviews
  Patterns pruned: {n} stale, {n} low-confidence
  Session summary: {compacted|ok} ({n} lines)
  Learnings: {compacted|ok} ({n} lines)
```

---

# Handoff Mode (Pre-Compression)

When triggered by context getting long or explicit handoff request, append to session-summary.md:

```markdown
## Handoff Context
- **Active task**: What was being worked on right now
- **Current state**: Where in the task (what's done, what's next)
- **Quality state**: Latest test/code scores
- **Active patterns**: Top 5 high-confidence patterns to watch
- **Open questions**: Decisions pending user input
```

## Error Handling

- If `iteration-log.md` is missing: create it, note "No previous iterations"
- If any JSON file has a parse error: rename to `{file}.corrupt.bak`, create fresh, warn user
- If `.agent-memory/` doesn't exist: suggest running `/agentic-os:init`

## What NOT to Do

- Do NOT modify `errors.json` (that's iteration-logger's job)
- Do NOT modify `patterns.json` directly (call pattern-extractor instead)
- Do NOT modify `decisions.json` (that's context-keeper's job)
- Do NOT write session-summary.md longer than 30 lines
- Do NOT commit without user confirmation
- Do NOT log trivial "learnings"
- Do NOT delete identity files (soul.md, user.md)
- Do NOT prune skill_candidate patterns
- Do NOT run memory maintenance during an active self-improve loop (check `improvements/state.json` in the plugin root — `status: "running"` means the loop is active)
