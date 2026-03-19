---
name: session-bootstrap
description: >
  Bootstraps full project context at session start. Reads session-summary,
  soul, user profile, patterns, and global learnings. Use at the beginning
  of every coding session.
  Trigger phrases: "start session", "session bootstrap", "session start",
  "begin work", "what was I working on".

metadata:
  author: agentic-os
  version: '3.0'
  layer: system
---

# Session Bootstrap

## When to Use

At the start of every coding session to restore full context.

## Sequence

1. **Read session-summary.md** — what happened last session, next steps
2. **Read soul.md** — agent behavior and priorities
3. **Read user.md** — user preferences and work style
4. **Read patterns.md** — known patterns and anti-patterns to watch for
5. **Check global memory** — pull any new cross-project patterns via sync
6. **Read project-context.md** — tech stack, architecture, constraints
7. **Check quality-score.json** — current test/code health
8. **Output a brief status** to the user:
   - Last session summary (3 lines max)
   - Open next steps
   - Any quality alerts (test failures, score drops)
   - New global patterns pulled (if any)

## Important

- Do NOT dump all file contents to the user — summarize concisely
- If session-summary.md says "System frisch initialisiert", prompt user to set up project context
- If quality score shows declining trend, mention it proactively
