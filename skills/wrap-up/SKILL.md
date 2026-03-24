---
name: wrap-up
description: |
  Wraps up a coding session — summarizes what was done, extracts learnings,
  updates the session summary, and suggests a git commit. Use when you are
  done working for now, when context is getting long and needs a handoff,
  or before switching to a different project. Ensures no progress is lost
  and the next session can pick up seamlessly.
  Trigger phrases: "wrap up", "end session", "session end", "save session",
  "close session", "Session beenden", "Zusammenfassung", "fertig fuer heute",
  "kontext sichern", "session handoff", "agent handoff",
  "ich hoer jetzt auf", "schluss fuer heute", "mach mal ne zusammenfassung".

  <example>
  Context: User is done for the day
  user: "fertig fuer heute, wrap up"
  assistant: "Session Wrap-Up: 5 Iterationen, 2 Fehler behoben. Session-Summary aktualisiert."
  <commentary>
  User ends session, trigger wrap-up to save context for next session.
  </commentary>
  </example>
user_invocable: true
---

# Session Wrap-Up

End-of-session sequence. Summarizes work, extracts learnings, prepares for next session.

## When to Use

- At the end of every coding session
- When context window is getting long (pre-compression)
- User says "wrap up", "session beenden", etc.
- Note: this skill is manual-only — no hook triggers it automatically. The SessionEnd hook does a lightweight session-summary update, but the full wrap-up (learnings, patterns, commit suggestion) requires explicit user invocation.

## Step 1: Gather Session Data

Collect from the current session:

1. **Iteration log**: Read `.agent-memory/iterations/iteration-log.md` — find entries from today's date
2. **Git changes**: Run `git diff --stat` and `git log --oneline -5` (if git available)
3. **Test status**: Read `.agent-memory/quality/test-results.json` — latest entry
4. **Code quality**: Read `.agent-memory/quality/code-reviews.json` — latest entry
5. **Errors this session**: Read `.agent-memory/iterations/errors.json` — entries from today

If iteration-log.md is empty or has no entries from today: note "Keine Iterationen in dieser Session" and proceed to Step 5 (skip Steps 2-4).

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

**Do NOT log trivial facts** like "file X exists" or "function Y takes 2 arguments". Only log insights that a future session would genuinely benefit from knowing.

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

**Keep it under 30 lines.** This file is read at every session start — conciseness is critical.

## Step 6: Update user.md (Conditional)

Only update `.agent-memory/identity/user.md` if a clear, repeated signal was observed:

- User corrected the same behavior 3+ times → record the preference
- User confirmed a non-obvious approach → record as validated pattern
- User expressed frustration with a specific style → record as anti-preference

**Do NOT update user.md for one-off corrections.** Wait for repeated signals.

## Step 7: Suggest Git Commit (Optional)

If there are uncommitted changes:

1. Run `git status` to see what's staged/unstaged
2. Suggest a conventional commit message based on the iteration types:
   - `feat:` for features
   - `fix:` for bugfixes
   - `refactor:` for refactors
   - `test:` for test changes
   - `chore:` for config/tooling
3. **Show the user** what would be committed
4. **Wait for confirmation** — never commit without explicit approval

## Handoff Mode (Pre-Compression)

When triggered by context getting long (PreCompact) or explicit handoff request, add extra context to session-summary.md:

Append after the standard summary:

```markdown
## Handoff Context
- **Active task**: What was being worked on right now
- **Current state**: Where in the task (what's done, what's next)
- **Quality state**: Latest test/code scores
- **Active patterns**: Top 5 high-confidence patterns to watch
- **Open questions**: Decisions pending user input
```

This enables the next session's bootstrap to restore full context.

## Error Handling

- If `iteration-log.md` is missing: create it, note "No previous iterations"
- If any JSON file has a parse error: rename to `{file}.corrupt.bak`, create fresh with `[]`, warn user
- If `.agent-memory/` doesn't exist: suggest running `/agentic-os:init`
- If `session-summary.md` is missing: create it fresh

## What NOT to Do

- Do NOT modify `errors.json` (that's iteration-logger's job)
- Do NOT modify `patterns.json` directly (call pattern-extractor instead)
- Do NOT modify `decisions.json` (that's context-keeper's job)
- Do NOT write session-summary.md longer than 30 lines
- Do NOT commit without user confirmation
- Do NOT log trivial "learnings" that clutter the knowledge base
