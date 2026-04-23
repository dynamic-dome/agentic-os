---
name: log
description: "Log a coding iteration (feature, bugfix, refactor) to the memory system with structured tags and error tracking."
user_invocable: true
arguments:
  - name: summary
    description: "Short description of what was done (optional, will be asked interactively if omitted)"
    required: false
---

# Log Iteration

Quickly log the current iteration to the memory system.

## Instructions

Invoke the `agentic-os:iteration-logger` skill. If a summary argument was provided, pass it as context.

Use the Skill tool:
```
Skill: agentic-os:iteration-logger
```
