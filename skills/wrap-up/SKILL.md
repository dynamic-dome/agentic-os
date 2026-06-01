---
name: wrap-up
description: |
  Wraps up a coding session — summarizes what was done, extracts learnings,
  updates the session summary, suggests a git commit. Use when you are
  done working for now, when context is getting long and needs a handoff,
  or before switching to a different project. Ensures no progress is lost
  and the next session can pick up seamlessly.

  Trigger phrases (session-specific only):
  "wrap up", "end session", "session end", "save session", "close session",
  "finish for today", "summarize session", "save context",
  "session handoff", "agent handoff", "I'm done for today",
  "that's it for today".

  <example>
  Context: User is done for the day
  user: "done for today, wrap up"
  assistant: "Session Wrap-Up: 5 iterations completed, 2 bugs fixed. Session summary updated."
  <commentary>
  User ends session, trigger wrap-up to save context for next session.
  </commentary>
  </example>

  Note on scope: Memory maintenance (clean memory, memory health, prune patterns,
  archive old data) was previously listed here but moved to the dedicated
  `memory-maintenance` skill in v3.x. This skill no longer matches generic
  "give me a summary" — that phrase is too broad and was matching unrelated
  contexts (article summaries, code summaries).
user_invocable: true
metadata:
  author: agentic-os
  version: '3.1'
  part-of: agentic-os
  layer: core
  trigger-audit-2026-04-30:
    removed:
      - "give me a summary (too broad — matched non-session contexts)"
      - "clean memory (owned by memory-maintenance skill)"
      - "memory cleanup (owned by memory-maintenance)"
      - "archive old data (owned by memory-maintenance)"
      - "memory health (owned by memory-maintenance)"
      - "compact memory (owned by memory-maintenance)"
      - "prune patterns (owned by memory-maintenance)"
      - "memory maintenance (owned by memory-maintenance)"
---

# Session Wrap-Up

End-of-session sequence. Summarizes work, extracts learnings, prepares for next session. Optionally runs memory maintenance.

## When to Use

- At the end of every coding session
- When context window is getting long (pre-compression)
- User says "wrap up", "end session", etc.
- For memory maintenance (clean memory, prune patterns, integrity check):
  invoke the dedicated `memory-maintenance` skill instead — wrap-up no longer
  owns those triggers as of v3.1 (2026-04-30 trigger audit).
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

### 3a: Dedup Check

Before adding a new learning, read `.agent-memory/learnings/learnings.json` and check for duplicates:

1. Normalize the new learning text: lowercase, strip punctuation, collapse whitespace
2. Tokenize into a word set
3. Compare against each existing entry using Jaccard similarity: `|intersection| / |union|`
4. **Threshold: similarity >= 0.6** → treat as duplicate
5. If duplicate found: update `last_relevant` to today's date on the existing entry, skip creation
6. If new: proceed to 3b

### 3b: Score and Append

For each new learning, assign metadata:

- **importance** (1-5):
  - 5 = would prevent data loss or security issue
  - 4 = would prevent a multi-attempt debugging session
  - 3 = non-obvious codebase/tool behavior
  - 2 = workflow optimization
  - 1 = trivia / edge case unlikely to recur
- **tags**: extract from text (e.g., "windows", "git", "python", "agentic-os", "memory")
- **layer**: default `"short-term"` (promoted to `"long-term"` after 30 days if still relevant)

Append to `.agent-memory/learnings/learnings.json`:

```json
{
  "id": "L{next_number}",
  "date": "{YYYY-MM-DD}",
  "text": "{insight with context}",
  "importance": 3,
  "tags": ["tag1", "tag2"],
  "layer": "short-term",
  "superseded_by": null,
  "last_relevant": "{YYYY-MM-DD}"
}
```

### 3c: Regenerate Markdown View

After writing to `learnings.json`, regenerate `learnings.md` from the JSON:

```markdown
# Learnings

*Auto-generated from learnings.json — do not edit directly.*

## {date}

- [{id}] ({'*' * importance}) {text}
```

Group entries by date, sorted chronologically.

## Step 3.5: Layer Lifecycle Review

If `learnings/learnings.json` exists, review layer assignments:

1. **Short-term → Long-term promotion**: For entries with `layer: "short-term"` older than 30 days:
   - If `last_relevant` was updated within the last 30 days → promote to `"long-term"`
   - If `last_relevant` is older than 30 days → mark as archive candidate (set `layer: "archive-candidate"`)
2. **Working memory consumption**: Read `working/current-session.json` if it exists:
   - Review each `learnings_draft` entry against the dedup check from Step 3a
   - Promote worthy drafts to `learnings.json` with `layer: "short-term"`
   - Discard trivial drafts
   - Reset `working/current-session.json` (it will be recreated at next session start)
3. **Superseded entries**: If a new learning contradicts an older one, set `superseded_by` on the older entry pointing to the new one's ID

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

## Step 7.5: Obsidian Wiki Sync (Conditional)

Sync session results to the Obsidian Wiki. This step **delegates** to the `obsidian-sync` skill — it does NOT duplicate its logic.

### Trigger Conditions (ALL must be true)
1. `.agent-memory/config.json` exists AND `sync_enabled: true`
2. At least ONE of:
   - >= `session_note_threshold` iterations logged today (default: 2)
   - meaningful_learning extracted in Step 3 (importance >= 4)
   - new architecture-decision or status-change in decisions.json

### Execution
If conditions met: invoke the `obsidian-sync` skill.

The obsidian-sync skill handles all wiki writes (session-note, entity update, rolling synthesis, pattern promotion status, index/log). Do NOT replicate any of its steps here.

### If conditions NOT met
Skip silently. Output nothing about wiki sync.

### Error Handling
If obsidian-sync fails: **warn and continue**. Never let wiki sync failure block wrap-up. Output: "Wiki sync failed: {reason}. Session data is safe in .agent-memory/."

## Step 7.6: Sharepoint-Push-Vermerk (Cross-Device)

If this session touched the Google-Drive Sharepoint (new/changed files under `G:\Meine Ablage\dynamic-AI\dynamic_sharepoint`):

1. **Frontmatter-check** every new MD file (`created` / `agent` / `purpose` / `status` / `source_path` — Sharepoint Manifest v1.0 §4).
2. **Hygiene-sweep**: no stackdumps, `.git`, `node_modules`, or `.env` dragged in (§7).
3. **INDEX.md** update if a new package was added.
4. Write **one** delta-handoff: `01_HANDOFFS/YYYY-MM-DD-from-claude-code-to-owner-session-sharepoint-delta.md`.
5. Add one line to the central handoff `C:\Users\domes\AI\session-summary.md`: `Sharepoint touched: yes, delta: <path>`.

If **not touched**: add only the line `Sharepoint unchanged this session` to the central handoff (`C:\Users\domes\AI\session-summary.md`). Do NOT write an empty handoff.

If the Sharepoint path is not mounted: skip silently.

## Step 8: Suggest Git Commit (Optional)

If there are uncommitted changes:
1. Run `git status`
2. Suggest a conventional commit message (feat/fix/refactor/test/chore)
3. **Show the user** what would be committed
4. **Wait for confirmation** — never commit without explicit approval

---

# Step 9: Memory Maintenance (Delegated)

Memory maintenance is a separate skill: `memory-maintenance`.

Wrap-up does NOT perform maintenance itself. It only decides whether to invoke the dedicated skill:

- If the user explicitly asked for it ("clean memory", "memory cleanup", "prune patterns", etc.): invoke `memory-maintenance` after Step 8.
- Otherwise check the quick threshold signal before invoking:
  - `iterations/iteration-log.md` > 100 entries
  - `iterations/errors.json` > 50 entries
  - `learnings/learnings.json` > 100 entries
  - `patterns/patterns.json` contains entries with `last_seen` older than 60 days
  - `session-summary.md` > 30 lines
  - `learnings/learnings.md` > 200 lines
- If none of the above apply: skip entirely. End after Step 8.

When invoking, hand off cleanly — `memory-maintenance` owns its own report and error handling; wrap-up should not duplicate that logic.

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
