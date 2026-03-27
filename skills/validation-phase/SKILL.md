---
name: validation-phase
description: Validates skill improvements by running tests and optionally using NotebookLM for quality evaluation. Handles rollback on failure. Use when "validate improvements", "test skill changes", "check quality", "Verbesserungen validieren".
metadata:
  author: agentic-os
  version: '1.0'
  part-of: self-improve-loop
  layer: quality
  depends-on:
    - agentic-os:iteration-logger
---

# Validation Phase

Tests improved skills, evaluates quality via NotebookLM, and handles rollback if changes are worse.

## When to Use This Skill

- Called by loop-orchestrator after improvement-phase
- When skill changes need quality verification
- Before committing improvements

## Instructions

### Step 1: Run Test Suite

Execute all tests in the target plugin:
```bash
cd {target_dir} && bash tests/run-all.sh
```

Capture:
- Total tests run
- Tests passed
- Tests failed
- Any error output

### Step 2: Evaluate Quality

**If NotebookLM is available** and a notebook exists for this plugin:

Use `Skill` tool to invoke `notebooklm:chat` with the prompt:
```
Compare the original and modified versions of this skill.
Original: {original_content}
Modified: {modified_content}

Score the modification 1-10 on:
1. Clarity of instructions
2. Trigger description accuracy
3. Safety and error handling
4. Completeness

Overall verdict: BETTER / SAME / WORSE
```

If verdict is "WORSE", treat as test failure and trigger rollback.

**If NotebookLM is NOT available**, evaluate locally:

1. Compare the original and modified SKILL.md content using `Read`
2. Check that no existing sections were removed without replacement
3. Verify the changes address the weakness they claim to fix
4. Confirm formatting consistency with other skills in the plugin
5. If changes appear to reduce clarity or remove safety guards, treat as "WORSE" and trigger rollback

### Step 3: Handle Results

**All tests pass AND NotebookLM says BETTER/SAME:**
- Record results in iteration documentation
- Report: "VALIDATION PASSED"

**Tests fail OR NotebookLM says WORSE:**
- Rollback via git (use checkpoint_sha from improvement-phase):
```bash
cd {target_dir} && git reset --hard {checkpoint_sha}
```
- Report: "VALIDATION FAILED — rollback applied"
- Include failure details

### Step 4: Document Results

Write to `improvements/iterations-{batch}.md`:
```markdown
## Iteration {N} — {date}
### Test Results
- Plugin tests: X/Y passed
- Skill tests: A/B passed
- NotebookLM score: Z/10

### Quality Score
- Fixes/Findings ratio: X/Y
- False alarm rate: Z%

### Verdict: PASSED / FAILED
```

### Step 5: Update State

Update `improvements/state.json` with:
- Iteration entry: number, date, status, test counts, quality score
- Add fixed weakness names to history array (for dedup)

### Step 6: Report

Output:
- Status: passed / failed / rollback
- Test summary
- NotebookLM evaluation (if available)
- Quality score
