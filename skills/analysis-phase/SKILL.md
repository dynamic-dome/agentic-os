---
name: analysis-phase
description: Identifies skill weaknesses using Agentic-OS pattern-extractor and iteration-logger. Ranks findings by severity and applies dedup. Use when "analyze skill weaknesses", "what needs improving", "find problems", "Schwachstellen analysieren".
metadata:
  author: agentic-os
  version: '2.0'
  layer: analysis
---

# Analysis Phase

Uses Agentic-OS pattern-extractor and iteration-logger to identify what needs improvement, ranks by severity, and deduplicates against history.

## When to Use This Skill

- Called by loop-orchestrator during each iteration
- After research-phase has gathered best practices
- When skill weaknesses need systematic identification

## Instructions

### Step 1: Receive Input

Expect as input:
- `target_dir`: Path to the plugin being analyzed
- `dedup_history`: Array of previously fixed weakness names from state.json
- `research_findings`: Best practices from research-phase (optional)

### Step 2: Invoke Agentic-OS Pattern Extractor

Use the `Skill` tool to invoke `agentic-os:pattern-extractor`:
```
Analyze the plugin at {target_dir}. Focus on skill quality patterns:
- Skill descriptions that are too vague or too specific for triggering
- Missing required sections in SKILL.md files
- Inconsistent formatting across skills
- Missing error handling or safety guards
- Steps that are ambiguous or under-specified
```

Collect pattern results. **If pattern-extractor returns "Not enough data" (fewer than 3 error records in errors.json), treat it as an empty result — no patterns from this source — and continue gracefully to Step 3. Do not abort.**

### Step 3: Read Iteration History Directly

Use the `Read` tool to load iteration data from the target plugin:
- `{target_dir}/.agent-memory/iterations/iteration-log.md` — recent iteration summaries
- `{target_dir}/.agent-memory/iterations/errors.json` — structured error records

Look for:
- Recurring errors related to skills
- Skills that triggered incorrectly (false positives/negatives)
- User feedback on skill quality

Note: `agentic-os:iteration-logger` is a *write* skill (it records new iterations). To read historical data, use the `Read` tool on the files above directly.

### Step 4: Analyze Skills Directly

Read all `skills/*/SKILL.md` files in the target directory using `Glob` and `Read`.

Check each skill for:
1. **Frontmatter completeness**: name, description, metadata (author, version, layer)
2. **Description quality**: Is it specific enough to trigger correctly? Does it include relevant keywords?
3. **Instructions clarity**: Are steps numbered? Are tool calls specified? Are edge cases handled?
4. **Safety**: Does it handle errors? Does it have rollback guidance?
5. **Consistency**: Same formatting, same section names, same level of detail across skills

### Step 5: Cross-Reference with Research

If research findings are available, compare skills against best practices:
- Are there recommended patterns the skills don't follow?
- Are there anti-patterns the skills exhibit?

**Agentic-OS Context Integration:**
If research findings include an `agentic_os_context` field (populated by research-phase from session-summary.md and learnings.md), extract `open_issues_from_memory` and treat each as an additional weakness candidate:
- Map each open issue to the most relevant skill
- Classify severity based on issue description
- Add to the weaknesses list (before dedup)

This ensures that open items tracked in agentic-os memory are systematically addressed by the improvement loop.

### Step 6: Rank and Deduplicate

Classify each finding:
- **critical**: Missing required sections, broken logic, security issues
- **warning**: Suboptimal triggers, missing edge cases, inconsistencies
- **suggestion**: Style improvements, nice-to-haves

**Dedup**: Compare each finding against `dedup_history` by name and category. Skip exact or near matches.

If 0 actionable items remain after dedup, report: "DIMINISHING RETURNS: no actionable weaknesses found"

### Step 7: Track False Alarms

Count findings that looked like problems but are actually fine (e.g., intentionally minimal skills, style choices). Report the count.

### Step 8: Report

Output structured findings:
```json
{
  "weaknesses": [
    {"name": "...", "skill": "...", "severity": "critical|warning", "description": "...", "suggested_fix": "..."}
  ],
  "suggestions": [...],
  "false_alarms": 0,
  "status": "completed|diminishing-returns"
}
```
