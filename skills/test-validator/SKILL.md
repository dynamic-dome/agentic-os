---
name: test-validator
description: |
  Runs the test suite after code changes and gives you a health score. Detects
  regressions (tests that passed before but fail now), flaky tests, and missing
  coverage. Use after finishing a feature or bugfix to make sure nothing broke,
  or periodically to track test health trends over time.
  Trigger: "validate", "test results", "regression check", "run tests",
  "check tests", "did I break anything", "is everything still working",
  "check for regressions", "run the test suite", "any tests failing".

  <example>
  Context: User finished a refactoring and wants to check for regressions
  user: "run tests, check for regressions"
  assistant: "Test result: 92/100 (Excellent) — 40/42 passed, 0 regressions"
  <commentary>
  User wants test validation after code changes, trigger test-validator.
  </commentary>
  </example>
user_invocable: true
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: quality
---

# Test Validator

## When to Use

- After code changes when tests need to run
- Before a commit or push
- After a refactoring
- When the user asks "Does everything still work?" or "Any regressions?"

## File Structure

```
.agent-memory/
└── quality/
    ├── test-results.json     # Historical test results
    └── quality-score.json    # Aggregated metrics
```

## Instructions

### Step 1: Detect the test framework

Use `Glob` and `Read` to identify the test setup:

| Indicator | Framework | Command |
|-----------|-----------|---------|
| `conftest.py`, `pyproject.toml [tool.pytest]` | pytest | `python -m pytest --tb=short -q` |
| `package.json` with `jest`/`vitest` | Jest/Vitest | `npm test` |
| `Makefile` with `test` target | Custom | `make test` |
| `go.mod` or `*_test.go` | Go | `go test ./...` |
| `Cargo.toml` or `tests/` (Rust) | Cargo | `cargo test` |
| `CMakeLists.txt` with `ctest` | CTest | `ctest --output-on-failure` |

Also check `CLAUDE.md` for project-specific test commands.

### Step 2: Run tests

Use the `Bash` tool:

```bash
python -m pytest --tb=short -q 2>&1
```

Capture: passed, failed, errors, skipped, duration, warnings.

### Step 3: Calculate health score (0-100)

```
base_score = (passed / total) * 100
Penalties:
  - Each failed test: -5
  - Each error: -10
  - No tests at all: Score = 0
  - Duration > 60s: -5
  - >20% warnings: -5

health_score = max(0, base_score - penalties)
```

| Score | Rating |
|-------|--------|
| 90-100 | Excellent |
| 70-89 | Good |
| 50-69 | Warning |
| 0-49 | Critical — prioritize fixes |

### Step 4: Regression check

Read the previous `test-results.json` with the `Read` tool and compare:
- **REGRESSION**: Previously passed, now failing
- **FIX**: Previously failing, now passing
- **GROWTH**: New tests added
- **FLAKY**: Alternates between passed/failed

### Step 5: Update test-results.json

```json
{
  "id": "<YYYY-MM-DD-HH-MM>",
  "timestamp": "<ISO 8601>",
  "trigger": "<manual|orchestrator|pre-commit>",
  "framework": "<pytest|jest|custom>",
  "results": {
    "total": 42,
    "passed": 40,
    "failed": 1,
    "errors": 0,
    "skipped": 1,
    "duration_seconds": 12.3
  },
  "health_score": 88,
  "regressions": [],
  "fixes": [],
  "new_tests": [],
  "flaky_suspects": [],
  "failed_details": []
}
```

### Step 6: Output result

```
Test result: <health_score>/100 (<rating>)
   Passed: <n> | Failed: <n> | Errors: <n> | Skipped: <n>
   Duration: <n>s

   Regressions: <n>
   New tests: <n>
   Trend: <improving|stable|declining>

   [If failed > 0:]
   → Recommendation: Fix <test_name> first (Regression!)
```

### Step 7: Escalate on Critical

When health_score < 50:
- Recommend blocking further feature work until fixed
- List failing/missing tests in priority order
- Suggest a "test-first" resolution order

## Coverage Tracking (optional)

```bash
python -m pytest --cov=src --cov-report=term -q 2>&1
```

Coverage > 80%: +5 bonus | Coverage < 40%: -10 penalty

## Log Rotation

When `test-results.json` contains more than 100 entries (configurable via plugin setting `max_test_result_entries`):
- Keep the most recent 100 entries
- Archive older entries to `test-results-archive-<YYYY-MM>.json` in the same directory
