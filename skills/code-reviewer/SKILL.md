---
name: code-reviewer
description: |
  Reviews code quality after any code changes — whether you just finished a feature,
  fixed a bug, refactored something, or are about to commit. Scores readability,
  maintainability, security, performance, correctness, and testability on a 0-100 scale.
  Use after completing coding work to catch issues before they persist, or when you
  want a second opinion on code you wrote. Also triggers when preparing a commit or
  pull request and want to ensure quality standards are met.
  Trigger: "code reviewen", "review this", "qualitaet pruefen", "selbst-review",
  "code review", "check quality", "self-review", "ist der code gut so",
  "before I commit", "schauen wir uns den code an".

  <example>
  Context: User wants to check code quality before committing
  user: "review the code I just wrote"
  assistant: "Code Review: 82/100 (Good) — 3 findings..."
  <commentary>
  User requests quality check on recent changes, trigger code-reviewer.
  </commentary>
  </example>
user_invocable: true
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: quality
---

# Code Reviewer

## When to Use This Skill

- New code written or significantly changed
- Before a commit
- User asks: "Is the code good?" / "What can be improved?"

## File Structure

```
.agent-memory/
└── quality/
    ├── code-reviews.json     # All reviews
    └── quality-score.json    # Aggregated metrics
```

## Instructions

### Step 1: Identify Changed Files

Use Claude Code tools:
- `Bash`: `git diff --name-only HEAD~1` for recent changes
- `Grep`: Search for TODO/FIXME/HACK in changed files
- Or derive from the current session context

### Step 2: Load Conventions

Read using the `Read` tool:
- `.agent-memory/context/project-context.md` → tech stack, conventions
- `.agent-memory/patterns/patterns.md` → known anti-patterns
- Project-specific config: `pyproject.toml`, `ruff.toml`, `.editorconfig`

### Step 3: Review Across 6 Dimensions

Score each changed file on a scale of 1-5:

1. **Readability** — Clear names, logical structure, consistent style
2. **Maintainability** — Single Responsibility, no overly long functions (>50 lines warning)
3. **Correctness** — Edge cases, error handling, type hints
4. **Performance** — Efficient data structures, no unnecessary loops
5. **Security** — No hardcoded secrets, input validation, safe paths
6. **Testability** — Testable functions, injectable dependencies, tests present

### Step 4: Calculate Overall Score

```
# Formula: dimensions 1-5, normalized to 0-100
# (mean - 1) / 4 * 100 gives range 0-100 (not 20-100)
code_quality_score = round(((mean([all 6 dimensions]) - 1) / 4) * 100)
```

| Score | Rating | Action |
|-------|--------|--------|
| 90-100 | Excellent | No changes needed |
| 75-89 | Good | Minor improvements recommended |
| 60-74 | Acceptable | Schedule improvements |
| 40-59 | Needs Work | Revise before committing |
| 0-39 | Poor | Fundamental refactoring needed |

### Step 5: Update code-reviews.json

Use `Read` to load and `Edit`/`Write` to update:

```json
{
  "id": "<YYYY-MM-DD-HH-MM>-review",
  "timestamp": "<ISO 8601>",
  "files_reviewed": ["src/example.py"],
  "trigger": "<orchestrator|manual|pre-commit>",
  "scores": {
    "overall": 82,
    "readability": 4,
    "maintainability": 4,
    "correctness": 5,
    "performance": 4,
    "security": 4,
    "testability": 3
  },
  "findings": [
    {
      "severity": "<critical|warning|suggestion>",
      "file": "src/example.py",
      "line": 45,
      "dimension": "testability",
      "issue": "Description of the problem",
      "suggestion": "Suggested improvement"
    }
  ],
  "summary": "Brief summary"
}
```

### Step 6: Output Results

```
Code Review: <score>/100 (<rating>)
   Files: <n> reviewed

   Scores:
   Readability:     <n>/5
   Maintainability: <n>/5
   Correctness:     <n>/5
   Performance:     <n>/5
   Security:        <n>/5
   Testability:     <n>/5

   Findings: <n> (critical: <n>, warning: <n>, suggestion: <n>)
   Top recommendation: <most important finding>
```

### Step 7: Cross-Reference with Patterns

Check whether findings match known patterns from `patterns.json`.
If a new recurring issue is found → mark as a pattern candidate.

### Step 8: Log Rotation

When `code-reviews.json` contains more than 100 entries:
- Keep the newest 100 entries
- Archive older ones to `code-reviews-archive-<YYYY-MM>.json` in the same directory
