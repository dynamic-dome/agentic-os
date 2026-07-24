---
name: pattern-extractor
description: >
  Extracts recurring patterns, anti-patterns, and best practices from
  iteration and error history into the pattern catalog; generates skills
  from confirmed candidates. Use every ~5 iterations, at session end
  (invoked by wrap-up or self-improve), or on "extract patterns" /
  "refresh patterns".
metadata:
  author: agentic-os
  version: '3.3'
  part-of: agentic-os
  layer: analysis
---

# Pattern Extractor

Analyze `.agent-memory/iterations/` to extract recurring patterns into `.agent-memory/patterns/`.

## When to Use

- Every 5 iterations (suggested by iteration-logger)
- At session end (called by wrap-up)
- When user explicitly requests pattern analysis
- When an error occurs for the 3rd+ time

## Step 1: Load Data

Read these files:

1. `.agent-memory/iterations/errors.json` — structured error records
2. `.agent-memory/iterations/iteration-log.md` — iteration history
3. `.agent-memory/patterns/patterns.json` — existing patterns (to avoid duplicates)

**Minimum data guard:**
- If triggered as "refresh patterns" / "pattern refresh" / "regenerate patterns": skip this guard entirely — just regenerate `patterns.md` from `patterns.json` (jump to Step 6) and stop.
- If `patterns.json` already has entries: always allow running (existing patterns can be updated even without new errors).
- If `errors.json` has fewer than 3 entries AND `patterns.json` is empty: output "Not enough data for pattern extraction (need 3+ error records or existing patterns)" and stop.

## Step 2: Detection Heuristics

Apply these rules to identify pattern candidates:

### Anti-Pattern Detection

| Signal | Threshold | Pattern Type |
|--------|-----------|-------------|
| Same `root_cause` text (fuzzy match) | 2+ errors | Anti-pattern |
| Same `category` + 2+ overlapping `tags` | 2+ errors | Anti-pattern |
| Same file in `files_changed` | 3+ iterations | Hotspot (design issue) |
| Test failures after same kind of change | 2+ occurrences | Fragile area |
| Error with `occurrences >= 3` | 1 entry | Confirmed anti-pattern |

### Best Practice Detection

| Signal | Threshold | Pattern Type |
|--------|-----------|-------------|
| Successful approach repeated | 3+ iterations | Best practice |
| Confidence 5/5 with same approach | 2+ iterations | Best practice candidate |
| Error fixed on first attempt | 3+ similar fixes | Known solution |

### Tag-Overlap Clustering

Group errors by tag similarity:
- Extract all unique tags from `errors.json`
- Cluster errors that share >= 2 tags
- Each cluster with 2+ members is a pattern candidate

## Step 3: Confidence Scoring

Calculate confidence for each candidate:

```
base_confidence = 0.3

# Boosters
+ 0.1 per occurrence beyond the first (max +0.3)
+ 0.1 if root_cause matches across errors
+ 0.1 if same file cluster
+ 0.1 if prevention strategy is consistent
+ 0.1 if occurs across multiple sessions (different dates)

# Caps
confidence = min(1.0, base_confidence + boosters)
```

**Thresholds:**
- `confidence < 0.3` → discard (not enough evidence)
- `0.3 <= confidence < 0.5` → low confidence (log but don't warn)
- `0.5 <= confidence < 0.7` → medium (include in pattern catalog)
- `confidence >= 0.7` → high (include in session briefing warnings)

## Step 4: Check for Duplicates

Before adding a new pattern, compare against existing `patterns.json`:

- Same `description` (fuzzy — see algorithm below) → update existing: merge evidence, recalculate confidence
- Same `tags` overlap (>= 3 shared tags) → potential duplicate, review manually
- If duplicate: increment `occurrences`, update `last_seen`, merge `evidence` arrays

### Fuzzy Description Matching Algorithm

Use **Jaccard similarity on word tokens** to determine if two descriptions refer to the same pattern:

1. **Normalize** each description: lowercase, strip punctuation (`[^a-z0-9\s]`), collapse whitespace
2. **Tokenize**: split into a set of words (tokens)
3. **Jaccard similarity**: `|intersection| / |union|`
4. **Threshold**: similarity `>= 0.6` → treat as duplicate
5. **Category+tags shortcut**: if both patterns share the same `category` AND have `>= 2` overlapping `tags` → treat as duplicate regardless of description similarity

**Example:**
- Description A: `"Circular import error in Python modules"`
- Description B: `"Circular import error when loading Python modules"`
- Tokens A: `{circular, import, error, in, python, modules}`
- Tokens B: `{circular, import, error, when, loading, python, modules}`
- Intersection: `{circular, import, error, python, modules}` → 5
- Union: `{circular, import, error, in, python, modules, when, loading}` → 8
- Jaccard: `5/8 = 0.625` → `>= 0.6` → **duplicate**

## Step 5: Write Pattern Entry

```json
{
  "id": "P{n}",
  "type": "pattern | anti-pattern | best-practice",
  "description": "Clear, actionable description of the pattern",
  "evidence": ["E5", "E12", "I23"],
  "confidence": 0.7,
  "severity": "critical | major | minor | info",
  "tags": ["python", "import-error", "circular-import"],
  "source_projects": ["current-project"],
  "first_seen": "YYYY-MM-DD",
  "last_seen": "YYYY-MM-DD",
  "occurrences": 3,
  "recommendation": "Specific action to take or avoid",
  "skill_candidate": false,
  "lifecycle": "active",
  "implemented_by": [],
  "implemented_at": null,
  "validated_by": [],
  "validated_at": null
}
```

`implemented_by`/`validated_by` close the feedback loop (see Step 6.6): refs to the
change that implements the recommendation (commit hash, `skill@version`, rule file) and to
the post-implementation evidence that the change actually worked. Because refs alone carry
no timestamp, each list is paired with an ISO date: `implemented_at` (when the change
landed) and `validated_at` (when the effect evidence was observed). New entries start with
honest empty lists and null dates; pre-4.6.0 entries lack all four fields — every consumer
must tolerate both shapes (same contract as `derived_from`/`review_after` on learnings, v4.4.0).

`lifecycle` is `"active"` by default. When a newer entry supersedes this one in the same scope
(see `sync-context` recency-supersession), it becomes `"superseded"` and gains
`superseded_by: <new id>` + `superseded_at: <ISO>`. Superseded entries are never deleted.

Set `skill_candidate: true` when:
- `occurrences >= 3` AND `confidence >= 0.7`
- The recommendation describes a multi-step procedure
- The pattern is generalizable beyond one specific file

Append to `patterns.json` array.

### Canonical schema + legacy normalization (pattern-schema-canon)

pattern-extractor is the **sole creator and schema owner** of `patterns.json` entries, so
the field set above is the **single canonical schema**. The canonical fields are `description`
(what the pattern is), `recommendation` (what to do/avoid), and `evidence` (source
error/iteration ids) — plus
`id/type/confidence/severity/tags/source_projects/first_seen/last_seen/occurrences/skill_candidate`
and the feedback-loop fields `implemented_by`/`implemented_at`/`validated_by`/`validated_at`
(since 4.6.0, optional on legacy entries).

**Authorized field-writers besides pattern-extractor** (field-GAIN only — no other skill or
session may create, delete, or rewrite entries; same model as decisions.json "Append +
field-extend"):
- obsidian-sync Step 6 sets the promotion metadata `promotion_status`/`promotion_scope`.
- The implementing/validating main session sets `implemented_by`+`implemented_at` and
  `validated_by`+`validated_at` under the Step 6.6 rules (a landed change and a later
  effect check cannot wait for the next extractor run).

Older entries in the wild used divergent shapes. Before appending, **normalize any legacy
entry you read** to the canonical schema (one-shape convergence):

| Legacy field | Canonical field | Action |
|---|---|---|
| `solution` (P00x) / `prevention` (pattern-001) | `recommendation` | rename, keep value |
| `source_errors` (P00x) / `error_ids` (pattern-001) | `evidence` | rename, keep value |
| `name` (P00x) / `title` (pattern-001) | `description` | prepend to `description` as `"{name} — {description}"` if `description` exists, else move into `description` |
| legacy `id` like `pattern-001` | `P{n}` | renumber to the `P{n}` sequence; keep the old id in a `previous_id` field for provenance |

Do this normalization in place when you touch `patterns.json`; do not create a parallel entry.
After normalization, re-run the Step 4 Jaccard dedup so entries that were duplicates under
different shapes collapse.

## Step 6: Update patterns.md

Write a human-readable summary:

```markdown
# Pattern Catalog

*Last updated: {date}*
*Total patterns: {n} ({anti-patterns} anti-patterns, {best-practices} best practices)*

## High Confidence Warnings

### P{n}: {description} (confidence: {n})
- **Type:** anti-pattern
- **Evidence:** {n} occurrences
- **Recommendation:** {recommendation}
- **Tags:** {tags}

## Medium Confidence

### P{n}: {description} (confidence: {n})
...

## Skill Candidates

- P{n}: {description} — ready for skill generation (3+ occurrences)
```

## Step 6.5: Skill Candidate Generation

When a pattern has `skill_candidate: true` with `confidence >= 0.7` AND `occurrences >= 3`,
generate a reusable skill from it (this replaces the former `skill-generator` skill):

1. **Derive structure** from the pattern: name = short descriptive slug from the
   `description` (lowercase, hyphens, max 64 chars); steps from `recommendation` plus
   details from the `evidence` ids in `.agent-memory/iterations/errors.json`;
   anti-patterns from what the recommendation says to avoid.
2. **Uniqueness check**: if `.agent-memory/generated-skills/<skill-name>/` already exists
   or another pattern carries the same `generated_skill` value, append a version suffix
   (e.g. `-v2`) or skip and inform the user — never overwrite silently.
3. **Write** `.agent-memory/generated-skills/<skill-name>/SKILL.md` using this minimal template:

   ```markdown
   ---
   name: <skill-name>
   description: >
     <What the skill does + English trigger phrases for when to activate it>
   type: skill
   ---

   # <Skill Title>

   ## When to Use
   <Situations where the skill applies>

   ## Steps
   1. <Step derived from the pattern recommendation>

   ## What NOT to Do
   - <Anti-pattern from the source pattern>
   ```

4. **Mark the pattern** in `patterns.json`: set `"generated_skill": "<skill-name>"` and
   `"skill_generated_at": "<ISO 8601>"` so the candidate is not regenerated next run.
5. Report generated skills in the Step 8 output summary.

## Step 6.6: Feedback Loop to EXISTING Components (rueckfluss-delta-gate)

Step 6.5 covers NEW skills. This step covers the other half of the feedback loop:
patterns whose `recommendation` targets an **existing** skill, hook, prompt rule, or
other agentic-os component. Source: membrain Loop-8 harvest (Rosine 1, T-15).

**Trigger:** a pattern with `confidence >= 0.7` whose recommendation explicitly names an
existing component (skill, hook, rule file — e.g. "wrap-up should…", "the lint must…").
If the target is only vaguely implied, list the pattern under "Unmatched" in Step 8
instead of guessing a component.

**Gate — do NOT modify the target component from this skill.** Instead:

1. **Idempotency check** — before writing anything, inspect the pattern for `"delta_task_id"`.
   If set (or an open task already references this pattern id), do NOT
   create another draft — report it as "draft pending" in Step 8 and stop here for this
   pattern. Step 6.5 uses `generated_skill` the same way.

2. **Write a delta draft** (4 lines, no new artifact format) as a task entry in
   `context/open-tasks.json` — tasks are the one store any agent may write
   (Authority-Trias). For architecture-level changes, additionally hand the draft to
   `context-keeper` and never write context/decisions.json directly (context-keeper
   owns the decision log):

   ```text
   Affected component: <skill/hook/rule + file>
   Observed problem:   <what the pattern evidence shows>
   Proposed change:    <the minimal delta>
   Acceptance check:   <how a later session verifies the change worked>
   ```

   Then **mark the pattern**: set `"delta_task_id": "<task id>"` and
   `"delta_drafted_at": "<ISO 8601>"` so the next run skips it (see step 1).

3. **After implementation** — the implementing session sets `implemented_by` (refs) plus
   `implemented_at` (ISO date the change landed) on the pattern,
   but only after the change has landed (commit hash, `skill@version`, or rule file ref).
   Never set it for a draft, a plan, or an unmerged change.

4. **After the effect check** — set `validated_by` (evidence refs) plus `validated_at`
   (ISO date of the observation) once the problem actually receded (recurrence drop in
   `errors.json`, a later audit/bilanz finding). Comparison rule: `validated_at`
   must not precede implemented_at, and the evidence must come from a
   session other than the implementing one — a session can never validate its own change;
   validation always comes from later observation.

**Provenance chain closed** (one line, end to end):
iteration/error → learning (`derived_from`) → pattern (`evidence`) → change (`implemented_by`) → effect (`validated_by`).

Report delta drafts in the Step 8 output summary as "Rueckfluss candidates".

## Step 7: Flag Potential New Patterns

Scan the last 5 errors that don't match any existing pattern:
- List them as "Unmatched errors — potential new patterns" in the output
- These need more data before becoming patterns

## Step 8: Output Summary

```
Pattern Extraction Complete:
  Analyzed: {n} errors, {n} iterations
  New patterns: {n}
  Updated patterns: {n}
  Skill candidates: {n}
  Unmatched errors: {n}

  High-confidence warnings:
  - P{n}: {description}

  Suggested actions:
  - [if skill_candidate] Generate skill from P{n}
  - [if unmatched > 5] More data needed, continue logging
```

## What NOT to Do

- Do NOT invent patterns from insufficient data (< 2 occurrences)
- Do NOT modify errors.json or iteration-log.md (read-only for this skill)
- Do NOT push to global memory (that's wrap-up's job)
- Do NOT guess confidence — calculate it from the formula above
- Do NOT create patterns from single-occurrence errors
