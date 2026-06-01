---
name: context-keeper
description: >
  Maintains the living project context: tech stack, architecture decisions,
  dependencies, constraints, and current project status. Called whenever an
  important decision is made or the architecture changes. Enables full context
  restoration across session switches.
  Trigger phrases: "update context", "record decision", "why did we choose X",
  "update project status", "decision record", "create ADR", "stack change",
  "new dependency".
user_invocable: true
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: core
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
| `project-context.md` | Overwrite | **Cache** — a compact agent view distilled from the project docs |
| `decisions.json` | Append-only | Decision log — never delete, only supersede |

## Source-of-Truth Hierarchy (IMPORTANT)

`project-context.md` is NOT the source of truth — the project docs are (Regel 13):

1. **`docs/PROJECT.md`** — name, status, stack, one-liner, open items, dependencies
2. **`docs/ARCHITECTURE.md`** — components, data flow, persistence
3. **`docs/CAPABILITIES.md`** — features/tools and their status
4. **`HOW-TO-USE.md`** — entry-point map
5. **`CLAUDE.md`** — project conventions

`project-context.md` is a **cache**: a compact distillation of those docs for fast
agent restore. When docs and cache disagree, the **docs win** — refresh the cache
from them, never treat the cache as truth. Runtime-only knowledge that is not yet in
the docs (a fresh decision, a just-discovered constraint) may live in the cache until
it is promoted into the docs.

## Step 1: Classify the Update

Determine the type:

| Type | Description | Target |
|------|-------------|--------|
| `stack-change` | New/removed technology | project-context.md |
| `architecture-decision` | Design choice with alternatives | Both files |
| `constraint-update` | New limitation or requirement | project-context.md |
| `dependency-note` | New dependency with rationale | project-context.md |
| `status-update` | Project milestone or phase change | project-context.md |

## Step 1.5: Read the Project Docs (primary source)

Before writing the cache, gather the authoritative state from the docs. Read each
that exists; skip silently if absent (a project may not have the full Regel-13 skeleton):

1. `docs/PROJECT.md` — frontmatter (`stack`, `status`, `repo`) + "Einzeiler", "Aktueller Stand", "Offene Baustellen", "Abhaengigkeiten"
2. `docs/ARCHITECTURE.md` — "Ueberblick" + "Kernkomponenten" (for the Architecture section)
3. `docs/CAPABILITIES.md` — the tools/features table (for status notes)
4. `HOW-TO-USE.md` and `CLAUDE.md` — for build/test commands and conventions

**Rules:**
- The docs are the source of truth. Derive the cache's Tech Stack / Architecture /
  Constraints / Status from them — do NOT re-infer the stack from config files when a
  doc already states it (that is `/init`'s job on first run, not context-keeper's).
- If a doc CONTRADICTS the current `project-context.md`, the doc wins. Note the drift
  in the Step 5 output so the user knows the cache was stale.
- If NO docs exist at all → fall back to reading config files / asking the user, and
  add a note suggesting the user create the Regel-13 skeleton.
- This step is read-only.

## Step 2: Update project-context.md (cache)

Read the current file, then overwrite with content distilled from Step 1.5. Keep the
cache compact (~60 lines) — it summarizes the docs, it does not duplicate them. Add a
pointer line `*Source: docs/ (PROJECT.md, ARCHITECTURE.md). This file is a cache.*`.
Maintain this structure:

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

## Step 3.5: Wiki-ADR Writeback (if Wiki configured)

If `.agent-memory/config.json` exists and `sync_enabled: true`:

For `architecture-decision` type decisions, additionally write back to the Wiki:

| Decision Subtype | Wiki Target | Action |
|-----------------|-------------|--------|
| Runtime/status decision | Projekt-Entity in `wiki/entities/{project_id}.md` | Update Status/Timeline section |
| Systemic architecture decision | `wiki/synthesis/` or `wiki/topics/` | Append to matching page or create ADR section |

**Routing logic:**
1. Read `config.json` → get `wiki_root` and `project_id`
2. Classify: Is this a runtime/status change (e.g., "switch to v2", "deprecate feature X") or a systemic architecture decision (e.g., "use SQLite instead of PostgreSQL", "adopt event sourcing")?
3. Runtime → update the project entity's Status/Timeline section
4. Systemic → find the best matching synthesis/topic page and append, or add to the entity's Architecture section if no better target exists

**Guardrails:**
- Only the main agent writes (subagents skip this step)
- Wiki write failures do NOT block the context-keeper flow (warn + continue)
- Do NOT duplicate what `wrap-up` Step 7.5 / `obsidian-sync` already does — context-keeper writes the **decision itself**, wrap-up writes the **session summary**
- Do NOT create new Wiki pages here — only update existing ones

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
