---
description: Show Agentic OS memory system status and health
allowed-tools: ["Read", "Glob", "Bash"]
---

# Agentic OS Status

Display the current state of the memory system.

## What to show

1. **Memory System Health:**
   - Does `.agent-memory/` exist? List missing directories/files
   - Last session summary (first 5 lines of `session-summary.md`)
   - Quality score from `quality-score.json`
   - Health grade from `retrospectives/metrics.json`

2. **Statistics:**
   - Total iterations logged (count entries in `iteration-log.md`)
   - Total patterns (count in `patterns.json`)
   - Total errors (count in `errors.json`)
   - Total decisions (count in `decisions.json`)

3. **Global Memory:**
   - Does `~/.claude-memory/global/` exist?
   - How many projects registered?
   - Last sync timestamp

4. **Format** as a compact table.
