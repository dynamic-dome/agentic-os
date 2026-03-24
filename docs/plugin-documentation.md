# Argentic OS v2 — Complete Plugin Documentation

## 1. What Is This Project?

**Argentic OS** is a self-improving agent memory system for Claude Code that creates a persistent knowledge base for any project. It's a v2 rewrite of an agentic operating system that tracks coding work, extracts patterns, and auto-generates reusable skills.

**Core Concept:** Turn unstructured coding work into actionable patterns, then automate recurring tasks by generating new skills from those patterns.

**Key Innovation:** A **closed-loop self-improvement cycle**:

```
Log iterations → Extract patterns → Generate skills → Avoid future errors
```

---

## 2. Architecture Overview

### 2.1 Memory System Structure (`.agent-memory/`)

```
.agent-memory/
├── session-summary.md          # Last session: work done, open items, next steps
├── identity/
│   ├── soul.md                 # Agent behavior, communication style, guard rails
│   └── user.md                 # User preferences, work patterns, corrections
├── context/
│   ├── project-context.md      # Tech stack, architecture, constraints
│   └── decisions.json          # All architecture decisions (append-only)
├── iterations/
│   ├── iteration-log.md        # Chronological work entries
│   └── errors.json             # Structured error records with root causes
├── patterns/
│   ├── patterns.json           # Machine-readable patterns with confidence scores
│   └── patterns.md             # Human-readable pattern catalog
├── quality/
│   ├── test-results.json       # Test execution history
│   ├── code-reviews.json       # Code quality reviews (6 dimensions)
│   └── quality-score.json      # Aggregated quality metrics + trends
├── learnings/
│   └── learnings.md            # Session insights (genuine, non-trivial only)
├── knowledge/
│   └── notebook-registry.md    # NotebookLM knowledge bases registry
└── generated-skills/           # Auto-generated skills from patterns
    └── <skill-name>/SKILL.md
```

### 2.2 Execution Model

**Minimal overhead, user-driven:**
- **SessionStart hook** (~15s): Read-only bootstrap of context
- **User invokes skills** during work (iteration-logger, code-reviewer, etc.)
- **Stop hook** (~15s): Log unlogged work
- **SessionEnd hook** (~30s): Update summary, extract learnings, suggest next steps
- **Total per session:** ~45 seconds

**No auto-triggers on every code change** — preserves focus, avoids overhead.

---

## 3. Skills (11 Total, 3 Layers)

### Layer 1: CORE (Memory & Context)

| # | Skill | Trigger | Purpose |
|---|-------|---------|---------|
| 1 | **session-bootstrap** | SessionStart hook, "start session" | Load project context, briefing, health checks (read-only) |
| 2 | **iteration-logger** | "log iteration", "document what I did" | Record features/bugfixes/refactors with duplicate detection |
| 3 | **pattern-extractor** | "extract patterns", after 5 iterations | Find recurring themes, calculate confidence scores, detect skill candidates |
| 4 | **context-keeper** | "update context", "decision record" | Maintain living context + append-only decision log (ADRs) |
| 5 | **wrap-up** | "wrap up", SessionEnd hook | Session summary, learnings, pattern extraction, git commit suggestion |
| 6 | **sync-context** | "sync memory", "pull patterns" | Manual cross-project pattern sync (currently unfinished, optional) |
| 7 | **skill-generator** | "generate skill", pattern flags `skill_candidate: true` | Turn patterns into reusable SKILL.md files |

### Layer 2: QUALITY (Code & Test Quality)

| # | Skill | Trigger | Purpose |
|---|-------|---------|---------|
| 8 | **code-reviewer** | "review this", "before commit" | 6-dimensional code quality scoring (0-100) |
| 9 | **test-validator** | "run tests", "regression check" | Test health scoring, regression detection, flaky test tracking |
| 10 | **tdd** | "use TDD", "test first" | Red-Green-Refactor enforcement with test runner detection |

### Layer 3: SELF-IMPROVEMENT (Evolution)

| # | Skill | Trigger | Purpose |
|---|-------|---------|---------|
| 11 | **self-improve** | Manual trigger, scheduled | Orchestrates autonomous improvement: find weaknesses → fix via TDD → auto-commit |

---

## 4. Skills in Detail

### 4.1 Session Bootstrap

**What it does:** Loads everything needed to continue work.
- Reads session-summary.md, soul.md, user.md, project-context.md, patterns.md, quality scores
- Performs health checks: file existence, JSON validity, scaling warnings
- Produces a concise briefing (< 15 lines) with active warnings and next steps
- **Never writes** — purely read-only

**Output:** SESSION BRIEFING with last session work, project status, active patterns, statistics, health warnings.

### 4.2 Iteration Logger

**What it does:** Records completed coding work.
- Analyzes the iteration: type (feature/bugfix/refactor/config/docs/test), files changed, summary, approach, confidence
- Detects duplicates: checks last 20 errors for same category + tags overlap
- Writes to `errors.json`: structured error record with root cause, failed approaches, prevention strategy
- Writes to `iteration-log.md`: chronological entry with learnings
- **Duplicate detection:** If same error occurs 3+ times, marks as anti-pattern candidate
- **Log rotation:** Archives when iteration-log.md > 500 entries or errors.json > 200 entries

### 4.3 Pattern Extractor

**What it does:** Finds recurring themes in error history.
- Analyzes `errors.json` and `iteration-log.md`

**Detection heuristics:**
- Same root_cause (fuzzy match) → anti-pattern
- Same category + 2+ overlapping tags → anti-pattern
- Same file in 3+ iterations → hotspot (design issue)
- 2+ test failures after same change → fragile area
- Successful approach repeated 3+ times → best practice

**Confidence calculation:**
```
base = 0.3
+ 0.1 per occurrence beyond first (max +0.3)
+ 0.1 if root_cause matches
+ 0.1 if same file cluster
+ 0.1 if prevention is consistent
+ 0.1 if occurs across multiple sessions
confidence = min(1.0, base + boosters)
```

**Thresholds:**
- < 0.3: discard
- 0.3-0.5: low confidence
- 0.5-0.7: medium (include in catalog)
- >= 0.7: high (briefing warnings)

**Skill candidates:** Patterns with `occurrences >= 3` AND `confidence >= 0.7` are flagged for skill generation.

### 4.4 Context Keeper

**What it does:** Maintains living project context + decision trail.

**Dual-file approach:**
- `project-context.md`: overwritten, always current (tech stack, architecture, constraints)
- `decisions.json`: append-only, never deleted (audit trail)

**Types:** stack-change, architecture-decision, constraint-update, dependency-note, status-update

**Decision entry:** id, date, type, title, status (active/superseded/reverted), context, options_considered, decision, consequences, supersedes, tags

### 4.5 Code Reviewer

**What it does:** Reviews code quality across 6 dimensions.

**Dimensions** (1-5 scale each):
1. Readability — clear names, logical structure, consistent style
2. Maintainability — SRP, no functions > 50 lines
3. Correctness — edge cases, error handling, type hints
4. Performance — efficient data structures, no unnecessary loops
5. Security — no hardcoded secrets, input validation, safe paths
6. Testability — testable functions, injectable dependencies

**Overall score:** `round(((mean - 1) / 4) * 100)` → 0-100 range
- 90-100: Excellent (no changes)
- 75-89: Good (minor improvements)
- 60-74: Acceptable (schedule improvements)
- 40-59: Needs Work (revise before commit)
- 0-39: Poor (refactoring needed)

### 4.6 Test Validator

**What it does:** Runs tests and tracks health.

**Framework detection:** pytest, Jest, Vitest, Mocha, cargo test, go test, ExUnit, CTest

**Health score calculation:**
```
base = (passed / total) * 100
penalties: -5 per failure, -10 per error, -5 if duration > 60s
health = max(0, base - penalties)
```

**Regression detection:**
- REGRESSION: Previously passed, now failing
- FIX: Previously failing, now passing
- GROWTH: New tests added
- FLAKY: Alternates between passed/failed

### 4.7 TDD (Test-Driven Development)

**What it does:** Enforces Red-Green-Refactor cycle.
1. **Red:** Write failing test that describes expected behavior
2. **Green:** Write minimal code to make test pass
3. **Refactor:** Clean up code, keep tests passing

**Cycle discipline:**
- No feature code without failing test
- No deleting/skipping tests
- Run full suite after each change
- Keep cycles small (one behavior per cycle)

### 4.8 Wrap-Up

**What it does:** End-of-session handoff.
1. Gather session data (iterations from today, git changes, test status, code quality, errors)
2. Summarize work (count iterations, list files changed, note quality changes)
3. Extract learnings (only genuine insights, not trivial facts)
4. Run pattern-extractor if 3+ iterations logged
5. Update session-summary.md (< 30 lines: what was done, open items, next steps, statistics)
6. Update user.md (only if 3+ repeated signals observed)
7. Suggest git commit (conventional format: feat:/fix:/refactor:/test:/chore:)

### 4.9 Skill Generator

**What it does:** Turns patterns into reusable skills.

**Source options:**
- From pattern with `skill_candidate: true`
- From current workflow description
- From user description + context

**Output file:** `.agent-memory/generated-skills/<skill-name>/SKILL.md` using standard SKILL.md template

### 4.10 Sync Context

**What it does:** Cross-project pattern sharing (currently unfinished).

**Architecture:** Local `.agent-memory/` ↔ `~/.claude-memory/global/`

**Issues:** Global infrastructure never created, no conflict resolution, no validation.

### 4.11 Self-Improve Orchestrator

**What it does:** Autonomous improvement loop.
1. Initialize (read improvements/state.json, increment iteration)
2. Analyze via improvement-scout agent (find 1-3 weaknesses)
3. Validate via fix-reviewer agent (feasibility, minimality, safety)
4. TDD fix (RED: failing test, GREEN: minimal fix, REFACTOR: cleanup)
5. Quality check via quality-gate agent
6. Document results to improvements/iterations-{batch}.md
7. Commit (no auto-push)

---

## 5. Hooks (6 Total)

All hooks are in `hooks/hooks.json`. They use prompt-based execution.

| Event | Timeout | Purpose |
|-------|---------|---------|
| **PostToolUse** (Write/Edit) | 10s | Track code changes silently |
| **SessionStart** | 15s | Auto-init + briefing |
| **UserPromptSubmit** | 10s | Scan intent for signals |
| **Stop** | 15s | Log unlogged work |
| **PreCompact** | 15s | Preserve critical context before compression |
| **SessionEnd** | 30s | Update summary, log learnings |
| **SubagentStop** | 10s | Suggest commit after agent work |

---

## 6. Agents (4 Total)

### 6.1 Context Detective (model: sonnet)
- **Purpose:** Auto-detect project tech stack on `/init`
- **Scans:** package.json, pyproject.toml, Cargo.toml, go.mod, pom.xml, README.md
- **Output:** `.agent-memory/context/project-context.md`

### 6.2 Improvement Scout (model: sonnet)
- **Purpose:** Health check + find actionable improvements
- **Detection:** Recurring errors, pattern gaps, quality trends, context freshness, stale decisions
- **Output:** Ranked list of max 5 improvements by impact

### 6.3 Fix Reviewer (model: sonnet)
- **Purpose:** Validates proposed fixes before implementation
- **Output:** APPROVE/REJECT with detailed reasoning

### 6.4 Quality Gate (model: sonnet)
- **Purpose:** Combined code review + test validation
- **Thresholds:**
  - PASS: code >= 75 AND test >= 80 AND no critical findings
  - WARN: code >= 60 AND test >= 60
  - FAIL: below WARN or critical findings exist

---

## 7. Commands (3 Total)

| Command | Purpose |
|---------|---------|
| `/agentic-os:init` | Bootstrap `.agent-memory/` in a new project |
| `/agentic-os:status` | Show memory system health and statistics |
| `/agentic-os:auto-commit` | Commit changes suggested by wrap-up or self-improve |

---

## 8. Session Lifecycle

```
USER STARTS SESSION
        ↓
SessionStart hook (15s)
    ├─ Auto-init .agent-memory/ if missing
    ├─ Read context files (read-only)
    └─ Output context via system message
        ↓
session-bootstrap skill (optional)
    ├─ Load all context files
    ├─ Health checks
    └─ Output briefing
        ↓
USER WORKS (iteration-logger, code-reviewer, test-validator, context-keeper, tdd)
        ↓
Optional: pattern-extractor (every 5 iterations or manual)
        ↓
Optional: skill-generator (when pattern is skill_candidate)
        ↓
Optional: self-improve (manual or scheduled)
        ↓
Stop hook (15s)
    └─ Log unlogged work
        ↓
PreCompact hook (15s) [if context compression needed]
    └─ Re-read critical files
        ↓
SessionEnd hook (30s)
    ├─ Update session-summary.md
    ├─ Log learnings
    └─ Suggest next steps
        ↓
USER ENDS SESSION
```

---

## 9. Self-Improvement Loop

```
improvements/state.json: iteration=51, total_fixes=65
    ↓
Self-Improve Iteration:
    ├─ improvement-scout: find weaknesses (1-3 per iteration)
    ├─ fix-reviewer: validate fixes (APPROVE/REJECT)
    ├─ TDD fix: RED → GREEN → REFACTOR
    ├─ quality-gate: check quality score
    ├─ Document to improvements/iterations-{batch}.md
    ├─ Git commit locally (no push)
    └─ Update state.json
```

**51 iterations completed, 65 total fixes** covering schema validation, documentation, hook logic, test coverage, and more.

---

## 10. Dependency Graph (Acyclic)

```
SESSION START (hook)
  ↓
session-bootstrap (read-only)
  ├─ reads: session-summary.md, soul.md, user.md, project-context.md, patterns.md, quality-score.json
  └─ (writes nothing)

WORK PHASE (user-driven)
  ├─ iteration-logger → iteration-log.md, errors.json
  ├─ context-keeper → project-context.md, decisions.json
  ├─ code-reviewer → code-reviews.json, quality-score.json
  ├─ test-validator → test-results.json, quality-score.json
  ├─ pattern-extractor → patterns.json, patterns.md
  │   ├─ reads: errors.json, iteration-log.md
  │   └─ flags skill_candidates
  ├─ skill-generator → generated-skills/<name>/SKILL.md
  │   └─ reads: patterns.json
  ├─ tdd → (no memory writes, uses test runner)
  ├─ sync-context → local ↔ global patterns (manual)
  └─ self-improve → improvements/state.json
      ├─ calls: improvement-scout (analysis)
      ├─ calls: fix-reviewer (validation)
      └─ calls: quality-gate (code checks)

SESSION END (hook)
  ↓
wrap-up
  ├─ reads: iteration-log.md, errors.json
  ├─ calls: pattern-extractor (if 3+ new iterations)
  ├─ writes: session-summary.md, learnings.md, user.md
  └─ suggests: git commit
```

---

## 11. Memory File Formats

### errors.json
```json
{
  "id": "E{n}",
  "date": "2026-03-24",
  "iteration": 42,
  "category": "runtime | test | build | config | logic | import | type",
  "tags": ["python", "import-error", "circular-import"],
  "trigger": "What action triggered the error",
  "problem": "Observable symptoms",
  "root_cause": "Why it went wrong",
  "fix": "How it was fixed",
  "failed_approaches": ["Approach 1: why it failed"],
  "prevention": "How to prevent this",
  "severity": "critical | major | minor",
  "attempts": 2,
  "confidence": 4,
  "occurrences": 1,
  "recurrence_dates": [],
  "last_seen": "2026-03-24"
}
```

### patterns.json
```json
{
  "id": "P{n}",
  "type": "pattern | anti-pattern | best-practice",
  "description": "Clear description",
  "evidence": ["E5", "E12", "I23"],
  "confidence": 0.7,
  "severity": "critical | major | minor | info",
  "tags": ["python", "import-error"],
  "occurrences": 3,
  "recommendation": "Specific action",
  "skill_candidate": false
}
```

### decisions.json
```json
{
  "id": "D{n}",
  "date": "2026-03-24",
  "type": "architecture-decision | stack-change | constraint-update",
  "title": "Short title",
  "status": "active | superseded | reverted",
  "context": "Why this was needed",
  "options_considered": [{"option": "Option A", "pros": [], "cons": []}],
  "decision": "What was chosen and why",
  "consequences": "Expected impact",
  "supersedes": null,
  "tags": ["architecture"]
}
```

### code-reviews.json
```json
{
  "id": "2026-03-24-14-30-review",
  "timestamp": "2026-03-24T14:30:00Z",
  "files_reviewed": ["src/example.py"],
  "scores": {
    "overall": 82,
    "readability": 4,
    "maintainability": 4,
    "correctness": 5,
    "performance": 4,
    "security": 4,
    "testability": 3
  },
  "findings": [{
    "severity": "critical | warning | suggestion",
    "file": "src/example.py",
    "line": 45,
    "dimension": "testability",
    "issue": "Description",
    "suggestion": "Suggested improvement"
  }]
}
```

### test-results.json
```json
{
  "id": "2026-03-24-14-30",
  "timestamp": "2026-03-24T14:30:00Z",
  "framework": "pytest | jest | custom",
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
  "flaky_suspects": []
}
```

---

## 12. Design Principles

1. **Minimal overhead** — 2 hooks (~45s total per session), no per-edit triggers
2. **User-driven** — skills invoked explicitly, not auto-triggered
3. **Read-only bootstrap** — session-bootstrap never writes, prevents side effects
4. **Append-only decisions** — decisions.json never deleted, only superseded (audit trail)
5. **Genuine learnings only** — avoid trivial facts in knowledge base
6. **Deterministic confidence** — use formula, not guessing
7. **Acyclic dependencies** — no circular skill/agent dependencies
8. **Log rotation** — archives prevent unbounded JSON growth
9. **Framework-agnostic** — works with any language/test runner
10. **Context preservation** — PreCompact hook ensures critical info survives compression

---

## 13. Key Files & Locations

| File | Purpose |
|------|---------|
| `README.md` | High-level overview, features, commands, hooks |
| `ANALYSE.md` | Deep technical analysis |
| `skills/DEPENDENCIES.md` | Complete dependency graph |
| `references/memory-structure.md` | .agent-memory/ directory reference |
| `references/skill-template.md` | Template for creating new skills |
| `hooks/hooks.json` | All hook definitions (6 hooks) |
| `commands/init.md` | `/agentic-os:init` implementation |
| `commands/status.md` | `/agentic-os:status` implementation |
| `agents/*.md` | 4 agent definitions |
| `skills/*/SKILL.md` | 11 skill definitions |
| `scripts/session-start.sh` | SessionStart hook bash script |
| `scripts/session-end.sh` | SessionEnd hook bash script |
| `scripts/pre-compact.sh` | PreCompact hook bash script |
| `improvements/state.json` | Self-improve orchestrator state |
| `.claude-plugin/plugin.json` | Plugin metadata (v2.0.0) |

---

## 14. Known Issues & Limitations

### Unfinished Features
- **sync-context:** Global infrastructure (`~/.claude-memory/global/`) never created
- **SubagentStop hook:** Commit suggestion depends on user confirmation

### Design Weaknesses
- Manual logging required — users must remember to call skills
- Single point of failure — Stop hook carries too many responsibilities
- Redundancy with Claude Code's native memory system

### Scaling Concerns
- JSON files read/written entirely on each operation (not streaming)
- No memory validation or integrity checks
- Pattern decay missing — old patterns keep full confidence

### Platform Issues
- Bash scripts assume Unix paths — Windows untested
- Git dependency required with unclear fallback behavior
