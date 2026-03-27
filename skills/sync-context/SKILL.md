---
name: sync-context
description: >
  Manual cross-project sync between local .agent-memory/ and global
  ~/.claude-memory/global/. Pulls relevant patterns from other projects,
  pushes local learnings for reuse. NOT auto-triggered — use only when
  explicitly requested.
  Trigger phrases: "sync memory", "pull patterns", "push learnings",
  "cross-project sync", "global memory", "Kontext synchronisieren",
  "globale Patterns holen", "Wissen teilen".
user_invocable: true
metadata:
  author: agentic-os
  version: '1.0'
  part-of: agentic-os
  layer: utility
---

# Cross-Project Sync (Optional, Manual Only)

Bidirectional sync between local `.agent-memory/` and `~/.claude-memory/global/`.

**This skill is never auto-triggered.** It runs only when the user explicitly requests it.

## Prerequisites (Auto-Setup)

Before any sync operation, ensure the global memory infrastructure exists.
This MUST run automatically — do not require the user to set it up manually.

**Required structure:**
```
~/.claude-memory/global/
├── patterns.json    (initialize as [])
├── learnings.json   (initialize as [])
└── projects.json    (initialize as {"projects": []})
```

**Auto-creation logic (run at skill start, before Step 1):**
1. Check if `~/.claude-memory/global/` exists
2. If not, create the directory and all three JSON files with their defaults
3. If directory exists but files are missing, create only the missing files
4. If directory creation fails (permissions) → warn user with exact error, abort gracefully
5. For each existing JSON file, attempt `JSON.parse`:
   - If corrupt (parse fails) → rename to `<filename>.corrupt.bak`, reinitialize with default, warn user
   - Example: `patterns.json` fails → move to `patterns.json.corrupt.bak`, create fresh `[]`

## When to Use

- User wants to import patterns from other projects
- User wants to share this project's learnings globally
- Switching between projects and wanting accumulated knowledge
- User has 3+ active projects and wants to leverage cross-project patterns

## Architecture

```
Project A (.agent-memory/)  ──push──>  ~/.claude-memory/global/  <──push──  Project B
                            <──pull──                            ──pull──>
```

## Step 1: Check Minimum Project Count

Before any sync, verify there are at least 2 projects registered globally:

1. Read `~/.claude-memory/global/projects.json` (create if missing — see Prerequisites)
2. Count entries in the `projects` array
3. If fewer than 2 projects exist → abort with: "SYNC SKIPPED: cross-project sync requires at least 2 projects. Currently only {n} project(s) registered. Run sync again after a second project has been set up."

## Step 2: Determine Direction

From user intent:
- "pull" / "holen" / "importieren" → pull only
- "push" / "teilen" / "exportieren" → push only
- "sync" / "beides" / no direction → bidirectional (pull then push)

## Step 3: Ensure Global Memory Exists (with Error Handling)

Run the auto-setup from Prerequisites:
1. Create `~/.claude-memory/global/` if missing
2. For each of `patterns.json`, `learnings.json`, `projects.json`:
   - If missing → create with default (`[]`, `[]`, `{"projects": []}`)
   - If exists → validate JSON parse
   - If corrupt → backup as `<file>.corrupt.bak`, reinitialize, warn user:
     `"WARNING: ~/.claude-memory/global/<file> was corrupt. Backed up as <file>.corrupt.bak and reinitialized."`
3. If `mkdir` or `write` fails → print error, abort:
   `"ERROR: Cannot create global memory dir: <error>. Sync aborted. Check permissions on ~/.claude-memory/."`

## Step 4: Pull (if applicable)

1. Read project's stack from `.agent-memory/context/project-context.md`
2. Read `~/.claude-memory/global/patterns.json`
3. Filter by matching `stack_tags` (only pull relevant patterns)
4. Only pull patterns with `confidence >= 0.5`
5. Merge into local `patterns.json`:
   - Same `id` → keep higher confidence, merge `source_projects`
   - Same description (fuzzy) but different `id` → deduplicate
   - Never overwrite local with lower-confidence global
   - On any merge conflict (same id, different content) → keep higher confidence version, log conflict in report (Step 6)

## Step 5: Push (if applicable)

1. Read local `.agent-memory/patterns/patterns.json`
2. Filter: only push patterns with `confidence >= 0.6`
3. Merge into `~/.claude-memory/global/patterns.json`:
   - Increment `occurrences` on merge
   - Merge `source_projects` arrays
   - Patterns with `occurrences >= 3` across projects get confidence boost (+0.1)
4. Push generalizable learnings from `.agent-memory/learnings/learnings.md` to global

## Step 6: Update Registry

Update `~/.claude-memory/global/projects.json` with:
- Project name and path
- Last sync timestamp
- Pattern count

## Step 7: Report

```
Cross-Project Sync Complete:
  Direction: {pull|push|bidirectional}
  Pulled: {n} patterns (from {n} projects)
  Pushed: {n} patterns, {n} learnings
  Skipped: {n} (below threshold)
  Conflicts: {n} (resolved by higher confidence)
```

## What NOT to Do

- Do NOT auto-trigger this skill from hooks or other skills
- Do NOT sync patterns with confidence < 0.5 (pull) or < 0.6 (push)
- Do NOT overwrite local patterns with lower-confidence global ones
- Do NOT sync if fewer than 2 projects exist globally (nothing to cross-pollinate)
