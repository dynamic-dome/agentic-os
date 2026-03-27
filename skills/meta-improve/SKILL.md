---
name: meta-improve
description: The loop improves its own skills — meta-level self-improvement. Limited to 1 iteration per run to prevent infinite recursion. Use when "improve the improver", "meta-improvement", "optimize the loop", "Meta-Verbesserung", "Loop optimieren".
metadata:
  author: agentic-os
  version: '2.0'
  layer: evolution
---

# Meta-Improve

The loop improves its own skills. Uses the same research/analysis/improvement/validation pipeline but targets the agentic-os plugin itself.

## When to Use This Skill

- Called by loop-orchestrator after regular iterations complete (optional)
- When the improvement process itself needs optimization
- Max 1 meta-iteration per run (recursion guard)

## Instructions

### Step 1: Recursion Guard

Read `improvements/state.json` and check `metaHistory`.
If the last meta-improvement was in the current run (same date), abort with: "META-GUARD: already ran meta-improve in this run"

### Step 2: Set Target to Self

Set the target directory to the agentic-os plugin directory itself:
```
target_dir = {PLUGIN_ROOT}  (this plugin's root)
```

### Step 3: Run Single Iteration

Spawn ONE Agent (subagent_type: "general-purpose") with:

```
Run ONE self-improve iteration for the agentic-os plugin itself.
Target: {PLUGIN_ROOT}

This is a META-IMPROVEMENT — you are improving the improvement loop.

Focus on:
1. Are skill descriptions triggering accurately?
2. Are instructions clear and complete?
3. Is the loop lifecycle efficient?
4. Are safety mechanisms comprehensive?

Phase 1 — RESEARCH:
Invoke `agentic-os:research-phase` (which handles NotebookLM availability checks and
automated/headless fallback automatically). If running in a scheduled/headless context,
the research-phase fallback uses WebSearch + local file reads — no manual NotebookLM call needed.
Add this plugin's own ARCHITECTURE.md as source if available.

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

If tests fail, rollback the meta-improvement entirely:
```bash
cd {PLUGIN_ROOT} && git revert --no-edit HEAD
```

Note: The improvement-phase already dropped the stash on success (P9 pattern), so the stash is gone. Use `git revert` to create a revert commit rather than attempting to restore a non-existent stash.

### Step 6: Report

Output:
- Meta-improvement status
- Changes made to which skills
- Quality score before/after
- Note: "Meta-improve is limited to 1x per run"
