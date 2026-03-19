---
name: sync-context
description: >
  Synchronizes patterns and learnings between local .agent-memory/ and
  global ~/.claude-memory/global/. Enables cross-project learning.
  Trigger phrases: "sync memory", "pull patterns", "push learnings",
  "cross-project sync", "global memory".

metadata:
  author: agentic-os
  version: '3.0'
  layer: system
---

# Cross-Project Sync

## When to Use

- At session start: pull global patterns relevant to this project's stack
- At session end: push new patterns/learnings to global
- When switching between projects and wanting accumulated knowledge

## Architecture

```
Project A (.agent-memory/)  ──push──►  ~/.claude-memory/global/  ◄──push──  Project B (.agent-memory/)
                            ◄──pull──                            ──pull──►
```

## Sync Logic

### Pattern Merging

Each pattern has:
```json
{
  "id": "P001",
  "type": "pattern|anti-pattern",
  "description": "...",
  "confidence": 0.0-1.0,
  "source_projects": ["dart-vision"],
  "stack_tags": ["python", "opencv"],
  "first_seen": "2026-03-19",
  "occurrences": 1
}
```

**Merge rules:**
- Same `id` → keep higher confidence, merge `source_projects`
- Same description but different `id` → deduplicate, assign single ID
- Increment `occurrences` on merge
- Patterns with `occurrences >= 3` across projects get `confidence` boost

### Stack-Filtered Pull

When pulling global patterns into a local project:
1. Read project's detected stack from `project-context.md`
2. Filter global patterns by matching `stack_tags`
3. Only pull patterns with `confidence >= 0.5`
4. Never overwrite local patterns with lower-confidence global ones

## Instructions

1. Determine sync direction from arguments (--pull, --push, --both)
2. Read both local and global pattern stores
3. Apply merge rules with deduplication
4. Write merged results atomically (tempfile → rename)
5. Update sync timestamp in `projects.json`
6. Report changes: added, updated, skipped
