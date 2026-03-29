---
name: run-loop
description: Start the self-improvement loop manually. Runs up to 4 iterations of research, analysis, improvement, and validation on plugin skills.
user_invocable: true
---

# Self-Improve Loop

Start the self-improvement loop for plugin skills.

## Instructions

Invoke the `agentic-os:loop-orchestrator` skill to run the full improvement cycle.

The orchestrator will:
1. Check git state and baseline tests
2. Run up to 4 sequential iterations
3. Each iteration: research → analysis → improvement → validation
4. Circuit breaker stops on diminishing returns or rollback
5. Single git push after all iterations
6. Output summary table

Use the Skill tool:
```
Skill: agentic-os:loop-orchestrator
```
