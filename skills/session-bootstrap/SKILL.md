---
name: session-bootstrap
description: >
  Bootstraps full project context at session start. Reads session-summary,
  identity files, patterns, and quality scores. Performs health checks on
  the memory system. Produces a compact briefing with warnings and next steps.
  Use at the beginning of every coding session.
  Trigger phrases: "start session", "session bootstrap", "session start",
  "begin work", "what was I working on", "Session starten", "Briefing laden",
  "woran habe ich gearbeitet", "wo waren wir", "was wissen wir",
  "context restore", "neue session", "Projektstand".
---

# Session Bootstrap

Restore full project context at the start of every coding session.

## When to Use

- Start of every new coding session (auto-triggered by SessionStart hook)
- After context-window reset or long pause
- User asks "Wo waren wir?" or "Projektstand?"
- Agent switch (Claude Code <-> other)

**Note:** The SessionStart hook now handles Auto-Init automatically. If `.agent-memory/` doesn't exist, the hook creates it before this skill runs. You should never need to suggest `/agentic-os:init` manually anymore.

## Step 1: Check Memory System Exists

Read `.agent-memory/session-summary.md`:

- If `.agent-memory/` does not exist → this should not happen (SessionStart hook auto-creates it). If it does, output "Memory system not found. This is unexpected — the SessionStart hook should have created it. Try restarting the session." and stop.
- If it exists but `session-summary.md` is missing → note "Keine vorherige Session gefunden", continue with other files.

## Step 2: Load Knowledge Files

Read files in this priority order. Skip any that don't exist:

1. **`session-summary.md`** — last session's work, open items, next steps
2. **`identity/soul.md`** — agent behavior settings, guard rails
3. **`identity/user.md`** — user preferences and work style
4. **`context/project-context.md`** — tech stack, architecture, constraints
5. **`patterns/patterns.md`** — known patterns and anti-patterns (scan for high-confidence only)
6. **`quality/quality-score.json`** — test health + code quality trends
7. **`iterations/errors.json`** — last 5 entries only (tail, not full load)

Apply identity settings from `soul.md` silently (communication style, guard rails).

## Step 3: Health Checks

Validate the memory system integrity:

### File Existence Check
Verify these core files exist:
- `session-summary.md`
- `identity/soul.md`
- `identity/user.md`
- `context/project-context.md`
- `iterations/iteration-log.md`
- `iterations/errors.json`
- `patterns/patterns.json`
- `quality/quality-score.json`

Missing files → warn user, suggest which skill creates them.

### JSON Validity Check
For each JSON file loaded: if parse fails → rename to `{file}.corrupt.bak`, create fresh with default (`[]` or `{}`), warn user.

### Scaling Guards
- `errors.json` > 200 entries → warn: "Error log is large ({n} entries). Consider archiving with iteration-logger."
- `decisions.json` > 50 active entries → warn: "Many active decisions ({n}). Review for superseded entries."
- `iteration-log.md` > 500 entries → warn: "Iteration log is very long. Archive recommended."

## Step 4: Produce Briefing

Output format (adapt content, keep structure concise):

```
SESSION BRIEFING — {project name}
{date}
---

LAST SESSION
  {2-3 lines from session-summary.md}
  Next steps: {numbered list from summary}

PROJECT STATUS
  {1-2 lines from project-context.md}
  Stack: {compact tech stack}

ACTIVE WARNINGS
  {high-confidence patterns (confidence >= 0.7, occurrences >= 3)}
  {last 3 unresolved errors}
  {quality score trends: improving/declining/stable}

STATISTICS
  Iterations: {n} | Patterns: {n} | Errors: {n}
  Test Health: {score}/100 | Code Quality: {score}/100

HEALTH
  {any missing files or scaling warnings}
---
```

**Keep the briefing under 15 lines.** Do NOT dump file contents — summarize.

## Step 5: Identify Active Warnings

Scan `patterns.json` for patterns that need attention:

- `confidence >= 0.7` AND `occurrences >= 3` → include in ACTIVE WARNINGS
- Anti-patterns whose `tags` overlap with the current project's stack → highlight
- Last 3 errors from `errors.json` that don't match any pattern → flag as "Potential new pattern"

## Step 6: Recommend Next Steps

Based on the briefing, suggest 2-3 concrete actions:

```
RECOMMENDED NEXT STEPS
  1. {from open items in last session summary}
  2. {from pattern warnings or quality alerts}
  3. {from project status}

  Ready to start?
```

## Error Handling

- Missing `session-summary.md`: "Keine vorherige Session gefunden" — continue
- Missing `soul.md` or `user.md`: trigger `/agentic-os:init` suggestion
- Corrupt JSON: backup + recreate + warn
- Missing `.agent-memory/`: suggest `/agentic-os:init`

## What NOT to Do

- Do NOT dump full file contents to the user
- Do NOT write to any files (bootstrap is read-only)
- Do NOT scan skill registries or build context matrices (Claude already knows available skills)
- Do NOT estimate token budgets (unreliable, leads to false warnings)
- Do NOT call sync-context (removed — no auto-sync on start)
- Do NOT take more than 15 seconds for the entire bootstrap
