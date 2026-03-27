---
name: pattern-extractor
description: >
  Analyzes iteration history and error logs to extract recurring patterns,
  anti-patterns, and best practices into a searchable pattern catalog.
  Uses deterministic clustering on category, tags, and file paths.
  Run periodically (every 5 iterations), at session end, when a problem
  occurs 3+ times, or on explicit request.
  Trigger phrases: "extract patterns", "find patterns", "analyze iterations",
  "what patterns do you see", "Muster extrahieren", "Patterns analysieren",
  "welche Muster erkennst du", "lessons learned", "retrospektive", "pattern scan".
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

If `errors.json` has fewer than 3 entries, output "Not enough data for pattern extraction (need 3+ error records)" and stop.

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
  "skill_candidate": false
}
```

Set `skill_candidate: true` when:
- `occurrences >= 3` AND `confidence >= 0.7`
- The recommendation describes a multi-step procedure
- The pattern is generalizable beyond one specific file

Append to `patterns.json` array.

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
