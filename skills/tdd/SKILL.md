---
name: tdd
description: >
  Enforces the Red-Green-Refactor cycle for building correct code from the start.
  Use when implementing features where correctness is critical, fixing bugs that
  need a regression test, or when you want confidence that code works before
  shipping. Automatically detects the project's test runner (pytest, Jest, Vitest,
  cargo test, go test, etc.). Follow this when the user says "implement X" and
  tests exist, or when a bug fix should be proven with a test first.
  Trigger on: "use TDD", "test first", "test-driven", "write tests before code",
  "red-green-refactor", "write the test first", "prove it works with a test",
  "test before implementing".
user_invocable: true
---

# Test-Driven Development (TDD)

This skill enforces the Red-Green-Refactor cycle. Tests define the target, code hits it, then you clean up. Follow this process exactly — no shortcuts.

## Why TDD works well with Claude

Tests give Claude a concrete, machine-verifiable goal. Instead of guessing whether code is correct, Claude writes a test that defines "correct," then iterates until it passes. This means less back-and-forth, automatic iteration on failures, and built-in test coverage as a side effect.

## When to use TDD

- New features, bug fixes, refactors where behavior must be preserved
- Any task where "does it work?" has an objective answer
- Projects that already have a test suite

## When NOT to use TDD

Skip TDD (write code first, add tests later) for:
- **Exploratory prototypes** — you don't know what you're building yet
- **UI styling** — visual changes need eyes, not assertions
- **Config changes** — no logic to test
- **Spikes/research** — throwaway code by design

If the task falls into one of these, say so and proceed without TDD.

---

## Step 0: Detect the test runner

Before writing anything, figure out how this project runs tests. Check for these signals:

| File / Config | Runner | Command |
|---|---|---|
| `pytest.ini`, `pyproject.toml [tool.pytest]`, `conftest.py` | pytest | `python -m pytest` |
| `jest.config.*`, `"jest"` in package.json | Jest | `npx jest` |
| `vitest.config.*`, `"vitest"` in package.json | Vitest | `npx vitest run` |
| `.mocharc.*`, `"mocha"` in package.json | Mocha | `npx mocha` |
| `Cargo.toml` | cargo test | `cargo test` |
| `go.mod` | go test | `go test ./...` |
| `mix.exs` | ExUnit | `mix test` |

If `CLAUDE.md` specifies a test command, use that instead. Store the detected command — you'll run it repeatedly.

**Test file conventions** — follow the project's existing pattern. Common defaults:
- Python: `tests/test_<module>.py` or `<module>_test.py`
- JS/TS: `<module>.test.{js,ts}` or `__tests__/<module>.{js,ts}`
- Rust: `#[cfg(test)]` module in same file, or `tests/` directory
- Go: `<module>_test.go` in same package

---

## Variant: Bugfix TDD

When fixing a bug in existing code, the cycle is slightly different. The goal is to first *prove* the bug exists with a test, then fix it.

1. **Locate the buggy code.** Read and understand the current implementation.
2. **Write a regression test** that exposes the bug — it should fail on the current code with the wrong behavior clearly visible in the error message.
3. **Run the test** and confirm it fails *for the right reason* (the bug, not an import error).
4. **Fix the code** — minimal change to make the regression test pass.
5. **Run the full suite** — the fix must not break existing tests.
6. **Refactor** if needed, keeping all tests green.

The key difference: you don't create the module from scratch. You write a test against existing code that demonstrates the defect, then patch the code.

**Example:**
```python
# Existing buggy code: calculate_discount(100, 110) returns -10.0

# Step 1: Regression test
def test_discount_over_100_percent_should_clamp():
    assert calculate_discount(100, 110) == 0.0  # FAIL: -10.0 != 0.0

# Step 2: Fix
def calculate_discount(price, percentage):
    clamped = max(0.0, min(percentage, 100.0))
    return price - (price * clamped / 100)
```

---

## The Cycle

For each unit of functionality, execute these phases in strict order.

### Phase 1: RED — Write a failing test

1. **Write a test** that describes the expected behavior. Be specific: one behavior per test.
2. **Run the test suite.** The new test MUST fail. If it passes, either:
   - The behavior already exists (no work needed), or
   - The test is wrong (it's not testing what you think)
3. **Confirm the failure message makes sense.** A good Red failure says "expected X but got Y" or "function not found" — not a crash in unrelated code.

**If you cannot execute tests** (e.g., missing dependencies, sandbox restrictions, subagent without Bash): simulate the run. Write down what the expected output would be and why. Document it explicitly:
```
Simulated run: python -m pytest test_foo.py
Expected result: FAIL — ImportError: cannot import 'foo' (module doesn't exist yet)
Red phase confirmed ✅
```
This keeps the discipline intact even when you can't actually run the test runner.

```
TodoWrite: [ ] RED: test written and confirmed failing
```

### Phase 2: GREEN — Make it pass with minimal code

1. **Write the simplest code** that makes the failing test pass. Resist the urge to write "good" code — ugly and passing beats elegant and untested.
2. **Run the test suite.** The new test AND all existing tests must pass.
3. If tests fail, read the error, fix the code, run again. Iterate until green.

The goal is speed to green, not beauty. "Minimal" means: if a hardcoded return value passes the test, that's fine for now — the next test will force you to generalize.

```
TodoWrite: [ ] GREEN: test passing with minimal implementation
```

### Phase 3: REFACTOR — Clean up, stay green

1. **Look at the code you just wrote.** Can you simplify? Remove duplication? Improve naming?
2. **Make improvements** — but only while keeping all tests passing.
3. **Run the test suite after every change.** If a test breaks, undo the last change immediately.

Refactoring is optional per cycle — if the code is already clean, move on. But always pause to consider it.

```
TodoWrite: [ ] REFACTOR: code improved, all tests still passing
```

### Then repeat

Pick the next behavior, write a failing test, make it pass, refactor. Each cycle should be small — a single function, a single edge case, a single rule.

---

## Checklist (use for each feature)

Copy this into your TodoWrite at the start of each TDD task:

```
- [ ] Detect test runner and conventions
- [ ] RED: Write failing test for [behavior]
- [ ] Confirm test fails with expected error
- [ ] GREEN: Write minimal code to pass
- [ ] Confirm ALL tests pass
- [ ] REFACTOR: Improve code, keep green
- [ ] Repeat for next behavior
- [ ] Final coverage check
```

---

## Coverage Check

After all cycles are done, run a coverage report to find untested paths. Use the project's coverage tool:

| Runner | Coverage Command | Target |
|---|---|---|
| pytest | `python -m pytest --cov=<module> --cov-report=term-missing` | 80%+ line coverage |
| Jest | `npx jest --coverage` | 80%+ line coverage |
| Vitest | `npx vitest run --coverage` | 80%+ line coverage |
| cargo test | `cargo tarpaulin` (or `cargo llvm-cov`) | 80%+ line coverage |
| go test | `go test -cover ./...` | 80%+ line coverage |

80% is the baseline — critical paths (payment, auth, scoring) should aim higher. If coverage is below target, identify the uncovered lines and add targeted tests in new Red-Green cycles.

If no coverage tooling is available, review the test file manually: list the behaviors the code supports, check each has a test.

---

## Rules

These are non-negotiable during TDD:

1. **No feature code without a failing test.** If you catch yourself writing implementation before a test exists, stop and write the test first.
2. **No deleting or skipping tests.** A failing test is a signal, not an inconvenience. Fix the code, not the test (unless the test itself is wrong).
3. **No "I'll add tests later."** Later never comes. The test comes first or not at all.
4. **Run the full suite, not just the new test.** Regressions hide in passing tests.
5. **Keep cycles small.** One behavior per Red-Green-Refactor cycle. If you're writing 5 tests at once, you're batching — break it down.

---

## Hooks (optional automation)

If the user wants to enforce TDD via Claude Code hooks, suggest this configuration for their `settings.json`:

### Auto-run tests after every code change

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "<TEST_COMMAND> 2>/dev/null",
            "onFailure": "warn"
          }
        ]
      }
    ]
  }
}
```

Replace `<TEST_COMMAND>` with the detected test runner (e.g., `python -m pytest --tb=short -q`, `npx jest --passWithNoTests`).

### Block completion if tests fail

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "<TEST_COMMAND>",
            "onFailure": "block"
          }
        ]
      }
    ]
  }
}
```

### Guard against writing feature code without tests

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "If this writes feature code (not a test file), check that a corresponding test file exists. If no test exists, return 'block' with a reminder to write the test first. Otherwise return 'approve'."
          }
        ]
      }
    ]
  }
}
```

---

## Example: Python + pytest

**Requirement:** Implement `calculate_discount(price, percentage)` that returns the discounted price.

**RED:**
```python
# tests/test_discount.py
from myapp.discount import calculate_discount

def test_basic_discount():
    assert calculate_discount(100, 10) == 90.0

def test_zero_discount():
    assert calculate_discount(100, 0) == 100.0
```
```bash
python -m pytest tests/test_discount.py  # FAIL: ModuleNotFoundError
```

**GREEN:**
```python
# myapp/discount.py
def calculate_discount(price: float, percentage: float) -> float:
    return price - (price * percentage / 100)
```
```bash
python -m pytest tests/test_discount.py  # PASS
```

**REFACTOR:** Code is already minimal — move on. Next cycle: add edge-case tests (negative percentage, over 100%, etc.).

---

## Example: JavaScript + Vitest

**RED:**
```javascript
// src/utils/slug.test.js
import { slugify } from './slug.js'

test('converts spaces to hyphens', () => {
  expect(slugify('hello world')).toBe('hello-world')
})

test('lowercases input', () => {
  expect(slugify('Hello World')).toBe('hello-world')
})
```
```bash
npx vitest run src/utils/slug.test.js  # FAIL: slugify is not a function
```

**GREEN:**
```javascript
// src/utils/slug.js
export function slugify(text) {
  return text.toLowerCase().replace(/\s+/g, '-')
}
```
```bash
npx vitest run src/utils/slug.test.js  # PASS
```

**REFACTOR:** Consider stripping special characters — but that's a new behavior, so write a test for it first (next cycle).
