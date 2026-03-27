---
name: improvement-phase
description: Applies TDD-based improvements to SKILL.md files with commit-hash checkpoint rollback. Use when "apply skill improvement", "fix skill weaknesses", "improve skill", "TDD fix", "Skill verbessern".
metadata:
  author: agentic-os
  version: '2.0'
  part-of: agentic-os
  layer: core
  depends-on:
    - agentic-os:iteration-logger
---

# Improvement Phase

Modifies SKILL.md files using a TDD approach (RED/GREEN/REFACTOR) with commit-hash checkpoint rollback. Max 20% change per skill per iteration.

## When to Use This Skill

- Called by loop-orchestrator during each iteration
- After research and analysis phases have identified weaknesses
- When skill files need concrete improvements

## Instructions

### Step 1: Receive Input

Expect as input:
- `weaknesses`: Ranked list from analysis-phase (critical/warning only, suggestions skipped)
- `research_findings`: Best practices from research-phase
- `target_dir`: Path to the plugin being improved
- `iteration_number`: Current iteration

### Step 2: Create Safety Checkpoint

Record the current commit hash as a rollback point:
```bash
cd {target_dir} && git rev-parse HEAD
```
Store this as `checkpoint_sha`. Do NOT use `git stash` — stash-based rollback is fragile when stash may be empty or contain unrelated entries.

### Step 3: TDD Cycle for Each Weakness

For each weakness (critical and warning only):

**RED — Write a test that catches the weakness:**
Append a test case to `tests/validate-skills.sh` that would fail with the current skill.
Example: If a skill is missing an error handling section, add a test that checks for it.

Run the test to confirm it fails:
```bash
bash tests/validate-skills.sh
```
(Expect failure — this is the RED phase)

**GREEN — Apply the minimal fix:**
Use the `Edit` tool to modify the SKILL.md file.

Mutation strategies (informed by research findings):
- **Rephrase**: Improve description for better trigger accuracy
- **Restructure**: Reorganize steps for clarity
- **Augment**: Add missing sections (error handling, edge cases)
- **Constrain**: Add guardrails and safety checks
- **Simplify**: Remove redundant or confusing instructions

**Constraint**: Max 20% of the file's lines may change per iteration. Calculate the limit:
```
max_changes = total_lines * 0.20
```
If the fix requires more changes, split across iterations.

**REFACTOR — Clean up:**
Ensure consistent formatting, fix any introduced inconsistencies.

Run all tests:
```bash
bash tests/run-all.sh
```

### Step 4: Handle Test Results

**If tests PASS:**
Continue to next weakness. No cleanup needed.

**If tests FAIL:**
Rollback to the checkpoint using the commit SHA recorded in Step 2:
```bash
cd {target_dir} && git reset --hard {checkpoint_sha}
```
This atomically restores all tracked files to the checkpoint state.
Do NOT use `git clean -fd` — it permanently deletes untracked files (including test helpers or temp scaffolding) that may be needed and cannot be recovered.
Report: "ROLLBACK: fixes caused test failures — iteration aborted"
Stop processing further weaknesses.

### Step 5: Commit (No Push)

Stage changes (exclude .agent-memory):
```bash
cd {target_dir} && git add -A -- ':!.agent-memory'
```

Commit:
```bash
git commit -m "fix(self-improve): {summary} (#{iteration_number})"
```

Do NOT push — the orchestrator handles the final push.

### Step 6: Report

Output:
- Status: completed / rollback
- Weaknesses processed: X
- Fixes applied: Y
- Files modified: [list]
- Change percentage per file
