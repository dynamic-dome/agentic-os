---
name: context-keeper
description: >
  Maintains the living project context: tech stack, architecture decisions,
  dependencies, constraints, and current project status. Called whenever an
  important decision is made or the architecture changes. Enables full context
  restoration across session switches.
  Trigger phrases: "kontext aktualisieren", "entscheidung festhalten",
  "update context", "warum haben wir X gewaehlt", "projektstand aktualisieren",
  "decision record", "ADR erstellen", "stack change", "neue dependency",
  "why did we choose X".
user_invocable: true
---

# Context Keeper

Maintain `.agent-memory/context/project-context.md` and `.agent-memory/context/decisions.json`.

## When to Use

- Architecture decision made (new library, pattern choice, trade-off)
- Tech stack change (new dependency, framework swap, version upgrade)
- Constraint discovered (performance limit, API restriction, compliance rule)
- User asks "why did we choose X?" (retrieval mode)
- Project status changes significantly

## Dual-File Responsibility

| File | Mode | Purpose |
|------|------|---------|
| `project-context.md` | Overwrite | Living document — always reflects current state |
| `decisions.json` | Append-only | Decision log — never delete, only supersede |

## Step 1: Classify the Update

Determine the type:

| Type | Description | Target |
|------|-------------|--------|
| `stack-change` | New/removed technology | project-context.md |
| `architecture-decision` | Design choice with alternatives | Both files |
| `constraint-update` | New limitation or requirement | project-context.md |
| `dependency-note` | New dependency with rationale | project-context.md |
| `status-update` | Project milestone or phase change | project-context.md |

## Step 2: Update project-context.md

Read the current file, then overwrite with updated content. Maintain this structure:

```markdown
# Project Context

*Last updated: {date}*

## Project
{project name} — {one-line description}

## Tech Stack
- **Language:** {e.g., Python 3.11}
- **Framework:** {e.g., FastAPI}
- **Database:** {e.g., PostgreSQL 15}
- **Testing:** {e.g., pytest + coverage}
- **Build:** {e.g., Docker + GitHub Actions}

## Architecture
{2-3 sentences describing the architecture}

## Key Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| {name} | {version} | {why it's needed} |

## Constraints
- {performance, compliance, API limits, etc.}

## Current Status
- **Phase:** {development/testing/production}
- **Priority:** {what's being worked on now}

## Open Questions
- {decisions pending, unknowns}
```

## Step 3: Record Decision (if applicable)

For `architecture-decision` and `stack-change` types, append to `decisions.json`:

```json
{
  "id": "D{n}",
  "date": "YYYY-MM-DD",
  "type": "architecture-decision | stack-change | constraint-update",
  "title": "Short decision title",
  "status": "active | superseded | reverted",
  "context": "Why this decision was needed",
  "options_considered": [
    {"option": "Option A", "pros": ["..."], "cons": ["..."]},
    {"option": "Option B", "pros": ["..."], "cons": ["..."]}
  ],
  "decision": "What was chosen and why",
  "consequences": "Expected impact",
  "supersedes": null,
  "tags": ["architecture", "database"]
}
```

Read `decisions.json` first to determine the next `id` number.

If this decision supersedes a previous one, set `supersedes: "D{old_id}"` and update the old entry's `status` to `"superseded"`.

## Step 4: Consistency Checks

After updating, verify:

1. **Contradiction check**: Does the new decision contradict any `active` decision in `decisions.json`? If yes, flag it and ask the user to resolve.

2. **Constraint check**: Does the new decision violate any listed constraint in `project-context.md`? If yes, flag it.

3. **Open questions**: Does this decision resolve any open question? If yes, remove it from the Open Questions section.

4. **Tag consistency**: Are the tags used consistent with existing tags in `decisions.json`? Reuse existing tags.

## Retrieval Mode

When the user asks "Why did we choose X?" or "What was the rationale for Y?":

1. Search `decisions.json` for matching entries (search `title`, `decision`, `tags`)
2. Filter to `status: "active"` entries (unless user asks about historical decisions)
3. Present the decision with its context, options considered, and consequences
4. If no match found, say so and offer to search `project-context.md`

## Step 5: Confirm

Output:

```
Context updated: {type} — {title}
  File: {which file(s) were updated}
  Decision: D{n} recorded (if applicable)

  Resolved questions: {if any}
  Warnings: {contradictions or constraint violations, if any}
```

## What NOT to Do

- Do NOT delete entries from decisions.json (set status to "superseded" instead)
- Do NOT make project-context.md longer than ~60 lines
- Do NOT record trivial decisions (choosing a variable name is not an ADR)
- Do NOT modify files outside of context/ directory
- Do NOT guess the tech stack — read actual config files or ask the user
