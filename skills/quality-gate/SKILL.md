---
name: quality-gate
description: |
  Combined code review, test validation, and TDD enforcement as a single quality
  skill. Scores readability, maintainability, security, performance, correctness,
  and testability on a 0-100 scale. Runs the test suite, detects regressions and
  flaky tests, and enforces Red-Green-Refactor when implementing new features.
  Use after completing coding work, before commits, or when you want confidence
  that code is correct and high quality.
  Trigger: "review this", "code review", "check quality", "self-review",
  "before I commit", "review the code", "check my code", "run tests",
  "check tests", "did I break anything", "is everything still working",
  "check for regressions", "run the test suite", "any tests failing",
  "use TDD", "test first", "test-driven", "red-green-refactor",
  "validate", "regression check", "quality check", "is the code ready".

  <example>
  Context: User wants to check code quality before committing
  user: "review the code I just wrote"
  assistant: "Quality Gate: 82/100 (Good) — Code review + tests passed"
  <commentary>
  User requests quality check on recent changes, trigger quality-gate.
  </commentary>
  </example>
user_invocable: true
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: quality
  depends-on:
    - agentic-os:pattern-extractor
    - agentic-os:context-keeper
---

# Quality Gate

Combined code review + test validation + TDD enforcement. Three modes depending on context:

- **Review mode**: Score code quality across 6 dimensions (default)
- **Test mode**: Run test suite and detect regressions
- **TDD mode**: Enforce Red-Green-Refactor cycle for new features

## When to Use

- After code changes, before a commit
- User asks: "Is the code good?", "Run tests", "Any regressions?"
- When implementing features with TDD: "test first", "use TDD"
- Pre-commit quality check: "quality check", "is the code ready?"

## File Structure

```
.agent-memory/
└── quality/
    ├── code-reviews.json     # All reviews
    ├── test-results.json     # Historical test results
    └── quality-score.json    # Aggregated metrics
```

---

# Mode 1: Code Review

## Step R.1: Identify Changed Files

Use Claude Code tools:
- `Bash`: `git diff --name-only HEAD~1` for recent changes
- `Grep`: Search for TODO/FIXME/HACK in changed files
- Or derive from the current session context

## Step R.2: Load Conventions

Read using the `Read` tool:
- `.agent-memory/context/project-context.md` — tech stack, conventions
- `.agent-memory/patterns/patterns.md` — known anti-patterns
- Project-specific config: `pyproject.toml`, `ruff.toml`, `.editorconfig`

## Step R.3: Review Across 6 Dimensions

Score each changed file on a scale of 1-5:

1. **Readability** — Clear names, logical structure, consistent style
2. **Maintainability** — Single Responsibility, no overly long functions (>50 lines warning)
3. **Correctness** — Edge cases, error handling, type hints
4. **Performance** — Efficient data structures, no unnecessary loops
5. **Security** — No hardcoded secrets, input validation, safe paths
6. **Testability** — Testable functions, injectable dependencies, tests present

## Step R.4: Calculate Overall Score

```
code_quality_score = round(((mean([all 6 dimensions]) - 1) / 4) * 100)
```

| Score | Rating | Action |
|-------|--------|--------|
| 90-100 | Excellent | No changes needed |
| 75-89 | Good | Minor improvements recommended |
| 60-74 | Acceptable | Schedule improvements |
| 40-59 | Needs Work | Revise before committing |
| 0-39 | Poor | Fundamental refactoring needed |

## Step R.5: Update code-reviews.json

```json
{
  "id": "<YYYY-MM-DD-HH-MM>-review",
  "timestamp": "<ISO 8601>",
  "files_reviewed": ["src/example.py"],
  "trigger": "<orchestrator|manual|pre-commit>",
  "scores": {
    "overall": 82,
    "readability": 4, "maintainability": 4, "correctness": 5,
    "performance": 4, "security": 4, "testability": 3
  },
  "findings": [
    {
      "severity": "<critical|warning|suggestion>",
      "file": "src/example.py", "line": 45, "dimension": "testability",
      "issue": "Description", "suggestion": "Suggested improvement"
    }
  ]
}
```

## Step R.6: Output Results

```
Code Review: <score>/100 (<rating>)
   Files: <n> reviewed
   Scores: Readability <n>/5 | Maintainability <n>/5 | Correctness <n>/5
           Performance <n>/5 | Security <n>/5 | Testability <n>/5
   Findings: <n> (critical: <n>, warning: <n>, suggestion: <n>)
   Top recommendation: <most important finding>
```

## Step R.7: Update quality-score.json

Update `.agent-memory/quality/quality-score.json` with latest code quality score and trend (improving/stable/declining based on 5-point delta).

## Step R.8: Cross-Reference with Patterns

Check whether findings match known patterns from `patterns.json`. If a new recurring issue is found, mark as pattern candidate.

## Log Rotation

When `code-reviews.json` contains more than 100 entries: keep newest 100, archive older ones to `code-reviews-archive-<YYYY-MM>.json`.

---

# Mode 2: Test Validation

## Step T.1: Detect the Test Framework

| Indicator | Framework | Command |
|-----------|-----------|---------|
| `conftest.py`, `pyproject.toml [tool.pytest]` | pytest | `python -m pytest --tb=short -q` |
| `package.json` with `jest`/`vitest` | Jest/Vitest | `npm test` |
| `go.mod` or `*_test.go` | Go | `go test ./...` |
| `Cargo.toml` | Cargo | `cargo test` |
| `tests/run-all.sh` | Custom | `bash tests/run-all.sh` |

Also check `CLAUDE.md` for project-specific test commands.

## Step T.2: Run Tests

```bash
python -m pytest --tb=short -q 2>&1
```

Capture: passed, failed, errors, skipped, duration, warnings.

## Step T.3: Calculate Health Score (0-100)

```
base_score = (passed / total) * 100
Penalties: each failed test -5, each error -10, no tests = 0, duration > 60s -5
health_score = max(0, base_score - penalties)
```

| Score | Rating |
|-------|--------|
| 90-100 | Excellent |
| 70-89 | Good |
| 50-69 | Warning |
| 0-49 | Critical — prioritize fixes |

## Step T.4: Regression Check

Read previous `test-results.json` and compare:
- **REGRESSION**: Previously passed, now failing
- **FIX**: Previously failing, now passing
- **GROWTH**: New tests added
- **FLAKY**: Alternates between passed/failed

## Step T.5: Update test-results.json

```json
{
  "id": "<YYYY-MM-DD-HH-MM>",
  "timestamp": "<ISO 8601>",
  "results": { "total": 42, "passed": 40, "failed": 1, "errors": 0, "skipped": 1, "duration_seconds": 12.3 },
  "health_score": 88,
  "regressions": [], "fixes": [], "new_tests": [], "flaky_suspects": []
}
```

## Step T.6: Output Result

```
Test result: <health_score>/100 (<rating>)
   Passed: <n> | Failed: <n> | Errors: <n> | Skipped: <n>
   Duration: <n>s | Regressions: <n> | New tests: <n>
   Trend: <improving|stable|declining>
```

## Step T.7: Escalate on Critical

When health_score < 50: recommend blocking further feature work, list failing tests in priority order.

## Coverage Tracking (optional)

```bash
python -m pytest --cov=src --cov-report=term -q 2>&1
```

Coverage > 80%: +5 bonus | Coverage < 40%: -10 penalty

## Log Rotation

When `test-results.json` contains more than 100 entries: keep most recent 100, archive older entries.

---

# Mode 3: TDD (Red-Green-Refactor)

Enforces the Red-Green-Refactor cycle. Tests define the target, code hits it, then you clean up.

## When to Use TDD

- New features, bug fixes, refactors where behavior must be preserved
- Any task where "does it work?" has an objective answer

## When NOT to Use TDD

- Exploratory prototypes, UI styling, config changes, spikes/research

## Step 0: Detect the Test Runner

Same detection as Mode 2 Step T.1. Store the detected command.

## The Cycle

For each unit of functionality:

### RED — Write a failing test
1. Write a test describing the expected behavior (one behavior per test)
2. Run the test suite — the new test MUST fail
3. Confirm the failure message makes sense

**If you cannot execute tests** (sandbox restrictions): simulate the run, document expected output explicitly.

### GREEN — Make it pass with minimal code
1. Write the simplest code that makes the failing test pass
2. Run the test suite — new AND all existing tests must pass
3. Iterate until green

### REFACTOR — Clean up, stay green
1. Simplify, remove duplication, improve naming
2. Run tests after every change — if a test breaks, undo immediately

### Then repeat

Pick the next behavior, write a failing test, make it pass, refactor.

## Variant: Bugfix TDD

1. Locate the buggy code
2. Write a regression test that exposes the bug — must fail for the right reason
3. Fix the code — minimal change to make the regression test pass
4. Run the full suite — fix must not break existing tests
5. Refactor if needed

## Rules (non-negotiable)

1. No feature code without a failing test
2. No deleting or skipping tests
3. No "I'll add tests later"
4. Run the full suite, not just the new test
5. Keep cycles small — one behavior per Red-Green-Refactor cycle

## Coverage Check

After all cycles, run coverage. 80% is the baseline; critical paths should aim higher.

---

# Combined Output (when running full quality gate)

When running both review and tests together:

```
Quality Gate: <verdict>
   Code Review: <score>/100 (<rating>)
   Test Health:  <score>/100 (<rating>)
   Regressions: <n>
   Verdict: PASS / WARN / FAIL
```

**PASS**: Code review >= 75 AND test health >= 90 AND 0 regressions
**WARN**: Code review >= 60 AND test health >= 70 AND 0 regressions
**FAIL**: Everything else (including any regressions)
