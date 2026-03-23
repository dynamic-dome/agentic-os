---
name: pattern-extractor
description: >
  Analyzes the iteration history (errors.json) and extracts recurring patterns,
  anti-patterns, and best practices into a searchable pattern catalog (JSON + Markdown).
  Uses deterministic clustering on category, tags, and file paths — no guessing.
  Run periodically (every 5-10 iterations), when a problem occurs 3+ times, or
  on explicit request. Trigger phrases: "patterns analysieren", "was wiederholt sich",
  "extract patterns", "lessons learned", "retrospektive", "pattern scan",
  "find patterns", "welche Muster erkennst du", "Muster extrahieren".
metadata:
  author: agentic-os
  version: '3.1'
  part-of: agentic-os
  layer: core
---

# Pattern Extractor

## Purpose

Transform raw iteration logs into actionable rules. The output is a pattern
catalog that `session-bootstrap` uses for warnings and `skill-generator` uses
as input for new skills. Pattern extraction must be deterministic and auditable —
every pattern traces back to specific error IDs.

## When to Trigger

- `iteration-logger` reports a problem with 3+ occurrences (recurrence threshold)
- User requests a retrospective ("was wiederholt sich?")
- Periodically after 5-10 new iterations
- Before starting a new module/feature (load known pitfalls)

## Directory Layout

```
.agent-memory/
├── iterations/
│   └── errors.json              # Input: structured error database
└── patterns/
    ├── patterns.md              # Output: human-readable pattern overview
    └── patterns.json            # Output: structured pattern database
```

## Instructions

### Step 1: Load data

Read:
- `.agent-memory/iterations/errors.json` — All logged errors
- `.agent-memory/patterns/patterns.json` — Existing patterns (for update/merge)

If `errors.json` has fewer than 3 entries, abort with:
"Not enough iteration data for pattern extraction. Log more iterations first."

### Step 2: Cluster errors (deterministic rules)

Apply these clustering rules in order. An error can belong to multiple clusters.

**Rule 1 — Category cluster:**
Group entries by `category`. A cluster is relevant if it has ≥2 entries.

**Rule 2 — Tag-overlap cluster:**
Two entries belong to the same cluster if they share ≥2 tags.
Use set intersection, not semantic similarity.

**Rule 3 — File-hotspot cluster:**
Group entries by `files_changed`. If the same file appears in ≥2 errors,
those errors form a cluster. This identifies fragile modules.

**Rule 4 — Explicit pattern seeds:**
Any entry with a non-null `reusable_pattern` field is a pattern seed,
even if it has no cluster (single occurrence with explicit lesson).

Do NOT use:
- Semantic similarity of `root_cause` text (not reproducible)
- LLM judgment for clustering decisions
- Fuzzy matching on any field

### Step 3: Evaluate clusters → patterns

For each cluster, determine if it qualifies as a pattern:

| Condition | Result |
|-----------|--------|
| Cluster has ≥3 entries | Pattern with `confidence: high` |
| Cluster has 2 entries | Pattern with `confidence: medium` |
| Single entry with `reusable_pattern` set | Pattern with `confidence: low` |
| Single entry without `reusable_pattern` | Not a pattern — skip |

For existing patterns in `patterns.json`, update occurrence counts and evidence.
Do not create a duplicate pattern if one already covers the same cluster.

### Step 4: Classify each pattern

| Type | Criteria | Example |
|------|----------|---------|
| `bug-pattern` | Same error type recurs | "Circular imports when adding new modules" |
| `anti-pattern` | Same failed approach recurs in `failed_approaches` | "Always trying import reorder first" |
| `best-practice` | Same solution recurs and works | "Lazy imports for cross-module deps" |
| `architecture-rule` | File-hotspot cluster + architecture category | "Config must not import from DB layer" |
| `tooling-tip` | Tool-specific tags dominate the cluster | "Use pytest fixtures instead of setUp" |
| `workflow-rule` | Process-level pattern (e.g. testing before refactor) | "Write tests before refactoring" |

Derive the type from the data. If unclear, default to `bug-pattern`.

### Step 5: Write patterns.json

For each pattern, create or update an entry:

```json
{
  "id": "<pattern-slug>",
  "type": "<bug-pattern|anti-pattern|best-practice|architecture-rule|tooling-tip|workflow-rule>",
  "title": "<short, memorable title>",
  "description": "<2-3 sentences: what is the pattern, when does it occur>",
  "trigger_conditions": [
    "<when should the agent think of this pattern>"
  ],
  "recommended_action": "<what to do when this pattern is recognized>",
  "avoid": [
    "<what NOT to do — derived from failed_approaches across cluster>"
  ],
  "evidence": {
    "occurrences": "<number of errors in this cluster>",
    "error_ids": ["<references to errors.json entries>"],
    "first_seen": "<date of earliest error>",
    "last_seen": "<date of latest error>",
    "clustering_rule": "<which rule(s) formed this cluster: category|tag-overlap|file-hotspot|explicit-seed>"
  },
  "tags": ["<union of tags from all clustered errors>"],
  "confidence": "<high|medium|low>",
  "skill_candidate": false
}
```

**skill_candidate criteria** — set to `true` only when ALL of:
- `occurrences >= 3`
- `confidence: "high"`
- `recommended_action` is a clear, multi-step procedure (not just "be careful")
- The pattern is not already covered by an existing generated skill

### Step 6: Write patterns.md

Create or overwrite the human-readable overview:

```markdown
# Pattern Catalog

*Last updated: <date>*
*Total patterns: <n> | High confidence: <n> | Skill candidates: <n>*

## Best Practices

### <title>
**Confidence:** <high|medium|low> | **Occurrences:** <n>x | **Clustering:** <rule>
<description>
**Action:** <recommended_action>
**Avoid:** <avoid items>
**Evidence:** <error_ids>

---

## Anti-Patterns
### <title>
...

## Bug Patterns
### <title>
...

## Architecture Rules
### <title>
...
```

Sort within each section by `occurrences` (highest first).

### Step 7: Output summary

```
Pattern analysis complete
  New patterns: <n> | Updated: <n> | Total: <n>

  Top patterns:
  1. <title> (<n> occurrences, <type>, <confidence>)
  2. <title> (<n> occurrences, <type>, <confidence>)

  Skill candidates: <n>
  [Recommendation: run skill-generator for "<pattern-title>"]
```

## Anti-gaming rules

These protect against pattern inflation:

- Never create a pattern from a single occurrence unless `reusable_pattern` is explicitly set
- Never upgrade confidence without new evidence (new error IDs)
- Never mark `skill_candidate: true` for patterns with only `confidence: low`
- When merging clusters, always take the more conservative confidence level
- If two patterns overlap significantly (≥80% shared error_ids), merge them

## Scaling

- If `errors.json` > 200 entries, process only the last 200 unless doing a full retrospective
- If `patterns.json` > 30 entries, flag low-confidence patterns older than 60 days
  for review and potential removal
