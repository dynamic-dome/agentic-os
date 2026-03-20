---
name: pattern-extractor
description: >
  Analyzes iteration history and error logs to extract recurring patterns
  and anti-patterns. Updates the pattern catalog.
  Trigger phrases: "extract patterns", "find patterns", "analyze iterations",
  "what patterns do you see", "Muster extrahieren", "Patterns analysieren",
  "welche Muster erkennst du".

metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: core
---

# Pattern Extractor

## When to Use

- Every N iterations (configured in `trigger-rules.json`.`pattern_check_interval`)
- At session end (wrap-up)
- When explicitly requested

## Analysis Process

1. **Read `errors.json`** — look for recurring error types, root causes, affected files
2. **Read `iteration-log.md`** — look for recurring change types, file clusters
3. **Read existing `patterns.json`** — avoid duplicates

## Pattern Schema

```json
{
  "id": "P{n}",
  "type": "pattern | anti-pattern | best-practice",
  "description": "Clear description of the pattern",
  "evidence": ["E5", "E12", "I23"],
  "confidence": 0.7,
  "severity": "critical | major | minor | info",
  "stack_tags": ["python", "opencv"],
  "source_projects": ["dart-vision"],
  "first_seen": "2026-03-19",
  "occurrences": 2,
  "recommendation": "What to do about it"
}
```

## Detection Heuristics

- **Same root cause 2+ times** → anti-pattern candidate
- **Same file changed in 3+ iterations** → hotspot, potential design issue
- **Test failures after same kind of change** → fragile area
- **Successful approach repeated** → best practice candidate

## Output

1. Append new patterns to `patterns.json`
2. Update `patterns.md` with human-readable summary
3. Tag patterns with `stack_tags` for cross-project relevance
4. Suggest global push if pattern has high confidence
