---
name: self-improve
description: "Orchestrates autonomous self-improvement loops: runs up to 4 iterations of research, analysis, TDD-based improvement, and validation with circuit breaker, NotebookLM research, and git-safe rollback. Replaces the old single-pass approach with a multi-iteration loop."
user_invocable: false
---

# Self-Improve Orchestrator

## When to Use

This skill is triggered by the scheduled self-improvement task or manually when the user says:
- "self improve", "improve yourself", "selbst verbessern"
- "run improvement loop", "iterate on plugin"
- "find and fix weaknesses", "Schwachstellen finden und fixen"

## Procedure

This skill delegates to the `agentic-os:loop-orchestrator` which manages the full multi-iteration improvement cycle.

Invoke the `Skill` tool with skill: `agentic-os:loop-orchestrator`.

The orchestrator handles:
1. **Research** — NotebookLM RAG + web search for best practices (with headless fallback)
2. **Analysis** — pattern-extractor + direct skill analysis with severity ranking and dedup
3. **Improvement** — TDD (Red/Green/Refactor) with max 20% mutation per skill, commit-hash checkpoint rollback
4. **Validation** — test suite + optional NotebookLM quality evaluation, git-revert on failure
5. **Circuit Breaker** — stops on diminishing returns or rollback failures
6. **Scheduling** — adaptive frequency via schedule-manager on convergence

## Prerequisites

- `improvements/state.json` exists with `currentIteration` counter
- `tests/run-all.sh` exists and is executable
- Git repository is clean (no uncommitted changes)

## Constraints

- Max 4 iterations per run
- Max 20% change per skill per iteration
- Never modify `.agent-memory/` files directly (use iteration-logger, pattern-extractor)
- Circuit breaker stops on 2+ consecutive diminishing-returns
- Meta-improve limited to 1x per run (recursion guard)
