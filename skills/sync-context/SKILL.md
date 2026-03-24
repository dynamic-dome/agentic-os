---
name: sync-context
description: >
  Shares knowledge between your projects — pull useful patterns from other
  projects into this one, or push what you learned here for reuse elsewhere.
  Use when starting a similar project and wanting to reuse past learnings,
  when you solved something that would help in other codebases, or to
  discover what patterns exist across all your projects. Includes interactive
  project discovery so you can see what is available before syncing.
  NOT auto-triggered — manual only.
  Trigger phrases: "sync memory", "pull patterns", "push learnings",
  "cross-project sync", "global memory", "sync context",
  "pull global patterns", "share knowledge", "what patterns exist in other projects",
  "which patterns can I import", "transfer knowledge".
user_invocable: true
---

# Cross-Project Sync (Optional, Manual Only)

Bidirectional sync between local `.agent-memory/` and `~/.claude-memory/global/`.

**This skill is never auto-triggered.** It runs only when the user explicitly requests it.

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

## Step 1: Discover Available Projects

Before syncing, show the user what is available:

1. Check if `~/.claude-memory/global/projects.json` exists
2. If it exists, read it and display:

```
Available Projects for Sync:
  1. project-alpha (15 patterns, last sync: 2025-01-15)
  2. project-beta (8 patterns, last sync: 2025-01-10)
  3. project-gamma (22 patterns, last sync: 2025-01-08)

Current project: {name} ({n} local patterns)
```

3. Ask the user (as plain text output):
   "Which projects should I sync with? Options: [list each project by number], or 'all' for all projects."
   Wait for the user's response before proceeding.

If `projects.json` does not exist or has fewer than 2 projects, inform the user:
"Not enough projects for cross-project sync yet. Push your local patterns first to start building the global knowledge base."

## Step 2: Determine Direction

From user intent:
- "pull" / "holen" / "importieren" → pull only
- "push" / "teilen" / "exportieren" → push only
- "sync" / "beides" / no direction → bidirectional (pull then push)
- "--list" / "was gibt es" / "show projects" → discovery only (Step 1), then stop

## Step 3: Ensure Global Memory Exists

Check `~/.claude-memory/global/` exists. If not, create:
- `patterns.json` → `[]`
- `learnings.json` → `[]`
- `projects.json` → `{"projects": []}`

## Step 4: Pull (if applicable)

1. Read project's stack from `.agent-memory/context/project-context.md`
2. Read `~/.claude-memory/global/patterns.json`
3. Filter by matching `stack_tags` (only pull relevant patterns)
4. Only pull patterns with `confidence >= 0.5`
5. Merge into local `patterns.json`:
   - Same `id` → keep higher confidence, merge `source_projects`
   - Same description (fuzzy) but different `id` → deduplicate
   - Never overwrite local with lower-confidence global

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

## Examples

### Example 1: Pull patterns from another project
User: "sync memory from project-alpha"
1. Discovery shows: "project-alpha (15 patterns, stack: python/fastapi)"
2. Stack-match filter: 8 of 15 patterns match current stack
3. Confidence filter: 6 of 8 above threshold (0.5)
4. Result: "Pulled 6 patterns from project-alpha"

### Example 2: Push learnings globally
User: "push learnings to global"
1. Reads local patterns.json: 12 patterns total
2. Confidence filter: 9 of 12 above push threshold (0.6)
3. Dedup: 2 already exist globally
4. Result: "Pushed 7 new patterns to global store"

## What NOT to Do

- Do NOT auto-trigger this skill from hooks or other skills
- Do NOT sync patterns with confidence < 0.5 (pull) or < 0.6 (push)
- Do NOT overwrite local patterns with lower-confidence global ones
- Do NOT sync if fewer than 2 projects exist globally (nothing to cross-pollinate)
