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
   - Quality scores from `quality-score.json`

2. **Statistics:**
   - Total iterations logged (count entries in `errors.json`)
   - Total patterns (count in `patterns.json`)
   - Total decisions (count active in `decisions.json`)
   - Generated skills (list directories in `generated-skills/`)

3. **Scaling Warnings:**
   - `errors.json` > 200 entries → warn
   - `decisions.json` > 50 active → warn
   - `patterns.json` > 30 entries → warn

4. **Format** as a compact table.
