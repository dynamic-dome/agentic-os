---
name: status
description: Show Agentic OS memory system status and health
allowed_tools: ["Read", "Glob", "Bash"]
---

# Agentic OS Status

Display the current state of the memory system.

## What to show

1. **Memory System Health:**
   - Does `.agent-memory/` exist? List missing directories/files
   - Last session summary (first 5 lines of `session-summary.md`)
   - Quality scores from `quality-score.json`

2. **Statistics:**
   - Total iterations logged (count entries in `iterations/iteration-log.md`)
   - Total patterns (count in `patterns/patterns.json`)
   - Total errors (count in `iterations/errors.json`)
   - Total decisions (count in `context/decisions.json`)
   - Total code reviews (count in `quality/code-reviews.json`)

3. **Self-Improvement Loop:**
   - Read `improvements/state.json` if it exists
   - Show: current iteration, last run, status (idle/running), total fixes
   - Show convergence state (count consecutive diminishing-returns in history)
   - Quality score trend (last 5 iterations)
   - List scheduled tasks via `mcp__scheduled-tasks__list_scheduled_tasks` if available

4. **Format** as a compact table.
