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

## Step 1: Determine Direction

From user intent:
- "pull" / "holen" / "importieren" → pull only
- "push" / "teilen" / "exportieren" → push only
- "sync" / "beides" / no direction → bidirectional (pull then push)

## Step 2: Ensure Global Memory Exists

Check `~/.claude-memory/global/` exists. If not, create:
- `patterns.json` → `[]`
- `learnings.json` → `[]`
- `projects.json` → `{"projects": []}`

## Step 3: Pull (if applicable)

1. Read project's stack from `.agent-memory/context/project-context.md`
2. Read `~/.claude-memory/global/patterns.json`
3. Filter by matching `stack_tags` (only pull relevant patterns)
4. Only pull patterns with `confidence >= 0.5`
5. Merge into local `patterns.json`:
   - Same `id` → keep higher confidence, merge `source_projects`
   - Same description (fuzzy) but different `id` → deduplicate
   - Never overwrite local with lower-confidence global

## Step 4: Push (if applicable)

1. Read local `.agent-memory/patterns/patterns.json`
2. Filter: only push patterns with `confidence >= 0.6`
3. Merge into `~/.claude-memory/global/patterns.json`:
   - Increment `occurrences` on merge
   - Merge `source_projects` arrays
   - Patterns with `occurrences >= 3` across projects get confidence boost (+0.1)
4. Push generalizable learnings from `.agent-memory/learnings/learnings.md` to global

## Step 5: Update Registry

Update `~/.claude-memory/global/projects.json` with:
- Project name and path
- Last sync timestamp
- Pattern count

## Step 6: Report

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
