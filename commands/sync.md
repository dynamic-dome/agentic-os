---
description: Sync learnings between local project memory and global cross-project memory
argument-hint: "[--pull | --push | --both]"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
---

# Sync Cross-Project Memory

Synchronize patterns, learnings, and anti-patterns between the local `.agent-memory/` and the global `~/.claude-memory/global/`.

## Behavior

**Default (no flag or `--both`):** Pull global patterns into local, then push local patterns to global.

### --pull
1. Read `~/.claude-memory/global/patterns.json`
2. Read `.agent-memory/patterns/patterns.json`
3. Merge global patterns into local (deduplicate by pattern ID)
4. Write merged result to `.agent-memory/patterns/patterns.json`
5. Update `.agent-memory/patterns/patterns.md` with any new entries
6. Report what was pulled

### --push
1. Read `.agent-memory/patterns/patterns.json`
2. Read `.agent-memory/learnings/learnings.md`
3. Read `~/.claude-memory/global/patterns.json`
4. Read `~/.claude-memory/global/learnings.json`
5. Merge local patterns into global (deduplicate, tag with project name)
6. Write merged results to global files
7. Update `~/.claude-memory/global/projects.json` with latest sync timestamp
8. Report what was pushed

### Conflict Resolution
- If same pattern ID exists in both: keep the one with higher confidence score
- If same pattern exists but different severity: keep the stricter one
- Always preserve project-specific context tags
