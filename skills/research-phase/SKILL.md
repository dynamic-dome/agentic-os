---
name: research-phase
description: Researches best practices before skill improvement. Analyzes local sources (patterns, iterations, architecture), applies built-in quality checklist, optionally uses WebSearch. NotebookLM is an optional enhancement, not required. Use when "research skill improvement", "find best practices", "Recherche starten", "best practices for skill".
metadata:
  author: agentic-os
  version: '2.0'
  part-of: agentic-os
  layer: research
  depends-on: []
---

# Research Phase

Gathers best practices and identifies weaknesses before improving skills. Works fully offline with local analysis; optionally enhanced by WebSearch or NotebookLM.

## When to Use This Skill

- Called by loop-orchestrator at the start of each iteration
- When skill improvements need to be informed by best practices

## Instructions

### Step 1: Receive Input

Expect as input:
- `target_skill_name`: Name of the skill to research
- `target_skill_content`: Current SKILL.md content
- `target_dir`: Plugin directory
- `iteration_number`: Current iteration

### Step 2: Local Analysis (always runs)

1. **Read local sources**: Use `Glob` and `Read` to check for:
   - `{target_dir}/.agent-memory/patterns/patterns.json` — recurring issues
   - `{target_dir}/.agent-memory/iterations/` — recent iteration logs
   - `{target_dir}/improvements/` — previous improvement results
   - `{target_dir}/ARCHITECTURE.md` or `{target_dir}/CLAUDE.md` — project context

2. **Analyze the skill content directly** against this checklist:
   - [ ] Steps are numbered with clear tool calls
   - [ ] Edge cases and error paths are specified
   - [ ] Description contains enough keywords for accurate triggering
   - [ ] Safety guards (rollback, abort conditions) are present
   - [ ] Frontmatter is complete (name, description, metadata)
   - [ ] No circular or broken dependencies
   - [ ] Consistent formatting with other skills in the plugin

3. **Cross-reference with patterns**: If patterns.json exists, check whether the skill exhibits known anti-patterns or misses known best practices.

### Step 3: Optional WebSearch Enhancement

If the skill has structural issues that local analysis cannot resolve, use `WebSearch` to find:
- "Claude Code SKILL.md best practices"
- "prompt engineering for agent skills"
- Specific topics related to the identified weaknesses

Skip this step if local analysis already produces 3+ actionable findings.

### Step 4: Optional NotebookLM Enhancement

Only if the user has explicitly requested NotebookLM integration OR if a notebook named `self-improve-{plugin-name}` already exists:
- Use the `notebooklm` user-skill (Python API) to query the existing knowledge base
- Do NOT create new notebooks automatically during the loop

### Step 5: Synthesize Findings

Output a structured research report:

```json
{
  "skill_name": "...",
  "weaknesses": ["..."],
  "best_practices": ["..."],
  "suggestions": [
    {"change": "...", "reason": "...", "impact": "high|medium|low"}
  ],
  "sources": "local|local+web|local+notebooklm"
}
```

### Step 6: Persist Findings to .agent-memory/research/

After synthesizing findings, write the report to disk so future iterations can skip re-running research:

```bash
mkdir -p {target_dir}/.agent-memory/research
```

Write to `{target_dir}/.agent-memory/research/research-cache.json`:

```json
{
  "skill_name": "...",
  "cached_at": "YYYY-MM-DDTHH:MM:SSZ",
  "iteration_number": N,
  "weaknesses": ["..."],
  "best_practices": ["..."],
  "suggestions": [{"change": "...", "reason": "...", "impact": "high|medium|low"}],
  "sources": "local|local+web|local+notebooklm"
}
```

**TTL**: Cache is considered fresh for 7 days. Consumers should check `cached_at` before re-running research.

### Step 7: Report

Output the structured research findings for the analysis and improvement phases to consume.
