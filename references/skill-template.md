# Skill Template — Agentic OS v3

Use this template when creating new skills manually or reviewing auto-generated skills.

## SKILL.md Template

```markdown
---
name: <skill-name>
description: >
  <One paragraph describing WHEN and WHY this skill should be activated.
  Include concrete trigger phrases that users or the orchestrator might use.
  Example triggers: "fix imports", "optimize query", "review security".>
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: <identity|orchestration|core|quality|evolution|transfer>
---

# <Skill Title>

## When to Use

- <Situation 1 where this skill applies>
- <Situation 2>
- Automatically triggered by: <orchestrator signal or hook>

## Prerequisites

- <What must exist before running (files, config, etc.)>

## Instructions

### Step 1: <Action Title>

<Clear instruction using Claude Code tools>
- Use `Read` to load: <specific files>
- Use `Grep` to find: <specific patterns>

### Step 2: <Action Title>

<Next instruction>

### Step 3: <Action Title>

<Final instruction>

## Output

```
<Expected output format — keep consistent across skills>
```

## Avoid (Anti-Patterns)

- Do not: <common mistake 1>
- Do not: <common mistake 2>

## Example

**Input:** <Concrete scenario>
**Expected behavior:** <What the skill should do>
**Output:** <Example output>
```

## Checklist for New Skills

- [ ] Name: kebab-case, 1-64 chars
- [ ] Description: Contains trigger phrases
- [ ] Version: 3.0 for new skills
- [ ] Layer: Correctly assigned
- [ ] Steps: Use explicit Claude Code tool names (Read, Write, Edit, Bash, Glob, Grep)
- [ ] Anti-patterns: At least one "Do not" rule
- [ ] Example: At least one concrete example
- [ ] Output format: Consistent with other skills in same layer

## Layer Guide

| Layer | Purpose | Examples |
|-------|---------|---------|
| identity | Agent behavior, user profile | soul-and-identity |
| orchestration | System control, health checks | heartbeat, agent-orchestrator |
| core | Memory management, logging | iteration-logger, pattern-extractor, sync-context |
| quality | Code and test quality | code-reviewer, test-validator, retrospective |
| evolution | Self-improvement | mutation-engine, skill-generator |
| transfer | Context handoff | agent-handoff, wrap-up |
