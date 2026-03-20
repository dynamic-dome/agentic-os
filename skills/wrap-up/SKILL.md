---
name: wrap-up
description: >
  Performs session wrap-up: summarizes work done, extracts learnings,
  syncs to global memory, updates session-summary.md.
  Trigger phrases: "wrap up", "end session", "session end",
  "save session", "close session", "Session beenden", "Zusammenfassung",
  "fertig fuer heute".

metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: core
---

# Session Wrap-Up

## When to Use

At the end of every coding session, or when context is getting long.

## Sequence

1. **Summarize iterations** — read `iteration-log.md` for this session's entries
2. **Extract patterns** — run pattern extraction on new iterations
3. **Update user.md** — append any observed feedback patterns or error tendencies
4. **Update session-summary.md** with:

```markdown
# Letzte Session

*Datum: {date}*

## Was wurde gemacht
- {bullet points of completed work}

## Offene Punkte
- {anything left unfinished}

## Nächste Schritte
1. {prioritized next actions}

## Statistik
- Iterationen: {count}
- Fehler: {count}
- Neue Patterns: {count}
```

5. **Sync to global** — push new patterns/learnings to `~/.claude-memory/global/`
6. **Update quality-score.json** if tests were run
7. **Suggest git commit** with conventional commit message based on changes

## Important

- Keep session-summary.md concise — it's read at every session start
- Focus on actionable next steps, not detailed history
- Global sync should only push patterns with confidence >= 0.6

## Error Handling

- If `iteration-log.md` is empty or missing: note "Keine Iterationen in dieser Session", skip pattern extraction
- If any JSON file is corrupt (parse error): rename to `<file>.corrupt.bak`, create fresh with defaults, warn user
- If global memory path is unreachable: skip sync, log warning, continue with local wrap-up
- If `session-summary.md` is missing: create it fresh instead of appending
