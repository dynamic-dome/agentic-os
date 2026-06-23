---
name: retrospective
description: >
  Multi-session deep analysis that aggregates the memory store (iterations, errors,
  patterns, quality scores, decisions, learnings) into long-term trend metrics: is the
  agent getting better, where are the blind spots, which areas need attention. Computes
  efficiency, quality, learning and growth metrics across time windows and assigns a
  health grade. Read-only over the store; writes only its own retrospectives/ output.
  Run periodically (every few sessions / weekly) — wrap-up invokes it on an interval.
  Trigger: "retrospective", "session retrospective", "long-term metrics",
  "are we improving", "show metrics", "progress trends", "health grade",
  "how are we doing over time", "what can we improve".
user_invocable: true
metadata:
  author: agentic-os
  version: '1.0'
  part-of: agentic-os
  layer: quality
  depends-on: []
---

# Retrospective

Long-horizon companion to `quality-gate` (which scores a single change) and `memory-audit`
(which reports point-in-time drift): retrospective looks **across sessions** and answers
"are the trends going the right way?".

## When to Use

- Periodically: every ~5 sessions or once a week (wrap-up triggers this on an interval)
- User asks for an overall read: "are we improving?", "show metrics", "retrospective"
- Before starting a new project milestone
- When it feels like the agent is not getting better

This skill is **read-only over the memory store** — it never mutates iterations, errors,
patterns, quality, decisions or learnings. It writes ONLY to `.agent-memory/retrospectives/`
(`retro-{date}.md` + `metrics.json`), files no other skill owns, so there is no
write-ownership conflict in the DAG.

## Step 1: Load Data Sources (read-only)

Read whichever of these exist; skip missing ones silently:

| Source | File | Extract |
|--------|------|---------|
| Iterations | `iterations/iteration-log.md` | iteration count, recency |
| Errors | `iterations/errors.json` | count, categories, `occurrences`/recurrence, dates |
| Patterns | `patterns/patterns.json` | count, `confidence` trend, `skill_candidate` flags |
| Tests | `quality/test-results.json` | `health_score` history, regressions, growth |
| Reviews | `quality/code-reviews.json` | quality trend per dimension |
| Quality | `quality/quality-score.json` | current test/code scores + trend |
| Decisions | `context/decisions.json` | count, superseded/reverted entries |
| Learnings | `learnings/learnings.json` | count, importance distribution, repeat themes |

## Step 2: Compute Core Metrics

### 2.1 Efficiency
```
avg_attempts_per_fix   = mean(error.attempts) over errors.json (default 1 if absent)
first_try_success_rate = count(attempts == 1) / total_errors * 100
trend                  = compare last 10 vs previous 10 errors
```

### 2.2 Quality
```
code_quality_trend = last 10 code_quality scores (quality-score.json / code-reviews.json)
test_health_trend  = last 10 test health_scores (test-results.json)
regression_rate    = total regressions / total test runs * 100
```

### 2.3 Learning
```
patterns_high_confidence = count(patterns with confidence >= 0.7)
repeat_error_rate        = errors with recurrence / total_errors * 100
unique_error_categories  = distinct categories in errors.json
```

### 2.4 Growth
```
total_iterations, total_errors, total_patterns, total_decisions,
total_learnings, total_generated_skills (count generated-skills/* if present)
```

## Step 3: Time-Window Analysis

Compute the metrics for three windows and a trend arrow (improving ↑ / stable → /
declining ↓), comparing the current window to the previous one:

| Window | Use |
|--------|-----|
| All-time | since project start |
| Last 7 days | short-term trend |
| Last 30 days | mid-term trend |

## Step 4: Blind-Spot Analysis

Surface areas that need attention:

- **Orphan skill candidates**: patterns with `skill_candidate: true` but no generated skill
- **Rising error categories**: a category whose frequency is increasing
- **Stuck quality dimensions**: a review dimension that stays low across runs
- **Recurring unfixed findings**: errors/patterns that reappear without resolution
- **Starved pipeline**: iterations logged but no patterns extracted, or null quality scores

## Step 5: Write metrics.json

Write `.agent-memory/retrospectives/metrics.json` (create the directory if missing):

```json
{
  "last_updated": "{ISO 8601}",
  "project_age_days": 14,
  "efficiency": {"avg_attempts_per_fix": 2.3, "first_try_success_rate": 45, "trend": "improving"},
  "quality":    {"code_quality_avg": 82, "test_health_avg": 88, "regression_rate": 5.2, "trend": "stable"},
  "learning":   {"patterns_high_confidence": 8, "repeat_error_rate": 15, "trend": "declining"},
  "growth":     {"total_iterations": 47, "total_patterns": 12, "total_learnings": 30, "total_skills_generated": 3},
  "blind_spots": ["..."],
  "health_grade": "B+"
}
```

**Health grade:**
```
A+ : all trends improving, no blind spots
A  : mostly improving, < 2 blind spots
B+ : stable or slightly improving, < 3 blind spots
B  : mixed, 3-4 blind spots
C  : mostly declining, > 4 blind spots
D  : all trends declining
```

## Step 6: Write the Retrospective Report

Write `.agent-memory/retrospectives/retro-{YYYY-MM-DD}.md`:

```markdown
# Retrospective — {date}

## Summary
**Health Grade: {grade}** | Project day: {n}

## Core Metrics
| Metric | Current | Trend | Previous |
|--------|---------|-------|----------|
| Attempts per fix | 2.3 | ↓ improving | 3.1 |
| First-try rate | 45% | ↑ improving | 38% |
| Code quality | 82/100 | → stable | 81/100 |
| Test health | 88/100 | ↑ improving | 82/100 |
| Repeat-error rate | 15% | ↓ declining | 22% |

## What's Going Well
- {positive trends}

## What Needs Attention
- {blind spots and negative trends}

## Recommendations
1. {concrete, prioritized}
2. {...}

## Since Last Retrospective
- {what improved / regressed vs the previous retro-*.md}
```

## Step 7: Output

```
RETROSPECTIVE — {date}
  Health Grade: {grade} | Project day: {n}
  Iterations: {n} | Patterns: {n} | Learnings: {n}
  Efficiency {trend} · Quality {trend} · Learning {trend}
  Top recommendations:
  1. {...}
  2. {...}
  Next retrospective: {date + interval}
```

## Error Handling

- Missing source file → skip it, note "partial data" in the report; never fail the run.
- Corrupt JSON → skip that source, warn in the report; do NOT rewrite store files
  (retrospective is read-only over the store; repair is `memory-maintenance`'s job).
- First run (no prior retro) → omit the "Since Last Retrospective" section.

## What NOT to Do

- Do NOT modify any store file outside `retrospectives/` (read-only contract).
- Do NOT recompute or decay `confidence` — that belongs to `memory-maintenance`.
- Do NOT invent metrics from absent data — report "insufficient data" instead.
