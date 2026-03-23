---
name: context-keeper
description: >
  Maintains the living project context: tech stack, architecture decisions,
  dependencies, constraints, and current project status. Called whenever an
  important decision is made or the architecture changes. Enables full context
  restoration across session switches. Trigger phrases: "kontext aktualisieren",
  "entscheidung festhalten", "update context", "warum haben wir X gewaehlt",
  "projektstand aktualisieren", "decision record", "ADR erstellen",
  "stack change", "neue dependency", "why did we choose X".
metadata:
  author: agentic-os
  version: '3.1'
  part-of: agentic-os
  layer: core
---

# Context Keeper

## Purpose

Maintain two complementary files:
- `project-context.md` — living overview (always current, overwritten in-place)
- `decisions.json` — append-only decision log (full history, never deleted)

Together they answer: "What is the current state?" and "Why did we choose X?"

## When to Trigger

- Architecture decision made (framework, library, pattern choice)
- Tech stack changes (new dependency, version upgrade, tool switch)
- Constraint added or changed (performance requirement, API limit, deadline)
- User asks "Warum haben wir X statt Y gewaehlt?"
- Status update needed (module completed, phase change)

## Directory Layout

```
.agent-memory/
└── context/
    ├── project-context.md        # Living project overview (overwritten)
    └── decisions.json            # Structured decision history (append-only)
```

Create both files if they do not exist.
- `decisions.json` → `[]`
- `project-context.md` → use template from Step 3

## Instructions

### Step 1: Classify the context update

| Type | When | Example |
|------|------|---------|
| `stack-change` | Library/tool added, removed, or upgraded | "Switch from requests to httpx" |
| `architecture-decision` | Structural choice | "Event-driven instead of REST for service X" |
| `constraint-update` | New or changed constraint | "API rate limit: max 100 req/min" |
| `dependency-note` | Important compatibility info | "numpy >=1.24 required for feature X" |
| `status-update` | Project progress | "Module A complete, Module B in progress" |

### Step 2: Write to decisions.json

For `stack-change`, `architecture-decision`, `constraint-update`, and `dependency-note`,
append an entry. Do NOT write entries for pure `status-update` — those only go into
`project-context.md`.

```json
{
  "id": "<YYYY-MM-DD>-<short-slug>",
  "timestamp": "<ISO 8601>",
  "type": "<stack-change|architecture-decision|constraint-update|dependency-note>",
  "title": "<short title>",
  "decision": "<what was decided>",
  "rationale": "<why — the reasoning>",
  "alternatives_considered": [
    {
      "option": "<alternative>",
      "rejected_because": "<reason for rejection>"
    }
  ],
  "impact": {
    "files_affected": ["<affected files/modules>"],
    "reversibility": "<easy|moderate|hard>",
    "dependencies": ["<new or affected dependencies>"]
  },
  "tags": ["<relevant tags>"],
  "status": "active"
}
```

**Status values:**
- `active` — current, applies now
- `superseded` — replaced by a newer decision (add `superseded_by: "<new-id>"`)
- `reverted` — rolled back (add `reverted_reason: "<why>"`)

### Step 3: Update project-context.md

This is an in-place update — replace the relevant sections, keep the rest.
The overall structure must always be:

```markdown
# Project Context

*Last updated: <date>*

## Project Goal
<1-2 sentences: what is being built and why>

## Tech Stack

| Component | Technology | Version | Note |
|-----------|-----------|---------|------|
| Language | Python | 3.11+ | match/case, tomllib |
| Framework | FastAPI | 0.109+ | Async-first, OpenAPI |
| ... | ... | ... | ... |

## Architecture Overview
<compact description, ASCII diagram if useful>

## Active Constraints
- <constraint>: <description>

## Module Status

| Module | Status | Note |
|--------|--------|------|
| auth | done | JWT + Refresh Token |
| api | in progress | REST endpoints |
| ... | ... | ... |

## Key Decisions (quick reference)
- **<date>**: <decision> — Reason: <rationale> (→ decisions.json#<id>)

## Known Limitations / Tech Debt
- <item>

## Open Questions
- <question>
```

**Important**: When updating, preserve sections you are not modifying. Do not
rewrite the entire file for a single stack change — update only the affected
section(s).

### Step 4: Consistency check

After every update, verify:

1. **Contradiction check**: Does the new decision contradict an existing active decision?
   - If yes → mark the old one as `"status": "superseded"` with `superseded_by`
   - Update the quick-reference section in project-context.md

2. **Constraint check**: Are existing constraints still valid?
   - If a constraint is resolved by the new decision → remove from "Active Constraints"

3. **Open questions check**: Does the new decision answer any open question?
   - If yes → remove the question, optionally note the answer

4. **Tag consistency**: Do the tags in the new decision match the tag conventions
   used in `errors.json` and `patterns.json`?

### Step 5: Confirm

```
Context updated: "<title>"
  Type: <type>
  Affected modules: <files/modules>
  Reversibility: <easy|moderate|hard>
  [Supersedes: <old decision id>]
  [Resolves open question: "<question>"]
```

## Retrieval Mode

When the agent asks for context (e.g. "Warum nutzen wir FastAPI?"):

1. Search `decisions.json` for matching tags or title keywords
2. Return the matching entry with `rationale` and `alternatives_considered`
3. Keep response compact — reference the decision ID for full details

This is a read-only operation. Do not modify any files during retrieval.

## Data Integrity Notes

- `project-context.md` is overwritten in-place. Git history provides versioning.
  If not in a git repo, the agent should warn that context history is not preserved.
- `decisions.json` is append-only. Entries are never deleted, only status-changed.
- Maximum recommended active decisions: 50. If exceeded, review for decisions
  that should be superseded.

## Example

```json
{
  "id": "2026-03-17-fastapi-over-flask",
  "timestamp": "2026-03-17T09:00:00+01:00",
  "type": "architecture-decision",
  "title": "FastAPI statt Flask fuer REST API",
  "decision": "FastAPI as web framework for all REST endpoints",
  "rationale": "Native async support, automatic OpenAPI docs, integrated Pydantic validation, better performance for I/O-bound workloads",
  "alternatives_considered": [
    {
      "option": "Flask + flask-restx",
      "rejected_because": "No native async, manual validation, more boilerplate"
    },
    {
      "option": "Django REST Framework",
      "rejected_because": "Too heavy for microservice, ORM not needed"
    }
  ],
  "impact": {
    "files_affected": ["app/main.py", "app/api/", "requirements.txt"],
    "reversibility": "moderate",
    "dependencies": ["fastapi>=0.109", "uvicorn", "pydantic>=2.0"]
  },
  "tags": ["python", "web-framework", "api", "async"],
  "status": "active"
}
```
