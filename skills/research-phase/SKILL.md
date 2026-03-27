---
name: research-phase
description: Uses NotebookLM to research best practices before skill improvement. Creates notebooks, adds sources, runs RAG queries. Use when "research skill improvement", "find best practices", "NotebookLM recherchieren", "Recherche starten", "best practices for skill".
metadata:
  author: agentic-os
  version: '1.0'
  part-of: self-improve-loop
  layer: research
  depends-on:
    - notebooklm:navigate
    - notebooklm:create-notebook
    - notebooklm:add-source
    - notebooklm:chat
---

# Research Phase

Uses NotebookLM for research and RAG to gather best practices before improving skills. Creates a knowledge base that grows with each iteration.

## When to Use This Skill

- Called by loop-orchestrator at the start of each iteration
- When skill improvements need to be informed by best practices
- When the loop needs external knowledge

## Instructions

### Step 1: Receive Input

Expect as input:
- `target_skill_name`: Name of the skill to research
- `target_skill_content`: Current SKILL.md content
- `target_dir`: Plugin directory
- `iteration_number`: Current iteration

### Step 2: Check NotebookLM Availability

Try to invoke `notebooklm:navigate`. If NotebookLM is **not available** (skill not found, MCP error, or timeout), skip to **Step 5 (Fallback)** below.

If NotebookLM IS available, proceed with Steps 3-4.

### Step 3: Add Sources (NotebookLM path)

Check if a notebook named `self-improve-{plugin-name}` already exists.
- If it exists: navigate to it
- If not: invoke `notebooklm:create-notebook` with name `self-improve-{plugin-name}`

Use `notebooklm:add-source` to add relevant sources to the notebook:

1. **Current SKILL.md content** (as text source)
2. **Pattern data** from `{target_dir}/.agent-memory/patterns/patterns.json` (if exists)
3. **Previous iteration results** from `{target_dir}/improvements/` (if exists)
4. **ARCHITECTURE.md** from target plugin (if exists)

Also search for and add external best-practice sources:
5. Use web search to find relevant articles about:
   - "Claude Code skill best practices"
   - "prompt engineering for agent skills"
   - "SKILL.md optimization"
   Add found URLs via `notebooklm:add-source`

### Step 4: RAG Queries (NotebookLM path)

Use `notebooklm:chat` with targeted questions:

**Query 1 — Weakness Detection:**
```
Analyze the skill "{target_skill_name}" from its SKILL.md content.
What are the top 3 structural weaknesses?
Focus on: trigger accuracy, instruction clarity, error handling, completeness.
```

**Query 2 — Best Practices:**
```
What prompt engineering best practices apply to this skill's instructions?
Consider: step decomposition, tool usage patterns, safety guards, edge cases.
```

**Query 3 — Improvement Suggestions:**
```
Based on all sources in this notebook, suggest 3 concrete improvements
for this skill. Each suggestion should include:
- What to change
- Why it improves the skill
- Expected impact (high/medium/low)
```

Then skip to Step 6.

### Step 5: Fallback Research (no NotebookLM)

When NotebookLM is unavailable, perform research directly:

1. **Read local sources**: Read `{target_dir}/.agent-memory/patterns/patterns.json`, `{target_dir}/improvements/`, and `ARCHITECTURE.md` if they exist.
2. **Analyze the skill content directly**: Evaluate the target SKILL.md for structural weaknesses (trigger accuracy, instruction clarity, error handling, completeness).
3. **Apply built-in best practices**: Check against these known patterns:
   - Steps should be numbered and have clear tool calls
   - Edge cases and error paths must be specified
   - Descriptions should contain enough keywords for accurate triggering
   - Safety guards (rollback, abort conditions) should be present
4. **Use WebSearch if available**: Search for "Claude Code SKILL.md best practices" to supplement.

Proceed to Step 6.

### Step 6: Synthesize Findings

Combine all NotebookLM responses into a structured research report:

```json
{
  "skill_name": "...",
  "weaknesses": ["..."],
  "best_practices": ["..."],
  "suggestions": [
    {"change": "...", "reason": "...", "impact": "high|medium|low"}
  ],
  "sources_added": 5,
  "notebook_name": "self-improve-..."
}
```

### Step 7: Skip Studio Output (Do Not Call notebooklm:studio)

Do NOT invoke `notebooklm:studio` or `notebooklm:save-note` automatically. These calls write persistent notes to the user's NotebookLM account and are disruptive when run on every iteration without explicit user consent.

Only generate studio output if the user has explicitly requested it (e.g., "save findings to NotebookLM", "generate studio summary") — and in that case invoke it directly, not as part of the automated loop.

### Step 8: Report

Output the structured research findings for the analysis and improvement phases to consume.
