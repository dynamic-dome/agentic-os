---
name: loop-orchestrator
description: Orchestrates the full self-improvement loop. Runs N sequential iterations with circuit breaker, dedup, and final push. Use when "run self-improve loop", "improve skills", "start improvement cycle", "self-improve", "improve the plugin", "Verbesserungsschleife starten".
metadata:
  author: agentic-os
  version: '2.0'
  part-of: agentic-os
  layer: orchestration
  depends-on:
    - agentic-os:research-phase
    - agentic-os:analysis-phase
    - agentic-os:improvement-phase
    - agentic-os:validation-phase
---

# Loop Orchestrator

Main entry point for the self-improvement loop. Runs up to 4 sequential iterations, each consisting of research, analysis, improvement, and validation phases.

## When to Use This Skill

- User wants to improve plugin skills iteratively
- Scheduled task triggers automated improvement
- User says "self-improve", "improve skills", "run the loop"

## Instructions

### Step 1: Read State and Dedup History

Read `improvements/state.json` from the plugin root directory.
- Extract `currentIteration` to calculate the next iteration number
- Extract `history` array — collect all previously fixed weakness names/categories
- If `status` is `"running"`, abort with: "ABORTED: another loop is already running"

Update `state.json` to set `status: "running"` and `lastRun` to current ISO timestamp.

### Step 2: Determine Target Plugin

By default, target the plugin directory itself (self-improvement). The user can specify a different plugin path as target.

Read the target plugin's skill files using `Glob` with pattern `skills/*/SKILL.md` in the target directory.

### Step 3: Check Git and Baseline

Run in the target plugin directory:
```bash
git status --porcelain
```
If there are uncommitted changes, abort with: "ABORTED: uncommitted changes — commit or stash first".

Run baseline tests:
```bash
bash tests/run-all.sh
```
If tests fail, abort with: "ABORTED: baseline tests already failing".

### Step 4: Run Iterations (with Circuit Breaker)

For each iteration (1 to 4), run sequentially. **Before spawning each iteration (except the first), apply the circuit breaker check:**

**Circuit Breaker** — check the previous iteration's result:
- If it reported **"diminishing-returns"**: skip remaining iterations
- If it reported **"rollback"**: skip remaining iterations
- If 2+ consecutive iterations reported "diminishing-returns": note convergence and stop

If the circuit breaker does not trigger, spawn an Agent (subagent_type: "general-purpose") with the following prompt. **Wait for each agent to complete before spawning the next.**

The agent prompt for each iteration:

```
Run ONE self-improve iteration #{N} for the plugin at {TARGET_DIR}.

Dedup history (skip these): {PREVIOUSLY_FIXED_WEAKNESSES}

Phase 1 — RESEARCH:
Invoke the Skill tool with skill: "agentic-os:research-phase".
Pass the target skill name and content as context.
Collect research findings.

Phase 2 — ANALYSIS:
Invoke the Skill tool with skill: "agentic-os:analysis-phase".
Pass the dedup history and research findings.
Collect ranked weaknesses.

Phase 3 — IMPROVEMENT:
Invoke the Skill tool with skill: "agentic-os:improvement-phase".
Pass the weaknesses and research findings.
Apply TDD fixes.

Phase 4 — VALIDATION:
Invoke the Skill tool with skill: "agentic-os:validation-phase".
Run tests, evaluate changes.

Report status: completed / diminishing-returns / rollback
```

### Step 5: Final Push

After all iterations complete (or circuit breaker triggers), check if any commits were made:
```bash
cd {TARGET_DIR} && git log --oneline {BASELINE_SHA}..HEAD
```
If no new commits exist (all iterations were diminishing-returns or rollback), skip the push and report "no changes to push".

Otherwise, push (and handle failure gracefully):
```bash
cd {TARGET_DIR} && git push || echo "PUSH FAILED — changes are committed locally but not pushed. Check remote configuration."
```

### Step 6: Update State

Update `improvements/state.json`:
- Set `status: "idle"`
- Increment `currentIteration` by the number of completed iterations
- Add history entries for each fixed weakness
- Record quality scores

### Step 7: Report

Output a summary table:

```
| Iteration | Status | Fixes | False Alarms | Quality Score |
|-----------|--------|-------|--------------|---------------|
| N         | ...    | ...   | ...          | ...           |
```

If converging, note: "Loop is converging — consider reducing frequency or expanding scope."
