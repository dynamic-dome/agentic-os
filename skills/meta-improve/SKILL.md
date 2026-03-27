---
name: meta-improve
description: The loop improves its own skills — meta-level self-improvement. Limited to 1 iteration per run to prevent infinite recursion. Use when "improve the improver", "meta-improvement", "optimize the loop", "Meta-Verbesserung", "Loop optimieren".
metadata:
  author: agentic-os
  version: '1.0'
  part-of: self-improve-loop
  layer: evolution
  depends-on:
    - agentic-os:pattern-extractor
    - agentic-os:iteration-logger
---

# Meta-Improve

The loop improves its own skills. Uses the same research/analysis/improvement/validation pipeline but targets the self-improve-loop plugin itself.

## When to Use This Skill

- Called by loop-orchestrator after regular iterations complete (optional)
- When the improvement process itself needs optimization
- Max 1 meta-iteration per run (recursion guard)

## Instructions

### Step 1: Recursion Guard

Read `improvements/state.json` and check `metaHistory`.
If the last meta-improvement was in the current run (same date), abort with: "META-GUARD: already ran meta-improve in this run"

### Step 2: Set Target to Self

Set the target directory to the self-improve-loop plugin directory itself:
```
target_dir = {PLUGIN_ROOT}  (this plugin's root)
```

### Step 3: Run Single Iteration

Spawn ONE Agent (subagent_type: "general-purpose") with:

```
Run ONE self-improve iteration for the self-improve-loop plugin itself.
Target: {PLUGIN_ROOT}

This is a META-IMPROVEMENT — you are improving the improvement loop.

Focus on:
1. Are skill descriptions triggering accurately?
2. Are instructions clear and complete?
3. Is the loop lifecycle efficient?
4. Are safety mechanisms comprehensive?

Phase 1 — RESEARCH:
Invoke skill "self-improve-loop:research-phase" to research best practices for self-improving agent loops.
It will use NotebookLM if available, or fall back to local analysis.

Phase 2 — ANALYSIS:
Read all skills in this plugin. Compare against best practices.
Identify 1-2 high-impact improvements only.

Phase 3 — IMPROVEMENT:
Apply TDD fixes. Max 20% change per skill.

Phase 4 — VALIDATION:
Run tests. If any fail, rollback.

Report: completed / rollback / no-improvements-needed
```

### Step 4: Update Meta-State

Update `improvements/state.json`:
- Add entry to `metaHistory` with date, changes made, quality score

### Step 5: Guard Against Degradation

After meta-improvement, run all tests again:
```bash
bash tests/run-all.sh
```

If tests fail, rollback the meta-improvement entirely using the commit hash recorded before changes:
```bash
git reset --hard {checkpoint_sha}
```

### Step 6: Report

Output:
- Meta-improvement status
- Changes made to which skills
- Quality score before/after
- Note: "Meta-improve is limited to 1x per run"
